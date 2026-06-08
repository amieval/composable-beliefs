defmodule CB.Belief.Contract.Enum do
  @moduledoc """
  Interpreter for enum-registry-kind contracts.

  ## Semantics

  An enum-registry contract's `rules` list decomposes into Datalog facts
  of the form:

      allowed(Field: string, Value: string).

  Each rule `%{"field" => F, "values" => [V1, V2, ...]}` decomposes into
  one `allowed(F, V)` fact per value.

  ## Query correspondence

      fields(c)                 ?- allowed(F, _). (distinct F)
      values_for(c, f)          ?- allowed(F, V), F = f.
      valid_value?(c, f, v)     ?- allowed(F, V), F = f, V = v. (as bool)
      fields_accepting(c, v)    ?- allowed(F, V), V = v. (distinct F)

  A typical enum-registry contract closes the value set for one or more
  named fields (for example a status or category field) so callers can
  validate inputs against the declared vocabulary.

  The interpreter is generic across enum-registry contracts - the belief
  is passed in. Callers are responsible for loading and (if needed)
  caching the contract.
  """

  alias CB.Belief

  @doc """
  Fields declared in the contract's `rules`.

  Datalog: `?- allowed(F, _).` with distinct F
  """
  @spec fields(Belief.t()) :: [String.t()]
  def fields(%Belief{rules: rules}) do
    (rules || [])
    |> Enum.map(& &1["field"])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  Allowed values for the given field.

  Returns a list of strings. Empty list if the field is not declared by
  the contract - callers should distinguish "unknown field" from "known
  field with no values" by checking against `fields/1` if it matters.

  Datalog: `?- allowed(F, V), F = field.`
  """
  @spec values_for(Belief.t(), String.t()) :: [String.t()]
  def values_for(%Belief{rules: rules}, field) do
    (rules || [])
    |> Enum.find(fn r -> r["field"] == field end)
    |> case do
      nil -> []
      %{"values" => values} when is_list(values) -> values
      _ -> []
    end
  end

  @doc """
  True if `value` is a declared allowed value for `field` in the contract.

  Returns `false` both for unknown fields and for unknown values. Use
  `fields/1` if you need to distinguish.

  Datalog: `?- allowed(F, V), F = field, V = value.` as satisfiability
  """
  @spec valid_value?(Belief.t(), String.t(), String.t()) :: boolean()
  def valid_value?(%Belief{} = contract, field, value) do
    value in values_for(contract, field)
  end

  @doc """
  Fields whose allowed-value set contains `value`.

  Useful for reverse lookup: given a value, which fields accept it?
  Rarely needed but cheap to expose.

  Datalog: `?- allowed(F, V), V = value.` with distinct F
  """
  @spec fields_accepting(Belief.t(), String.t()) :: [String.t()]
  def fields_accepting(%Belief{rules: rules}, value) do
    (rules || [])
    |> Enum.filter(fn r -> value in (r["values"] || []) end)
    |> Enum.map(& &1["field"])
    |> Enum.uniq()
  end

  @doc """
  All `%{field, values}` entries as maps with atom keys. Useful for
  rendering / diffing the full enum registry.

  Datalog: not a single query - this is the raw fact relation grouped
  back into its source shape.
  """
  @spec entries(Belief.t()) :: [%{field: String.t(), values: [String.t()]}]
  def entries(%Belief{rules: rules}) do
    Enum.map(rules || [], fn r ->
      %{field: r["field"], values: r["values"] || []}
    end)
  end
end
