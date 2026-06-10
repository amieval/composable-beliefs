defmodule CB.Codepath.AssertionsTest do
  # async: false - the "real predicates" describe scopes the global
  # :beliefs_path app env, which concurrent tests read through CB.Config.
  use ExUnit.Case, async: false

  alias CB.Belief
  alias CB.Codepath.Assertions
  alias CB.Codepath.Predicates
  alias CB.Materializer.Sink

  defmodule FixturePredicates do
    def always_true?, do: true
    def always_false?, do: false
    def boom_check, do: raise("kaput")
    def not_boolean?, do: :maybe
    def mutate_everything, do: true
  end

  defp b(fields), do: struct(Belief, Map.merge(%{status: "active", deps: []}, Map.new(fields)))

  defp stop(id, opts) do
    rules =
      case opts[:predicate] do
        nil -> []
        name -> [%{"when" => %{"assertions" => "on"}, "requires" => name}]
      end

    b(
      id: id,
      type: if(rules == [], do: "primitive", else: "implication"),
      kind: if(rules == [], do: "fact", else: "rule"),
      contract: rules != [],
      rules: rules,
      claim: opts[:claim] || "a stop",
      artifact: "code:lib/pipe.ex#def read do"
    )
  end

  defp target(step_rows, deps) do
    b(
      id: "x:c100",
      type: "implication",
      kind: "output-target",
      contract: true,
      tags: ["output:codepath"],
      deps: deps,
      rules: [%{"entry" => "s1"}, %{"render_steps" => step_rows}]
    )
  end

  describe "Predicates.resolve/2" do
    test "enforces the inspection-only naming invariant before lookup" do
      assert {:error, :bad_name} = Predicates.resolve(FixturePredicates, "mutate_everything")
    end

    test "rejects unknown predicates and accepts exported ones" do
      assert {:error, :unknown_predicate} = Predicates.resolve(FixturePredicates, "ghost?")
      assert {:ok, fun} = Predicates.resolve(FixturePredicates, "always_true?")
      assert fun.() == true
      assert {:ok, _} = Predicates.resolve(FixturePredicates, "boom_check")
    end
  end

  describe "Assertions.run/3" do
    test "contract stops assert, non-contract stops narrate only (the gradient)" do
      narrating = stop("x:a001", [])
      asserting = stop("x:c001", predicate: "always_true?")

      steps = [
        %{"id" => "s1", "belief" => "x:a001", "goto" => "s2"},
        %{"id" => "s2", "belief" => "x:c001"}
      ]

      t = target(steps, ["x:a001", "x:c001"])

      results = Assertions.run(t, [narrating, asserting, t], module: FixturePredicates)

      assert [%{step: "s2", belief: "x:c001", predicate: "always_true?", result: "pass"}] =
               results

      assert Assertions.passed?(results)
    end

    test "false, raise, non-boolean, bad name, and unknown all fail with detail" do
      cases = [
        {"always_false?", "returned false"},
        {"boom_check", "kaput"},
        {"not_boolean?", "non-boolean"},
        {"mutate_everything", "inspection-only"},
        {"ghost?", "no exported"}
      ]

      for {predicate, expected} <- cases do
        s = stop("x:c001", predicate: predicate)
        t = target([%{"id" => "s1", "belief" => "x:c001"}], ["x:c001"])

        assert [%{result: "fail", detail: detail}] =
                 Assertions.run(t, [s, t], module: FixturePredicates)

        assert detail =~ expected, "#{predicate}: #{detail}"
      end
    end
  end

  describe "Sink.Test" do
    test "persisting action items invokes predicates and returns pass/fail refs" do
      items = [
        %{"action" => "invoke always_true?", "predicate" => "always_true?"},
        %{"predicate" => "always_false?"}
      ]

      assert {:ok, [ok, bad]} = Sink.Test.persist(nil, items, module: FixturePredicates)
      assert %{"id" => "always_true?", "result" => "pass"} = ok
      assert %{"id" => "always_false?", "result" => "fail", "detail" => _} = bad
      assert bad["action"] == "invoke always_false?"
    end
  end

  describe "the real predicates over a real collection" do
    @describetag :tmp_dir

    test "all four belief-pipeline predicates pass against a valid graph", %{tmp_dir: dir} do
      path = Path.join(dir, "beliefs.json")

      File.write!(
        path,
        Jason.encode!([
          %{
            "id" => "t:a001",
            "type" => "primitive",
            "kind" => "fact",
            "claim" => "x",
            "status" => "active"
          }
        ])
      )

      # Predicates read CB.Config.beliefs_path; scope the override to this test.
      previous = Application.get_env(:cb, :beliefs_path)
      Application.put_env(:cb, :beliefs_path, path)
      on_exit(fn -> restore_env(previous) end)

      assert Predicates.belief_count_positive?()
      assert Predicates.from_map_roundtrips?()
      assert Predicates.store_reads_structs?()
      assert Predicates.formatter_renders_table?()
    end
  end

  describe "the shipped belief-pipeline codepath with assertions on" do
    test "every routed predicate passes; the data stop narrates only (the gradient)" do
      path = Path.join(CB.repo_root(), "codepath/beliefs.json")

      if File.exists?(path) do
        previous = Application.get_env(:cb, :beliefs_path)
        Application.put_env(:cb, :beliefs_path, path)
        on_exit(fn -> restore_env(previous) end)

        {:ok, beliefs} = CB.Belief.Store.read()
        assert [target] = CB.Codepath.targets(beliefs)

        results = Assertions.run(target, beliefs)

        assert Enum.map(results, &{&1.step, &1.predicate, &1.result}) == [
                 {"from-map", "from_map_roundtrips?", "pass"},
                 {"store", "store_reads_structs?", "pass"},
                 {"formatter", "formatter_renders_table?", "pass"}
               ]

        refute Enum.any?(results, &(&1.step == "data"))
      end
    end
  end

  defp restore_env(nil), do: Application.delete_env(:cb, :beliefs_path)
  defp restore_env(value), do: Application.put_env(:cb, :beliefs_path, value)
end
