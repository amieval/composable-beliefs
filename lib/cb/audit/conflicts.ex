defmodule CB.Audit.Conflicts do
  @moduledoc """
  Detect potential conflicts in the DAG. Makes contradictions expensive
  by surfacing them.

  The audit runs three detectors:

  - **Stale overrides** - active nodes whose deps include superseded or
    retracted nodes. Delegates to `CB.Belief.Graph.stale/1`.

  - **Scope overlaps** - pairs of active directives that share scope
    (domain + tags + subjects). Overlap does not imply contradiction;
    it means the nodes are close enough that a contradiction would be
    meaningful. The agent interprets whether a pair actually contradicts,
    is redundant, or is compatible.

  - **Scope classification** - each pair is tagged with the reason for
    overlap (shared tags, shared subject refs, shared subject types, or
    domain-global).

  The design accepts that semantic conflict detection (do two claims
  actually contradict?) requires LLM judgment. This audit surfaces
  candidate pairs; the reviewer decides.

  ## Scope rules

  Two active directives share scope iff:

  1. They are in the same domain (or both have no domain), AND
  2. At least one of:
     - They share a tag
     - They share a subject ref
     - They share a subject type
     - Both have empty tags and subjects (domain-global in same domain)

  Different non-nil domains means no overlap regardless of other fields.
  """

  alias CB.Belief
  alias CB.Belief.Store, as: BeliefStore
  alias CB.Belief.Graph

  @doc """
  Run the full conflict scan.

  ## Options

  - `:tag` - only consider nodes with this tag
  - `:domain` - only consider nodes in this domain
  - `:id` - only consider nodes that share scope with this node ID
  - `:contracts_only` - limit to contract-grade directives

  Returns a map with `:stale_overrides`, `:scope_overlaps`, and summary counts.
  """
  def scan(opts \\ []) do
    with {:ok, all} <- BeliefStore.read() do
      directives =
        all
        |> Enum.filter(&(&1.type == "directive" and &1.status == "active"))
        |> maybe_filter(opts)

      %{
        stale_overrides: stale_overrides(all),
        scope_overlaps: scope_overlaps(directives),
        total_directives: length(directives),
        total_nodes: length(all)
      }
    end
  end

  @doc "Find all active directives that share scope with a given node."
  def related(node_id, opts \\ []) do
    with {:ok, all} <- BeliefStore.read(),
         {:ok, target} <- find_node(all, node_id) do
      others =
        all
        |> Enum.filter(&(&1.type == "directive" and &1.status == "active" and &1.id != node_id))
        |> maybe_filter(opts)

      overlaps =
        for b <- others,
            reason = overlap_reason(target, b),
            reason != nil do
          {target, b, reason}
        end

      {:ok, overlaps}
    end
  end

  @doc "Detect direct scope overlap between two nodes. Returns reason or nil."
  def overlap_reason(a, b) do
    cond do
      # Self-comparison isn't overlap
      a.id == b.id ->
        nil

      # Different non-nil domains = no overlap
      a.domain != nil and b.domain != nil and a.domain != b.domain ->
        nil

      # Shared tag
      (shared = shared_tags(a, b)) != [] ->
        {:shared_tags, shared}

      # Shared subject ref
      (shared = shared_subject_refs(a, b)) != [] ->
        {:shared_subject_refs, shared}

      # Shared subject type
      (shared = shared_subject_types(a, b)) != [] ->
        {:shared_subject_types, shared}

      # Both domain-global (no tags, no subjects) in the same domain
      a.domain != nil and a.domain == b.domain and
        (a.tags || []) == [] and (b.tags || []) == [] and
        (a.subjects || []) == [] and (b.subjects || []) == [] ->
        {:domain_global, a.domain}

      true ->
        nil
    end
  end

  # --- Private ---

  defp stale_overrides(all) do
    # Graph.stale returns [{node, stale_dep_ids}, ...]
    # Restrict to active nodes, since only they would act on bad deps.
    all
    |> Graph.stale()
    |> Enum.filter(fn {node, _bad} -> node.status == "active" end)
  end

  defp scope_overlaps(nodes) do
    # All unordered pairs. Use id comparison to enforce ordering once.
    for a <- nodes,
        b <- nodes,
        a.id < b.id,
        reason = overlap_reason(a, b),
        reason != nil do
      {a, b, reason}
    end
  end

  defp maybe_filter(nodes, opts) do
    nodes
    |> maybe_filter_tag(Keyword.get(opts, :tag))
    |> maybe_filter_domain(Keyword.get(opts, :domain))
    |> maybe_filter_contracts(Keyword.get(opts, :contracts_only, false))
  end

  defp maybe_filter_tag(nodes, nil), do: nodes
  defp maybe_filter_tag(nodes, tag), do: Enum.filter(nodes, &(tag in (&1.tags || [])))

  defp maybe_filter_domain(nodes, nil), do: nodes
  defp maybe_filter_domain(nodes, dom), do: Enum.filter(nodes, &(&1.domain == dom))

  defp maybe_filter_contracts(nodes, false), do: nodes
  defp maybe_filter_contracts(nodes, true), do: Enum.filter(nodes, &Belief.contract?/1)

  defp shared_tags(a, b) do
    a_tags = MapSet.new(a.tags || [])
    b_tags = MapSet.new(b.tags || [])
    MapSet.intersection(a_tags, b_tags) |> MapSet.to_list()
  end

  defp shared_subject_refs(a, b) do
    a_refs = (a.subjects || []) |> Enum.map(& &1["ref"]) |> MapSet.new()
    b_refs = (b.subjects || []) |> Enum.map(& &1["ref"]) |> MapSet.new()
    MapSet.intersection(a_refs, b_refs) |> MapSet.to_list()
  end

  defp shared_subject_types(a, b) do
    a_types = (a.subjects || []) |> Enum.map(& &1["type"]) |> MapSet.new()
    b_types = (b.subjects || []) |> Enum.map(& &1["type"]) |> MapSet.new()
    MapSet.intersection(a_types, b_types) |> MapSet.to_list()
  end

  defp find_node(all, id) do
    case Enum.find(all, &(&1.id == id)) do
      nil -> {:error, {:not_found, id}}
      node -> {:ok, node}
    end
  end
end
