defmodule CB.Belief.Contract.StateMachine do
  @moduledoc """
  Interpreter for state-machine-kind contracts.

  ## Semantics

  A state-machine contract's `rules` list decomposes into Datalog facts
  of the form:

      edge(From: string, To: string, Requires: [string]).

  This module exposes a small set of Elixir functions that correspond
  to Datalog queries over those facts. The DSL is the Datalog subset;
  the syntax (JSON shape) and implementation (hand-written Elixir) are
  project-specific.

  ## Query correspondence

      edges(c)                  ?- edge(F, T, R).
      transitions_from(c, f)    ?- edge(F, T, _), F = f.
      requires(c, {f, t})       ?- edge(F, T, R), F = f, T = t.
      valid_edge?(c, {f, t})    ?- edge(F, T, _), F = f, T = t. (as bool)

  Each edge names zero or more per-edge requirement slugs. This module
  is the routing table: it answers *which* edges exist and *which*
  requirements fire on each. It does not know *how* to evaluate those
  requirements - the caller holds the domain logic. That boundary is
  what keeps the DSL tabular and inspectable.

  Expected contract shape:

      %Belief{kind: "state-machine", rules: [%{"from" => ..., "to" => ..., "requires" => [...]}, ...]}

  The interpreter is generic across state-machine contracts - the belief
  is passed in. Callers are responsible for loading and (if needed)
  caching the contract.
  """

  alias CB.Belief

  @typedoc "A single transition edge as a map with atom keys."
  @type edge :: %{from: String.t(), to: String.t(), requires: [String.t()]}

  @doc """
  All edges declared in the contract's `rules`, as maps with atom keys
  `:from`, `:to`, `:requires`.

  Datalog: `?- edge(F, T, R).`
  """
  @spec edges(Belief.t()) :: [edge()]
  def edges(%Belief{rules: rules}) do
    Enum.map(rules || [], &edge_from_rule/1)
  end

  @doc """
  Valid target states reachable from the given source state.

  Returns a list of `to` strings. Empty list if the source state has no
  outgoing edges (e.g. terminal states).

  Datalog: `?- edge(F, T, _), F = from.`
  """
  @spec transitions_from(Belief.t(), String.t()) :: [String.t()]
  def transitions_from(%Belief{} = contract, from) do
    contract
    |> edges()
    |> Enum.filter(&(&1.from == from))
    |> Enum.map(& &1.to)
  end

  @doc """
  Requirement slugs for the edge `from -> to`.

  Returns `{:ok, requires}` when the edge exists (possibly with an empty
  requires list) and `:error` when no such edge is declared.

  Datalog: `?- edge(F, T, R), F = from, T = to.`
  """
  @spec requires(Belief.t(), {String.t(), String.t()}) :: {:ok, [String.t()]} | :error
  def requires(%Belief{} = contract, {from, to}) do
    case find_edge(contract, from, to) do
      nil -> :error
      edge -> {:ok, edge.requires}
    end
  end

  @doc """
  True if the contract declares an edge from `from` to `to`.

  Datalog: `?- edge(F, T, _), F = from, T = to.` evaluated as
  satisfiability.
  """
  @spec valid_edge?(Belief.t(), {String.t(), String.t()}) :: boolean()
  def valid_edge?(%Belief{} = contract, {from, to}) do
    find_edge(contract, from, to) != nil
  end

  # --- Private ---

  defp find_edge(%Belief{} = contract, from, to) do
    contract
    |> edges()
    |> Enum.find(&(&1.from == from && &1.to == to))
  end

  defp edge_from_rule(rule) when is_map(rule) do
    %{
      from: rule["from"],
      to: rule["to"],
      requires: rule["requires"] || []
    }
  end
end
