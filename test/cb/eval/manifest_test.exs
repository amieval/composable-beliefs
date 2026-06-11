defmodule CB.Eval.ManifestTest do
  use ExUnit.Case, async: true

  alias CB.Belief
  alias CB.Eval.Manifest

  @fixture Path.expand("../../fixtures/run_manifest_v1.json", __DIR__)

  defp fixture, do: @fixture |> File.read!() |> Jason.decode!()

  describe "load/1 and validate/1" do
    test "the committed fixture validates" do
      assert {:ok, %{"eval_id" => "fixture-bulk-write-v1"}} = Manifest.load(@fixture)
    end

    test "unknown manifest versions refuse rather than best-effort parse" do
      assert {:error, {:unsupported_manifest_version, 2}} =
               fixture() |> Map.put("manifest_version", 2) |> Manifest.validate()

      assert {:error, {:missing_field, "manifest_version"}} = Manifest.validate(%{})
    end

    test "missing identity fields are named" do
      assert {:error, {:missing_field, "eval_id"}} =
               fixture() |> Map.delete("eval_id") |> Manifest.validate()

      assert {:error, {:invalid_field, "date", _}} =
               fixture() |> Map.put("date", "June 9") |> Manifest.validate()

      assert {:error, {:missing_field, "harness.name"}} =
               fixture() |> Map.put("harness", %{}) |> Manifest.validate()
    end

    test "duplicate run ids and rulers are refused" do
      m = fixture()
      [r1 | _] = m["runs"]

      assert {:error, {:duplicate, "runs[].run_id", "run1"}} =
               Manifest.validate(%{m | "runs" => [r1, r1]})

      [s1 | _] = r1["scorers"]
      bad_run = Map.put(r1, "scorers", [s1, s1])

      assert {:error, {:duplicate, _, "det-fielddiff"}} =
               Manifest.validate(%{m | "runs" => [bad_run]})
    end

    test "run logs must be document:/https: artifact URIs" do
      m = fixture()
      [r1 | rest] = m["runs"]

      assert {:error, {:invalid_field, "runs[run1].log", _}} =
               Manifest.validate(%{
                 m
                 | "runs" => [Map.put(r1, "log", "file:///etc/passwd") | rest]
               })
    end

    test "load-bearing cases cannot exceed the run's case count" do
      m = fixture()
      [r1 | rest] = m["runs"]
      shrunk = Map.put(r1, "cases", 2)

      assert {:error, {:invalid_field, path, _}} =
               Manifest.validate(%{m | "runs" => [shrunk | rest]})

      assert path =~ "load_bearing_cases"
    end

    test "outcome counts are non-negative integers" do
      m = fixture()
      [r1 | rest] = m["runs"]
      [s1 | srest] = r1["scorers"]
      bad = put_in(s1, ["aggregate", "outcome_counts"], %{"pass" => -1})

      assert {:error, {:invalid_field, path, _}} =
               Manifest.validate(%{m | "runs" => [Map.put(r1, "scorers", [bad | srest]) | rest]})

      assert path =~ "outcome_counts"
    end
  end

  describe "to_beliefs/2" do
    test "the fixture yields 8 aggregates and 12 load-bearing case primitives" do
      beliefs = Manifest.to_beliefs(fixture(), "fx")

      assert length(beliefs) == 20
      assert Enum.count(beliefs, &("aggregate" in &1["tags"])) == 8
      assert Enum.all?(beliefs, &(&1["type"] == "primitive" and &1["kind"] == "observation"))
      assert Enum.all?(beliefs, &("fixture" in &1["tags"]))
    end

    test "ids hash the identity tuple as spec'd in docs/run-manifest.md" do
      beliefs = Manifest.to_beliefs(fixture(), "fx")

      expected =
        :crypto.hash(:sha256, "cb-eval-v1|fixture-bulk-write-v1|run1|det-fielddiff")
        |> Base.encode16(case: :lower)
        |> binary_part(0, 8)

      assert Enum.any?(beliefs, &(&1["id"] == "fx:o-#{expected}"))
    end

    test "aggregates carry five subjects and the aggregate tag; cases carry six" do
      beliefs = Manifest.to_beliefs(fixture(), "fx")
      {aggs, cases} = Enum.split_with(beliefs, &("aggregate" in &1["tags"]))

      for a <- aggs do
        types = Enum.map(a["subjects"], & &1["type"])
        assert types == ~w(eval run model model_version ruler)
        assert a["artifact"] =~ ~r|^eval:fixture-bulk-write-v1/run\d/[a-z-]+$|
      end

      for c <- cases do
        types = Enum.map(c["subjects"], & &1["type"])
        assert types == ~w(eval run case model model_version ruler)
        assert Enum.any?(c["tags"], &String.starts_with?(&1, "outcome:"))
      end
    end

    test "evidence cites the raw log and the harness identity; dates come from the manifest" do
      beliefs = Manifest.to_beliefs(fixture(), "fx")

      for b <- beliefs do
        assert b["created"] == "2026-06-09"
        assert [e] = b["evidence"]
        assert e["date"] == "2026-06-09"
        assert String.starts_with?(e["artifact"], "document:logs/fixture/")
        assert e["detail"] =~ "config digest: sha256:5e1f2c9a"
      end
    end

    test "generation is deterministic - same manifest, same beliefs, same spec bytes" do
      a = Manifest.to_beliefs(fixture(), "fx")
      b = Manifest.to_beliefs(fixture(), "fx")
      assert a == b

      assert Mix.Tasks.Cb.Import.Eval.spec_json(a) == Mix.Tasks.Cb.Import.Eval.spec_json(b)
    end
  end

  describe "plan/2" do
    test "fresh observations are new; re-import is a detected no-op" do
      generated = Manifest.to_beliefs(fixture(), "fx")

      assert %{new: ^generated, noop: [], conflicts: []} = Manifest.plan(generated, [])

      on_disk = Enum.map(generated, &Belief.from_map/1)
      plan = Manifest.plan(generated, on_disk)
      assert plan.new == []
      assert plan.conflicts == []
      assert length(plan.noop) == 20
    end

    test "changed content under the same identity is a conflict" do
      generated = Manifest.to_beliefs(fixture(), "fx")
      on_disk = Enum.map(generated, &Belief.from_map/1)

      mutated = fixture()
      [r1 | rest] = mutated["runs"]
      [s1 | srest] = r1["scorers"]
      changed = put_in(s1, ["aggregate", "outcome_counts"], %{"pass" => 46, "silent_loss" => 4})
      mutated = %{mutated | "runs" => [Map.put(r1, "scorers", [changed | srest]) | rest]}

      plan = Manifest.plan(Manifest.to_beliefs(mutated, "fx"), on_disk)
      assert length(plan.conflicts) == 1
      assert length(plan.noop) == 19
    end

    test "unrelated existing beliefs do not interfere" do
      other = Belief.from_map(%{"id" => "fx:a1", "type" => "primitive", "status" => "active"})
      generated = Manifest.to_beliefs(fixture(), "fx")
      assert %{noop: [], conflicts: []} = Manifest.plan(generated, [other])
    end
  end
end
