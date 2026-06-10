defmodule CB.Belief.AdjudicationTest do
  use ExUnit.Case, async: true

  alias CB.Belief.Adjudication

  @moduletag :tmp_dir

  defp seed(path, beliefs) do
    File.write!(path, Jason.encode!(beliefs))
    path
  end

  defp existing_contract do
    %{
      "id" => "cb:c040",
      "type" => "implication",
      "kind" => "enum-registry",
      "contract" => true,
      "claim" => "Old enum.",
      "rules" => [%{"field" => "artifact-scheme", "values" => ["document"]}],
      "status" => "active",
      "created" => "2026-05-15"
    }
  end

  defp proposed_contract do
    %{
      "type" => "implication",
      "kind" => "enum-registry",
      "contract" => true,
      "claim" => "New enum.",
      "rules" => [%{"field" => "artifact-scheme", "values" => ["document", "code"]}],
      "deps" => []
    }
  end

  defp record(overrides \\ %{}) do
    Map.merge(
      %{
        "proposed" => proposed_contract(),
        "conflicting_id" => "cb:c040",
        "outcome" => "accept_supersede",
        "reasoning" => "test",
        "session_ref" => "test-session"
      },
      overrides
    )
  end

  test "accept_supersede assigns the successor a c-id in the conflicting belief's namespace",
       %{tmp_dir: dir} do
    path = seed(Path.join(dir, "beliefs.json"), [existing_contract()])

    assert {:ok, summary} = Adjudication.apply(record(), beliefs_path: path, today: "2026-06-09")
    assert summary.new_id == "cb:c041"

    {:ok, content} = File.read(path)
    {:ok, beliefs} = Jason.decode(content)
    old = Enum.find(beliefs, &(&1["id"] == "cb:c040"))
    new = Enum.find(beliefs, &(&1["id"] == "cb:c041"))

    assert old["status"] == "superseded"
    assert old["superseded_by"] == "cb:c041"
    assert new["status"] == "active"
  end

  test "a bare conflicting id yields a bare successor id (pre-namespacing behavior)",
       %{tmp_dir: dir} do
    bare = Map.put(existing_contract(), "id", "c040")
    path = seed(Path.join(dir, "beliefs.json"), [bare])

    assert {:ok, summary} =
             Adjudication.apply(record(%{"conflicting_id" => "c040"}),
               beliefs_path: path,
               today: "2026-06-09"
             )

    assert summary.new_id == "c041"
  end

  test "defer writes a namespaced deferral primitive", %{tmp_dir: dir} do
    path = seed(Path.join(dir, "beliefs.json"), [existing_contract()])

    assert {:ok, summary} =
             Adjudication.apply(record(%{"outcome" => "defer"}),
               beliefs_path: path,
               today: "2026-06-09"
             )

    assert summary.new_id == "cb:a001"
  end

  test "refuses when the conflicting belief is already terminal", %{tmp_dir: dir} do
    superseded =
      existing_contract()
      |> Map.put("status", "superseded")
      |> Map.put("superseded_by", "cb:c099")

    path = seed(Path.join(dir, "beliefs.json"), [superseded])

    assert {:error, :conflicting_already_terminal} =
             Adjudication.apply(record(), beliefs_path: path, today: "2026-06-09")
  end
end
