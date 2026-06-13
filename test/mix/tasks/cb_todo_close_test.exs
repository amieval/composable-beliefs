defmodule Mix.Tasks.Cb.Todo.CloseTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.Cb.Todo.Close, as: Task

  defp fixture do
    path = Path.join(System.tmp_dir!(), "cb-todo-close-#{:rand.uniform(999_999)}.json")

    records = [
      %{
        "action" => "Build the thing",
        "created" => "2026-06-12",
        "id" => "t0001",
        "source" => "cb:a530",
        "status" => "open"
      }
    ]

    File.write!(path, Jason.encode!(records, pretty: true) <> "\n")
    on_exit(fn -> File.rm(path) end)
    path
  end

  describe "validate_notes/1" do
    test "missing notes are an error" do
      assert {:error, _} = Task.validate_notes(nil)
    end

    test "blank notes are an error" do
      assert {:error, _} = Task.validate_notes("   ")
    end

    test "non-empty notes pass through" do
      assert {:ok, "done because"} = Task.validate_notes("done because")
    end
  end

  describe "run/1" do
    test "dry run reports the flip without writing" do
      path = fixture()

      stderr =
        capture_io(:stderr, fn ->
          stdout =
            capture_io(fn ->
              Task.run(["t0001", "--notes", "Discharged.", "--todos", path])
            end)

          assert stdout =~ "t0001"
          assert stdout =~ "open -> done"
        end)

      assert stderr =~ "Dry run"

      [record] = Jason.decode!(File.read!(path))
      assert record["status"] == "open"
      refute Map.has_key?(record, "notes")
    end

    test "--write flips the record on disk" do
      path = fixture()

      capture_io(fn ->
        capture_io(:stderr, fn ->
          Task.run(["t0001", "--notes", "Discharged.", "--todos", path, "--write"])
        end)
      end)

      [record] = Jason.decode!(File.read!(path))
      assert record["status"] == "done"
      assert record["notes"] == "Discharged."
    end
  end
end
