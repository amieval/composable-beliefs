defmodule CB.TodosTest do
  use ExUnit.Case, async: true

  alias CB.Todos

  defp tmp_path do
    Path.join(System.tmp_dir!(), "cb-todos-#{:rand.uniform(999_999)}.json")
  end

  defp record(id, overrides \\ %{}) do
    Map.merge(
      %{
        "action" => "Do the thing for #{id}",
        "created" => "2026-06-12",
        "id" => id,
        "source" => "cb:a999",
        "status" => "open"
      },
      overrides
    )
  end

  describe "close/3" do
    test "flips an open record to done with discharge notes" do
      records = [record("t0001"), record("t0002")]

      assert {:ok, updated, closed} = Todos.close(records, "t0002", "Discharged.")
      assert closed["status"] == "done"
      assert closed["notes"] == "Discharged."

      assert Enum.find(updated, &(&1["id"] == "t0002")) == closed
      # The untouched record is byte-for-byte the same map.
      assert Enum.find(updated, &(&1["id"] == "t0001")) == record("t0001")
    end

    test "materialization-time notes are kept, discharge notes appended" do
      records = [record("t0001", %{"notes" => "a999: why this matters"})]

      assert {:ok, _updated, closed} = Todos.close(records, "t0001", "Discharged.")
      assert closed["notes"] == "a999: why this matters\n\nDischarged."
    end

    test "an unknown id is an error" do
      assert {:error, {:not_found, "t9999"}} = Todos.close([record("t0001")], "t9999", "n")
    end

    test "a record that is not open refuses the flip" do
      records = [record("t0001", %{"status" => "done"})]
      assert {:error, {:not_open, "t0001", "done"}} = Todos.close(records, "t0001", "n")
    end
  end

  describe "read/1 and write/2" do
    test "a missing file reads as an empty collection" do
      assert {:ok, []} = Todos.read(tmp_path())
    end

    test "a non-array file is an error" do
      path = tmp_path()
      File.write!(path, ~s({"not": "a list"}))
      on_exit(fn -> File.rm(path) end)

      assert {:error, :todos_not_a_list} = Todos.read(path)
    end

    test "write/read roundtrip preserves records" do
      path = tmp_path()
      on_exit(fn -> File.rm(path) end)

      records = [record("t0001"), record("t0002", %{"notes" => "kept"})]
      assert {:ok, ^path} = Todos.write(records, path)
      assert {:ok, ^records} = Todos.read(path)
    end

    test "closing one record leaves the others byte-identical in the file" do
      path = tmp_path()
      on_exit(fn -> File.rm(path) end)

      {:ok, _} = Todos.write([record("t0001"), record("t0002")], path)
      before_lines = path |> File.read!() |> String.split("\n")

      {:ok, records} = Todos.read(path)
      {:ok, updated, _closed} = Todos.close(records, "t0002", "Discharged.")
      {:ok, _} = Todos.write(updated, path)
      after_lines = path |> File.read!() |> String.split("\n")

      # Only the t0002 record changed: its status line flipped and a
      # notes line appeared. Every line of the t0001 record survives.
      removed = before_lines -- after_lines
      added = after_lines -- before_lines
      assert removed == [~s(    "status": "open")]
      assert Enum.sort(added) == [~s(    "notes": "Discharged.",), ~s(    "status": "done")]
    end
  end
end
