defmodule CB.Method.ChecksTest do
  use ExUnit.Case, async: true

  alias CB.Belief
  alias CB.Method.Checks

  defp belief(map), do: map |> Map.put_new("status", "active") |> Belief.from_map()

  defp routed_contract(id, requires, params \\ nil) do
    rule = %{"when" => %{"verify" => "collection"}, "requires" => requires}
    rule = if params, do: Map.put(rule, "params", params), else: rule

    belief(%{
      "id" => id,
      "type" => "directive",
      "kind" => "implies",
      "name" => "m-#{requires}",
      "contract" => true,
      "rules" => [rule],
      "invariants" => ["fixture"]
    })
  end

  defmodule Fixture do
    def always_pass?(_beliefs, _params), do: true
    def always_fail?(_beliefs, _params), do: {false, "t:bad is the culprit"}
    def min_check?(_beliefs, params), do: params == %{"min" => 3} or {false, inspect(params)}
  end

  describe "contracts/1 (discovery by rule shape)" do
    test "finds active implies-kind contracts routing on verify: collection" do
      c = routed_contract("m:c1", "always_pass?")
      assert Checks.contracts([c]) == [c]
    end

    test "ignores enum-registry contracts despite their when-less rule entries" do
      enum =
        belief(%{
          "id" => "m:c2",
          "type" => "directive",
          "kind" => "enum-registry",
          "contract" => true,
          "rules" => [%{"field" => "kind", "values" => ["observation"]}],
          "invariants" => ["fixture"]
        })

      assert Checks.contracts([enum]) == []
    end

    test "ignores implies contracts routing on other conditions" do
      codepath =
        belief(%{
          "id" => "m:c3",
          "type" => "directive",
          "kind" => "implies",
          "contract" => true,
          "rules" => [%{"when" => %{"assertions" => "on"}, "requires" => "always_pass?"}],
          "invariants" => ["fixture"]
        })

      assert Checks.contracts([codepath]) == []
    end

    test "ignores superseded contracts and non-contracts" do
      superseded =
        belief(%{
          "id" => "m:c4",
          "type" => "directive",
          "kind" => "implies",
          "contract" => true,
          "rules" => [%{"when" => %{"verify" => "collection"}, "requires" => "always_pass?"}],
          "invariants" => ["fixture"],
          "status" => "superseded",
          "superseded_by" => "m:c5"
        })

      plain = belief(%{"id" => "m:a1", "type" => "primitive", "kind" => "observation"})

      assert Checks.contracts([superseded, plain]) == []
    end
  end

  describe "run/2" do
    test "produces one row per routed rule, with params passed through" do
      beliefs = [
        routed_contract("m:c1", "always_pass?"),
        routed_contract("m:c2", "always_fail?"),
        routed_contract("m:c3", "min_check?", %{"min" => 3})
      ]

      rows = Checks.run(beliefs, module: Fixture)

      assert [
               %{contract: "m:c1", predicate: "always_pass?", result: "pass", detail: nil},
               %{
                 contract: "m:c2",
                 predicate: "always_fail?",
                 result: "fail",
                 detail: "t:bad is the culprit"
               },
               %{contract: "m:c3", predicate: "min_check?", result: "pass"}
             ] = rows

      refute Checks.passed?(rows)
      assert Checks.passed?(Enum.filter(rows, &(&1.result == "pass")))
    end

    test "missing params reach the predicate as an empty map" do
      rows = Checks.run([routed_contract("m:c1", "min_check?")], module: Fixture)
      assert [%{result: "fail", detail: "%{}"}] = rows
    end

    test "an unresolvable routed name fails the row, never crashes" do
      rows = Checks.run([routed_contract("m:c1", "ghost?")], module: Fixture)
      assert [%{result: "fail", detail: detail}] = rows
      assert detail =~ "no exported arity-2 predicate"
    end

    test "a union with no routed contracts yields no rows" do
      assert Checks.run([belief(%{"id" => "t:a1", "type" => "primitive"})]) == []
    end
  end

  describe "against the real method: contracts (integration)" do
    # The sdl worked example is the canonical failing fixture: it
    # deliberately violates m-runs and m-judge-validation (see its
    # README). Skipped when the sibling belief-collections checkout is
    # absent so the suite stays self-contained elsewhere.
    @registry CB.Collection.default_registry_path()

    @tag :collections
    test "sdl fails exactly m-runs and m-judge-validation; toy passes all six" do
      if File.exists?(@registry) do
        {:ok, %{union: sdl}} = CB.Collection.load_union("sdl")
        failed = for row <- Checks.run(sdl), row.result == "fail", do: row.name
        assert Enum.sort(failed) == ["m-judge-validation", "m-runs"]

        {:ok, %{union: toy}} = CB.Collection.load_union("toy")
        rows = Checks.run(toy)
        assert length(rows) == 6
        assert Checks.passed?(rows)
      end
    end
  end
end
