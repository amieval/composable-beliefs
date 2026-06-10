defmodule CB.Codepath.Assertions do
  @moduledoc """
  Run a codepath's routed predicates - the assertions-on gradient.

  For each step of a codepath output-target whose belief is
  contract-grade, the belief's `implies` rules route to named predicates
  (`CB.Belief.Contract.Implies`); this module resolves each name through
  `CB.Codepath.Predicates.resolve/2` and invokes it directly in-process
  (plan-3 Step A - no booted app, no MCP). Non-contract stops produce no
  rows: they narrate only. That asymmetry *is* the gradient.

  A predicate passes when it returns `true`. `false`, a non-boolean, a
  raise, or an unresolvable name all fail with a detail - an assertion
  run never crashes the suite.
  """

  alias CB.Belief
  alias CB.Belief.Contract.Implies
  alias CB.Codepath.Predicates
  alias CB.OutputTarget

  @assert_fields %{"assertions" => "on"}

  @type result :: %{
          step: String.t(),
          belief: String.t(),
          predicate: String.t(),
          result: String.t(),
          detail: String.t() | nil
        }

  @doc """
  Run every routed predicate of `target`'s contract-grade stops.

  `opts`:
  - `:module` - the predicates module (default `CB.Codepath.Predicates`);
    tests inject fixtures here.

  Returns result rows in step order. Steps whose belief is not
  contract-grade contribute none.
  """
  @spec run(Belief.t(), [Belief.t()], keyword()) :: [result()]
  def run(target, all_beliefs, opts \\ []) do
    module = Keyword.get(opts, :module, Predicates)
    by_id = Map.new(all_beliefs, &{&1.id, &1})
    steps = OutputTarget.rules_map(target)["render_steps"] || []

    for step <- steps,
        belief = by_id[step["belief"]],
        Belief.contract?(belief),
        predicate <- Implies.applicable(belief, @assert_fields) do
      {result, detail} = Predicates.invoke(module, predicate)

      %{
        step: step["id"],
        belief: belief.id,
        predicate: predicate,
        result: result,
        detail: detail
      }
    end
  end

  @doc "True when no result row failed."
  @spec passed?([result()]) :: boolean()
  def passed?(results), do: Enum.all?(results, &(&1.result == "pass"))
end
