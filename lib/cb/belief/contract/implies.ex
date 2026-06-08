defmodule CB.Belief.Contract.Implies do
  @moduledoc """
  Interpreter for implies-kind contracts.

  ## Semantics

  An implies contract's `rules` list decomposes into conditional
  invariants:

      implies(When: map, Requires: string).

  Each rule has a `when` condition (a partial map of field→value pairs)
  and a `requires` slug naming the predicate to enforce when the
  condition matches. The interpreter checks conditions; the calling
  module implements each predicate.

  ## Query correspondence

      invariants(c)                 ?- implies(W, R).
      applicable(c, fields)         ?- implies(W, R), matches(W, fields). (slugs only)
      condition_for(c, slug)        ?- implies(W, R), R = slug. (the when map)

  Condition matching: every key-value pair in the `when` map must equal
  the corresponding key in the provided fields map. Extra keys in the
  fields map are ignored (partial match).

  A typical implies contract names struct-level invariants that only
  fire under particular field configurations.
  """

  alias CB.Belief

  @doc """
  All invariant rules as `%{when: map, requires: string}` maps.

  Datalog: `?- implies(W, R).`
  """
  @spec invariants(Belief.t()) :: [%{when: map(), requires: String.t()}]
  def invariants(%Belief{rules: rules}) do
    (rules || [])
    |> Enum.map(fn rule ->
      %{when: rule["when"] || %{}, requires: rule["requires"]}
    end)
  end

  @doc """
  Predicate slugs whose `when` condition matches the given fields.

  `fields` is a string-keyed map of the struct's current field values.
  A rule's condition matches when every key-value pair in its `when`
  map equals the corresponding entry in `fields`.

  Returns a list of requirement slug strings. Empty if no invariants
  fire for the current field values.

  Datalog: `?- implies(W, R), matches(W, fields).`
  """
  @spec applicable(Belief.t(), map()) :: [String.t()]
  def applicable(%Belief{} = contract, fields) when is_map(fields) do
    contract
    |> invariants()
    |> Enum.filter(fn %{when: condition} -> condition_matches?(condition, fields) end)
    |> Enum.map(& &1.requires)
  end

  @doc """
  The `when` condition map for a specific requirement slug.

  Returns `{:ok, when_map}` if found, `:error` if no rule uses that slug.

  Datalog: `?- implies(W, R), R = slug.`
  """
  @spec condition_for(Belief.t(), String.t()) :: {:ok, map()} | :error
  def condition_for(%Belief{} = contract, slug) do
    case Enum.find(invariants(contract), &(&1.requires == slug)) do
      nil -> :error
      %{when: condition} -> {:ok, condition}
    end
  end

  # --- Private ---

  defp condition_matches?(condition, fields) do
    Enum.all?(condition, fn {key, expected} ->
      Map.get(fields, key) == expected
    end)
  end
end
