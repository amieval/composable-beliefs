defmodule CB.Method.Checks do
  @moduledoc """
  The method-check pass: run a collection union's routed methodology
  contracts as a static verification step.

  Discovery is role-based, like everything else in the verifier: from
  the loaded union, the pass selects active contract-grade directives
  of the catalogued `implies` kind whose rules route on
  `{"when": {"verify": "collection"}, "requires": "<predicate>"}` - by
  rule shape, not by namespace or id, so any collection may declare such
  contracts. Each routed name resolves through the shared gate against
  `CB.Eval.Predicates` (`:module` injection for tests) and is invoked
  with the union plus the rule's optional `"params"` map.

  Rule entries tolerate the extra `params` key by construction -
  `CB.Belief.Contract.Implies` reads only `when`/`requires`, and the
  contract-shape catalogue (`cb:c046`) lists `when`/`requires` as
  *required* fields, not a closed set - so no catalogue supersession is
  needed (see plans/cb-eval/decisions.md).

  Graph-shape predicates are pure traversal: deterministic, so this
  pass lives on the `verify.schema` side of the determinism boundary,
  inside `mix cb.verify.collection`. It never touches the dynamic
  verifier (`cb.verify.codepath`), and nothing here mutates anything.
  """

  alias CB.Belief
  alias CB.Belief.Contract.Implies
  alias CB.Eval.Predicates

  @route_fields %{"verify" => "collection"}

  @type result :: %{
          contract: String.t(),
          name: String.t() | nil,
          predicate: String.t() | nil,
          result: String.t(),
          detail: String.t() | nil
        }

  @doc """
  Active `implies`-kind contracts in `beliefs` with at least one rule
  routing on `{"verify": "collection"}`.
  """
  @spec contracts([Belief.t()]) :: [Belief.t()]
  def contracts(beliefs) do
    beliefs
    |> Enum.filter(&(&1.status == "active" and Belief.contract?(&1) and &1.kind == "implies"))
    |> Enum.filter(fn c -> Implies.applicable(c, @route_fields) != [] end)
  end

  @doc """
  Run every routed methodology predicate over the union.

  `opts`:
  - `:module` - the predicates module (default `CB.Eval.Predicates`);
    tests inject fixtures here.

  Returns one result row per routed rule, in contract order. A union
  with no routed contracts returns `[]` - the caller reports a skip,
  not a failure, per house convention.
  """
  @spec run([Belief.t()], keyword()) :: [result()]
  def run(beliefs, opts \\ []) do
    module = Keyword.get(opts, :module, Predicates)

    for contract <- contracts(beliefs),
        predicate <- Implies.applicable(contract, @route_fields) do
      {result, detail} =
        Predicates.invoke(module, predicate, beliefs, params_for(contract, predicate))

      %{
        contract: contract.id,
        name: contract.name,
        predicate: predicate,
        result: result,
        detail: detail
      }
    end
  end

  @doc "True when no result row failed."
  @spec passed?([result()]) :: boolean()
  def passed?(results), do: Enum.all?(results, &(&1.result == "pass"))

  # The optional `params` map on the rule entry routing `slug`. The map
  # is passed to the predicate as untrusted shape - validation is the
  # predicate's job.
  defp params_for(%Belief{rules: rules}, slug) do
    (rules || [])
    |> Enum.find(fn r -> r["requires"] == slug end)
    |> case do
      %{"params" => params} when is_map(params) -> params
      _ -> %{}
    end
  end
end
