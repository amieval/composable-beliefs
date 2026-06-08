defmodule CB.Belief do
  @moduledoc """
  Belief struct and JSON serialization.

  Beliefs are the nodes of the composable beliefs DAG - structured claims
  about the world that the agent can query, compose, and act on. Stored
  in the belief graph JSON file (see `CB.Config.beliefs_path/0`).

  ## Self-referential schema

  The DAG's own schema can be expressed as contracts in the DAG. Those
  contracts are the source of truth - this moduledoc points, it does
  not restate. Use `mix cb.verify.schema` to check this module against
  the contracts mechanically.

  By convention the schema discipline is split across a small family of
  contracts:

  | Contract | Governs |
  |---|---|
  | master schema | artifact field, contract field, enum-validated kind/domain/artifact-scheme |
  | kind enum | canonical kind values |
  | artifact-scheme enum | canonical artifact-scheme values |
  | domain enum | canonical domain values |
  | status lifecycle | status lifecycle and immutability |

  The `confidence`, `source`, and `implication` fields were expunged from
  earlier revisions of the schema: confidence as a subjective metric doing
  no load-bearing work, `source` renamed to the structured `:artifact`
  field, and `:implication` deleted in favor of a structural `:contract`
  boolean marking contract-grade implications. Use `CB.Belief.support/1`
  for structural-support metrics derived from the belief's own graph
  position.

  ## Struct summary

  Three structural types (`primitive`, `compound`, `implication`) are the
  only values of the `type` field. Contract-grade implications carry
  `contract: true` and non-empty `rules` and/or `invariants`; detect them
  via `CB.Belief.contract?/1`. `kind`, `domain`, and the artifact's scheme
  are enum-validated. `tags` is a flat list of strings for cross-cutting
  concerns.
  """

  @types ~w(primitive compound implication)
  @statuses ~w(active superseded retracted retired)

  @fields [
    :id,
    :type,
    :kind,
    :domain,
    :tags,
    :name,
    :who,
    :claim,
    :rules,
    :invariants,
    :contract,
    :artifact,
    :evidence,
    :subjects,
    :deps,
    :materialized,
    :status,
    :superseded_by,
    :retracted_on,
    :retracted_reason,
    :created,
    :_keys
  ]

  @ordered_keys ~w(id type kind domain tags name who claim rules invariants contract artifact evidence subjects deps materialized status superseded_by retracted_on retracted_reason created)

  # Canonical inner-key orders for nested objects. Matches existing data
  # convention so round-trips are byte-stable. Extra keys (not listed)
  # are appended in their original insertion order.
  @evidence_key_order ~w(date detail artifact proposed sent section)
  @subject_key_order ~w(ref type)

  defstruct @fields

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: String.t(),
          kind: String.t() | nil,
          domain: String.t() | nil,
          tags: list(String.t()),
          name: String.t() | nil,
          who: String.t() | nil,
          claim: String.t() | nil,
          rules: list(map()),
          invariants: list(String.t()),
          contract: boolean() | nil,
          artifact: String.t() | nil,
          evidence: list(map()),
          subjects: list(map()),
          deps: list(String.t()),
          materialized: map() | nil,
          status: String.t() | nil,
          superseded_by: String.t() | nil,
          retracted_on: String.t() | nil,
          retracted_reason: String.t() | nil,
          created: String.t() | nil,
          _keys: MapSet.t() | nil
        }

  @doc """
  Check if a belief is contract-grade.

  Reads the structural `:contract` field. The biconditional with non-empty
  `rules`/`invariants` is enforced by `mix cb.verify.schema`; this predicate
  trusts the field.
  """
  def contract?(%__MODULE__{contract: true}), do: true
  def contract?(_), do: false

  @doc "Valid structural types."
  def types, do: @types

  @doc "Valid status values."
  def statuses, do: @statuses

  @doc """
  Structural-support metrics derived from the belief's own graph
  position.

  Replaces the retired `confidence` field. Returns a map of
  deterministic counts - no subjective scoring. Callers that need a
  ranking signal should aggregate or weight these structural facts;
  there is no single scalar.

  Fields:
  - `:artifact_count` - distinct artifacts across the belief's own
    `artifact` field + its evidence entries' `artifact` fields
  - `:evidence_count` - count of evidence entries
  - `:dep_count` - count of upstream dependencies

  Inbound reference count (how many beliefs cite this one) requires
  graph traversal and is exposed separately via `CB.Belief.Graph`.
  """
  @spec support(t()) :: %{
          artifact_count: non_neg_integer(),
          evidence_count: non_neg_integer(),
          dep_count: non_neg_integer()
        }
  def support(%__MODULE__{} = b) do
    evidence_artifacts =
      (b.evidence || [])
      |> Enum.map(fn e -> e["artifact"] end)
      |> Enum.reject(&is_nil/1)

    artifacts =
      [b.artifact | evidence_artifacts]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    %{
      artifact_count: length(artifacts),
      evidence_count: length(b.evidence || []),
      dep_count: length(b.deps || [])
    }
  end

  @doc "Convert a JSON map (string keys) to a Belief struct."
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      type: map["type"],
      kind: map["kind"],
      domain: map["domain"],
      tags: map["tags"] || [],
      name: map["name"],
      who: map["who"],
      claim: map["claim"],
      rules: map["rules"] || [],
      invariants: map["invariants"] || [],
      contract: map["contract"],
      artifact: map["artifact"],
      evidence: map["evidence"] || [],
      subjects: map["subjects"] || [],
      deps: map["deps"] || [],
      materialized: map["materialized"],
      status: map["status"],
      superseded_by: map["superseded_by"],
      retracted_on: map["retracted_on"],
      retracted_reason: map["retracted_reason"],
      created: map["created"],
      _keys:
        MapSet.new(Map.keys(map))
        |> MapSet.delete("confidence")
        |> MapSet.delete("source")
        |> MapSet.delete("implication")
    }
  end

  @doc "Convert a Belief struct to a `Jason.OrderedObject` for serialization."
  def to_map(%__MODULE__{} = a) do
    present_keys = a._keys || MapSet.new(@ordered_keys)

    pairs =
      for key <- @ordered_keys, MapSet.member?(present_keys, key) do
        atom = String.to_existing_atom(key)
        value = Map.get(a, atom)
        {key, order_nested(key, value)}
      end

    Jason.OrderedObject.new(pairs)
  end

  # Wrap nested evidence/subject items so their inner keys serialize in
  # canonical order, preventing churn on round-trips.
  defp order_nested("evidence", items) when is_list(items) do
    Enum.map(items, &order_map(&1, @evidence_key_order))
  end

  defp order_nested("subjects", items) when is_list(items) do
    Enum.map(items, &order_map(&1, @subject_key_order))
  end

  defp order_nested(_key, value), do: value

  defp order_map(map, key_order) when is_map(map) and not is_struct(map) do
    known =
      for key <- key_order, Map.has_key?(map, key) do
        {key, Map.get(map, key)}
      end

    # Preserve any extra keys not in the canonical order at the end,
    # sorted for determinism.
    extra =
      map
      |> Map.drop(key_order)
      |> Enum.sort_by(fn {k, _} -> k end)

    Jason.OrderedObject.new(known ++ extra)
  end

  defp order_map(value, _), do: value
end
