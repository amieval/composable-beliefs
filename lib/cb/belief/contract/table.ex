defmodule CB.Belief.Contract.Table do
  @moduledoc """
  Interpreter for derivation-table-kind contracts.

  ## Semantics

  A derivation-table contract's `rules` list is a relation — each entry
  is a tuple (map) whose keys are the relation's columns. Column names
  and count are per-contract; the interpreter is generic across all
  derivation-table contracts.

  Datalog fact shape (per-contract columns):

      row(Col1: any, Col2: any, ..., ColN: any).

  ## Query correspondence

      rows(c)                       ?- row(C1, C2, ..., Cn).
      lookup(c, %{k => v})          ?- row(...), K = v.  (selection)
      column_values(c, col)         ?- row(..., Col, ...). (projection, distinct)
      has_match?(c, %{k => v})      ?- row(...), K = v.  (as bool)
      columns(c)                    schema introspection (all column names)

  A typical derivation-table contract encodes a small decision table
  whose rows map input columns to a derived output column.
  """

  alias CB.Belief

  @doc """
  All rows in the contract's `rules`, as-is (list of string-keyed maps).

  Datalog: `?- row(C1, C2, ..., Cn).`
  """
  @spec rows(Belief.t()) :: [map()]
  def rows(%Belief{rules: rules}) do
    rules || []
  end

  @doc """
  Rows matching all key-value pairs in `conditions`.

  Returns a list of matching rows (maps). Empty list if no match.
  Conditions are AND-ed: every key in the conditions map must match
  the row's value for that key.

  Datalog: `?- row(...), K1 = v1, K2 = v2.`
  """
  @spec lookup(Belief.t(), map()) :: [map()]
  def lookup(%Belief{} = contract, conditions) when is_map(conditions) do
    contract
    |> rows()
    |> Enum.filter(fn row ->
      Enum.all?(conditions, fn {k, v} -> row[k] == v end)
    end)
  end

  @doc """
  All distinct values for the given column across the contract's rows.

  Datalog: `?- row(..., Col, ...).` with distinct Col
  """
  @spec column_values(Belief.t(), String.t()) :: [any()]
  def column_values(%Belief{} = contract, column) do
    contract
    |> rows()
    |> Enum.map(& &1[column])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  True if at least one row matches all conditions.

  Datalog: `?- row(...), K1 = v1, K2 = v2.` as satisfiability
  """
  @spec has_match?(Belief.t(), map()) :: boolean()
  def has_match?(%Belief{} = contract, conditions) do
    lookup(contract, conditions) != []
  end

  @doc """
  All column names present across the contract's rows.

  Returns a sorted list of unique string keys. Useful for schema
  introspection and validation.
  """
  @spec columns(Belief.t()) :: [String.t()]
  def columns(%Belief{} = contract) do
    contract
    |> rows()
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
