defmodule CB.Belief.Graph do
  @moduledoc """
  Graph operations on the composable beliefs DAG. Pure deterministic traversal -
  no LLM reasoning, same input always produces same output.

  All functions take an index (map of id => belief) built from the
  full belief list. Build once with `index/1`, pass to all operations.
  """

  @doc "Build an id => belief lookup map."
  def index(beliefs), do: Map.new(beliefs, &{&1.id, &1})

  @doc """
  Resolve a possibly-bare id to its canonical id.

  An id that matches a belief exactly resolves to itself. A bare local id
  (`c029`) resolves to the single namespaced belief whose local part
  matches (`cb:c029`). Returns `{:error, :not_found}` when nothing matches,
  or `{:error, {:ambiguous, ids}}` when a bare id matches more than one
  namespace.
  """
  def resolve_id(beliefs, id) do
    ids = Enum.map(beliefs, & &1.id)

    if id in ids do
      {:ok, id}
    else
      case Enum.filter(ids, &(local_id(&1) == id)) do
        [canonical] -> {:ok, canonical}
        [] -> {:error, :not_found}
        many -> {:error, {:ambiguous, Enum.sort(many)}}
      end
    end
  end

  # Local part of an id: everything after the namespace prefix
  # (`cb:c029` -> `c029`). A bare id is its own local part.
  defp local_id(id), do: id |> String.split(":") |> List.last()

  @doc "Direct dependencies of a belief."
  def deps(%{deps: deps}, _index) when is_list(deps), do: deps
  def deps(_, _), do: []

  @doc "Resolve dep IDs to belief structs."
  def resolve_deps(belief, index) do
    belief
    |> deps(index)
    |> Enum.map(&Map.get(index, &1))
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  All beliefs that depend on the given ID (reverse lookup).
  Returns direct dependents only unless `deep: true`.
  """
  def dependents(id, beliefs, opts \\ []) do
    direct =
      Enum.filter(beliefs, fn a ->
        is_list(a.deps) and id in a.deps
      end)

    if Keyword.get(opts, :deep, false) do
      deep_dependents(Enum.map(direct, & &1.id), beliefs, MapSet.new([id]))
    else
      direct
    end
  end

  defp deep_dependents([], _beliefs, _visited), do: []

  defp deep_dependents(ids, beliefs, visited) do
    new_visited = MapSet.union(visited, MapSet.new(ids))

    direct =
      Enum.filter(beliefs, fn a ->
        is_list(a.deps) and Enum.any?(a.deps, &(&1 in ids)) and
          a.id not in visited
      end)

    next_ids =
      direct
      |> Enum.map(& &1.id)
      |> Enum.reject(&MapSet.member?(new_visited, &1))

    direct ++ deep_dependents(next_ids, beliefs, new_visited)
  end

  @doc """
  Find a dependency path from `from_id` to `to_id`.
  Returns `{:ok, [id1, id2, ...]}` or `:no_path`.
  Searches both downstream (deps) and upstream (dependents).
  """
  def path(from_id, to_id, index, beliefs) do
    case bfs_path(from_id, to_id, index, :down, beliefs) do
      {:ok, p} -> {:ok, p}
      :no_path ->
        case bfs_path(from_id, to_id, index, :up, beliefs) do
          {:ok, p} -> {:ok, p}
          :no_path -> :no_path
        end
    end
  end

  defp bfs_path(from, to, _index, _dir, _beliefs) when from == to, do: {:ok, [from]}

  defp bfs_path(from, to, index, dir, beliefs) do
    queue = :queue.in({from, [from]}, :queue.new())
    bfs_step(queue, to, index, dir, beliefs, MapSet.new([from]))
  end

  defp bfs_step(queue, to, index, dir, beliefs, visited) do
    case :queue.out(queue) do
      {:empty, _} ->
        :no_path

      {{:value, {current, path}}, rest} ->
        neighbors = case dir do
          :down ->
            case Map.get(index, current) do
              nil -> []
              a -> a.deps || []
            end
          :up ->
            beliefs
            |> Enum.filter(fn a -> is_list(a.deps) and current in a.deps end)
            |> Enum.map(& &1.id)
        end

        case Enum.find(neighbors, &(&1 == to)) do
          nil ->
            {new_queue, new_visited} =
              Enum.reduce(neighbors, {rest, visited}, fn n, {q, v} ->
                if MapSet.member?(v, n) do
                  {q, v}
                else
                  {:queue.in({n, path ++ [n]}, q), MapSet.put(v, n)}
                end
              end)
            bfs_step(new_queue, to, index, dir, beliefs, new_visited)

          _ ->
            {:ok, path ++ [to]}
        end
    end
  end

  @doc """
  Supersession history for a belief.
  Returns `{predecessors, successors}` where each is a list of beliefs
  in chronological order.
  """
  def history(id, beliefs) do
    idx = index(beliefs)
    successors = walk_successors(id, idx)
    predecessors = walk_predecessors(id, beliefs)
    {Enum.reverse(predecessors), successors}
  end

  defp walk_successors(id, index, visited \\ MapSet.new()) do
    if MapSet.member?(visited, id) do
      []
    else
      case Map.get(index, id) do
        nil -> []
        a ->
          case a.superseded_by do
            nil -> []
            next_id ->
              case Map.get(index, next_id) do
                nil -> []
                next -> [next | walk_successors(next_id, index, MapSet.put(visited, id))]
              end
          end
      end
    end
  end

  defp walk_predecessors(id, beliefs, visited \\ MapSet.new()) do
    if MapSet.member?(visited, id) do
      []
    else
      case Enum.find(beliefs, &(&1.superseded_by == id)) do
        nil -> []
        pred -> [pred | walk_predecessors(pred.id, beliefs, MapSet.put(visited, id))]
      end
    end
  end

  @doc """
  Find stale beliefs with optional cascade detection.
  Returns list of `{belief, stale_deps}` tuples.
  """
  def stale(beliefs, opts \\ []) do
    idx = index(beliefs)
    cascade = Keyword.get(opts, :cascade, false)

    superseded_ids =
      beliefs
      |> Enum.filter(&(&1.status in ~w(superseded retracted)))
      |> Enum.map(& &1.id)
      |> MapSet.new()

    direct_stale =
      beliefs
      |> Enum.filter(fn a ->
        a.type != "primitive" and a.status == "active" and
          Enum.any?(a.deps || [], &MapSet.member?(superseded_ids, &1))
      end)
      |> Enum.map(fn a ->
        bad = Enum.filter(a.deps || [], &MapSet.member?(superseded_ids, &1))
        {a, bad}
      end)

    if cascade do
      direct_ids = MapSet.new(Enum.map(direct_stale, fn {a, _} -> a.id end))
      cascade_stale(beliefs, idx, direct_stale, direct_ids, superseded_ids)
    else
      direct_stale
    end
  end

  defp cascade_stale(beliefs, idx, found, found_ids, problem_ids) do
    all_problem = MapSet.union(problem_ids, found_ids)

    next =
      beliefs
      |> Enum.filter(fn a ->
        a.type != "primitive" and a.status == "active" and
          not MapSet.member?(found_ids, a.id) and
          Enum.any?(a.deps || [], &MapSet.member?(found_ids, &1))
      end)
      |> Enum.map(fn a ->
        bad = Enum.filter(a.deps || [], &MapSet.member?(all_problem, &1))
        {a, bad}
      end)

    if next == [] do
      found
    else
      next_ids = MapSet.new(Enum.map(next, fn {a, _} -> a.id end))
      cascade_stale(beliefs, idx, found ++ next, MapSet.union(found_ids, next_ids), all_problem)
    end
  end

  @doc "Find all beliefs about a given subject ref or type."
  def by_subject(beliefs, ref: ref) do
    Enum.filter(beliefs, fn a ->
      Enum.any?(a.subjects || [], fn s -> s["ref"] == ref end)
    end)
  end

  def by_subject(beliefs, type: type) do
    Enum.filter(beliefs, fn a ->
      Enum.any?(a.subjects || [], fn s -> s["type"] == type end)
    end)
  end

  @doc "Aggregate statistics across the graph."
  def stats(beliefs) do
    active = Enum.filter(beliefs, &(&1.status == "active"))

    by_type = Enum.frequencies_by(beliefs, & &1.type)
    by_status = Enum.frequencies_by(beliefs, & &1.status)

    stale_count = length(stale(beliefs))

    unlinked =
      active
      |> Enum.count(&(&1.type == "implication" and &1.materialized == nil))

    artifact_schemes =
      beliefs
      |> Enum.filter(&(&1.type == "primitive" and &1.artifact != nil))
      |> Enum.map(fn a ->
        case String.split(a.artifact, ":", parts: 2) do
          [scheme, _] -> scheme
          [single] -> single
        end
      end)
      |> Enum.frequencies()

    dep_depths =
      active
      |> Enum.filter(&(&1.type != "primitive"))
      |> Enum.map(&max_depth(&1.id, index(beliefs), MapSet.new()))
      |> Enum.sort()

    # Most depended-on: count how many times each ID appears in deps
    dep_counts =
      beliefs
      |> Enum.filter(&(&1.status == "active"))
      |> Enum.flat_map(&(&1.deps || []))
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_id, count} -> -count end)
      |> Enum.take(5)

    %{
      total: length(beliefs),
      by_type: by_type,
      by_status: by_status,
      stale_count: stale_count,
      unlinked_implications: unlinked,
      artifact_schemes: artifact_schemes,
      dep_depths: dep_depths,
      most_depended: dep_counts
    }
  end

  defp max_depth(id, index, visited) do
    if MapSet.member?(visited, id) do
      0
    else
      case Map.get(index, id) do
        nil -> 0
        a ->
          deps = a.deps || []
          if deps == [] do
            0
          else
            new_visited = MapSet.put(visited, id)
            1 + (deps |> Enum.map(&max_depth(&1, index, new_visited)) |> Enum.max(fn -> 0 end))
          end
      end
    end
  end
end
