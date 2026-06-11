defmodule CB.Belief.MutationTest do
  use ExUnit.Case, async: true

  alias CB.Belief
  alias CB.Belief.Mutation

  defp beliefs do
    [
      %Belief{
        id: "a001",
        type: "primitive",
        kind: "rule",
        domain: "ops",
        claim: "Loan period is 21 days",
        artifact: "document:policy.md",
        evidence: [],
        deps: [],
        status: "active",
        created: "2024-09-01",
        _keys: MapSet.new(~w(id type kind domain claim artifact evidence deps status created))
      }
    ]
  end

  @opts [slug: "session-test", date: "2026-06-03"]

  test "context mutation is a no-op" do
    bs = beliefs()

    assert Mutation.apply_one(%{type: "context", id: "m1", belief_id: "a001"}, bs, @opts) ==
             {:ok, bs}
  end

  test "reclassify-kind updates kind and appends evidence" do
    m = %{
      type: "reclassify-kind",
      id: "m1",
      belief_id: "a001",
      before: %{"kind" => "rule"},
      after: %{"kind" => "policy"}
    }

    assert {:ok, [updated]} = Mutation.apply_one(m, beliefs(), @opts)
    assert updated.kind == "policy"
    assert List.last(updated.evidence)["artifact"] == "session:session-test"
    assert List.last(updated.evidence)["date"] == "2026-06-03"
  end

  test "set-name sets the name field" do
    m = %{type: "set-name", id: "m1", belief_id: "a001", after: %{"name" => "loan-period-rule"}}
    assert {:ok, [updated]} = Mutation.apply_one(m, beliefs(), @opts)
    assert updated.name == "loan-period-rule"
  end

  test "add-dep replaces deps with the new set" do
    m = %{type: "add-dep", id: "m1", belief_id: "a001", dep: "a002", after: %{"deps" => ["a002"]}}
    assert {:ok, [updated]} = Mutation.apply_one(m, beliefs(), @opts)
    assert updated.deps == ["a002"]
  end

  test "supersede flips status and links successor" do
    m = %{type: "supersede", id: "m1", belief_id: "a001", successor: "a009"}
    assert {:ok, [updated]} = Mutation.apply_one(m, beliefs(), @opts)
    assert updated.status == "superseded"
    assert updated.superseded_by == "a009"
  end

  test "retract sets status, date, and reason" do
    m = %{
      type: "retract",
      id: "m1",
      belief_id: "a001",
      after: %{"retracted_on" => "2026-06-03", "retracted_reason" => "obsolete"}
    }

    assert {:ok, [updated]} = Mutation.apply_one(m, beliefs(), @opts)
    assert updated.status == "retracted"
    assert updated.retracted_on == "2026-06-03"
    assert updated.retracted_reason == "obsolete"
  end

  test "new-belief appends a fresh belief" do
    m = %{
      type: "new-belief",
      id: "m1",
      belief_id: "a050",
      after: %{"id" => "a050", "type" => "primitive", "kind" => "rule", "claim" => "new fact"}
    }

    assert {:ok, updated} = Mutation.apply_one(m, beliefs(), @opts)
    assert length(updated) == 2
    new = Enum.find(updated, &(&1.id == "a050"))
    assert new.claim == "new fact"
  end

  test "new-belief rejects id collisions" do
    m = %{
      type: "new-belief",
      id: "m1",
      belief_id: "a001",
      after: %{"id" => "a001", "type" => "primitive"}
    }

    assert {:error, {:belief_id_conflict, "a001"}} = Mutation.apply_one(m, beliefs(), @opts)
  end

  test "belief-not-found surfaces for mutations targeting a missing id" do
    m = %{type: "set-name", id: "m1", belief_id: "zzz", after: %{"name" => "x"}}
    assert {:error, {:belief_not_found, "zzz"}} = Mutation.apply_one(m, beliefs(), @opts)
  end

  test "unknown type returns :not_implemented" do
    assert {:error, {:not_implemented, "wat"}} =
             Mutation.apply_one(%{type: "wat", id: "m1", belief_id: "a001"}, beliefs(), @opts)
  end

  test "apply_batch filters context and short-circuits on error" do
    ms = [
      %{type: "context", id: "m0", belief_id: "a001"},
      %{type: "set-name", id: "m1", belief_id: "a001", after: %{"name" => "named"}},
      %{type: "set-name", id: "m2", belief_id: "missing", after: %{"name" => "x"}}
    ]

    assert {:error, {"m2", {:belief_not_found, "missing"}}} =
             Mutation.apply_batch(ms, beliefs(), @opts)
  end

  test "apply_batch applies a clean batch" do
    ms = [
      %{type: "set-name", id: "m1", belief_id: "a001", after: %{"name" => "named"}},
      %{type: "add-dep", id: "m2", belief_id: "a001", dep: "a002", after: %{"deps" => ["a002"]}}
    ]

    assert {:ok, [updated]} = Mutation.apply_batch(ms, beliefs(), @opts)
    assert updated.name == "named"
    assert updated.deps == ["a002"]
  end

  test "summary renders a one-line description" do
    m = %{type: "supersede", id: "m1", belief_id: "a001", successor: "a009"}
    assert Mutation.summary(m) == "m1 (supersede) a001: → a009"
  end

  test "missing slug raises" do
    m = %{type: "set-name", id: "m1", belief_id: "a001", after: %{"name" => "x"}}
    assert_raise ArgumentError, fn -> Mutation.apply_one(m, beliefs(), date: "2026-06-03") end
  end
end
