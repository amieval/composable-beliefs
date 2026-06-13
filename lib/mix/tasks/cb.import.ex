defmodule Mix.Tasks.Cb.Import do
  @moduledoc """
  Import belief nodes from a JSON specification file.

  Designed for batch additions (phase rollouts, policy migrations).
  The Elixir-native alternative to disposable scripts.

  ## Usage

      mix cb.import <spec.json>            # Dry run
      mix cb.import <spec.json> --write    # Apply
      mix cb.import <spec.json> --write --beliefs path/to/collection/beliefs.json

  `--beliefs PATH` points import at an alternate belief graph for one
  invocation (the same override the belief shell and preflight take), so a
  belief can be written into a non-default collection without exporting
  `CB_BELIEFS`. Both read and write honor the override.

  ## Spec format

  ```json
  {
    "new_beliefs": [
      {
        "id": "cb:a305",
        "type": "primitive",
        "kind": "convention",
        "domain": "dev",
        "tags": ["docs"],
        "claim": "...",
        "artifact": "policy:house-style",
        "evidence": [],
        "subjects": [],
        "status": "active",
        "created": "2026-04-12"
      }
    ],
    "backfills": [
      {
        "id": "cb:a044",
        "updates": {"domain": "agent", "tags": ["agent-role"]}
      }
    ]
  }
  ```

  Backfills only fill empty fields (nil domain, [] tags). Never stomp
  existing values - safer for incremental cleanup.

  ## Validation

  Exits non-zero before writing if:
  - New belief IDs lack the graph's namespace prefix (bare `a305` in a
    `cb:`-namespaced graph) - bare ids land silently inconsistent: every
    namespaced lookup and intra-batch dep dangles
  - New belief IDs collide with existing nodes
  - Backfill target IDs don't exist
  - Spec file is malformed

  After successful write, run `mix cb.verify.schema` to confirm the
  batch conforms to the self-referential contracts.
  """
  @shortdoc "Import belief nodes from a JSON spec file"

  use Mix.Task

  alias CB.Belief
  alias CB.Belief.Store

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args, strict: [write: :boolean, beliefs: :string])

    if opts[:beliefs], do: Application.put_env(:cb, :beliefs_path, opts[:beliefs])

    write? = opts[:write] || false

    case positional do
      [spec_path] ->
        run_with_spec(spec_path, write?)

      _ ->
        IO.puts(:stderr, "Usage: mix cb.import <spec.json> [--write]")
        System.halt(1)
    end
  end

  defp run_with_spec(spec_path, write?) do
    with {:ok, content} <- File.read(spec_path),
         {:ok, spec} <- Jason.decode(content),
         {:ok, all} <- Store.read() do
      new_beliefs = spec["new_beliefs"] || []
      backfills = spec["backfills"] || []

      existing_ids = MapSet.new(all, & &1.id)

      with :ok <- validate_namespace_consistency(new_beliefs, all),
           :ok <- validate_new_ids(new_beliefs, existing_ids),
           :ok <- validate_no_duplicate_new_ids(new_beliefs),
           :ok <- validate_backfill_targets(backfills, existing_ids) do
        report(new_beliefs, backfills)

        if write? do
          apply_changes(all, new_beliefs, backfills)
        else
          IO.puts(:stderr, "\nDry run. Pass --write to apply.")
        end
      end
    else
      {:error, %Jason.DecodeError{} = err} ->
        IO.puts(:stderr, "Error: malformed JSON in spec: #{Exception.message(err)}")
        System.halt(1)

      {:error, :enoent} ->
        IO.puts(:stderr, "Error: spec file not found: #{spec_path}")
        System.halt(1)

      {:error, reason} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  @doc """
  Ids in `new_beliefs` that lack the graph's namespace prefix.

  Returns `{namespace, offending_ids}`. The graph's namespace is the single
  prefix every existing id shares (`cb:a001` -> `"cb"`); a graph with no
  nodes, or with mixed or bare ids, declares no namespace and the result is
  `{nil, []}` - nothing to be consistent with. Pure - the halting wrapper
  around it is `run/1`'s concern.
  """
  @spec namespace_violations([map()], [CB.Belief.t()]) :: {String.t() | nil, [String.t()]}
  def namespace_violations(new_beliefs, existing) do
    case graph_namespace(existing) do
      nil ->
        {nil, []}

      ns ->
        prefix = ns <> ":"

        bad =
          new_beliefs
          |> Enum.map(& &1["id"])
          |> Enum.reject(&(is_binary(&1) and String.starts_with?(&1, prefix)))

        {ns, bad}
    end
  end

  # The single namespace prefix shared by every existing id, or nil.
  defp graph_namespace(existing) do
    existing
    |> Enum.map(fn b ->
      case String.split(b.id, ":", parts: 2) do
        [ns, _] -> ns
        _ -> nil
      end
    end)
    |> Enum.uniq()
    |> case do
      [ns] when is_binary(ns) -> ns
      _ -> nil
    end
  end

  defp validate_namespace_consistency(new_beliefs, all) do
    case namespace_violations(new_beliefs, all) do
      {_, []} ->
        :ok

      {ns, bad} ->
        IO.puts(
          :stderr,
          "Error: new-belief ids missing the graph's #{ns}: namespace prefix: #{inspect(bad)}\n" <>
            "Write spec ids namespaced (#{ns}:a305, not a305) - bare ids land " <>
            "inconsistent and namespaced lookups and deps dangle."
        )

        System.halt(1)
    end
  end

  defp validate_new_ids(new_beliefs, existing_ids) do
    collisions =
      new_beliefs
      |> Enum.filter(&MapSet.member?(existing_ids, &1["id"]))
      |> Enum.map(& &1["id"])

    if collisions == [] do
      :ok
    else
      IO.puts(:stderr, "Error: ID collisions with existing nodes: #{inspect(collisions)}")
      System.halt(1)
    end
  end

  defp validate_no_duplicate_new_ids(new_beliefs) do
    ids = Enum.map(new_beliefs, & &1["id"])
    dupes = ids -- Enum.uniq(ids)

    if dupes == [] do
      :ok
    else
      IO.puts(:stderr, "Error: duplicate IDs within spec: #{inspect(Enum.uniq(dupes))}")
      System.halt(1)
    end
  end

  defp validate_backfill_targets(backfills, existing_ids) do
    missing =
      backfills
      |> Enum.reject(&MapSet.member?(existing_ids, &1["id"]))
      |> Enum.map(& &1["id"])

    if missing == [] do
      :ok
    else
      IO.puts(:stderr, "Error: backfill targets not in DAG: #{inspect(missing)}")
      System.halt(1)
    end
  end

  defp report(new_beliefs, backfills) do
    IO.puts("Belief import")
    IO.puts(String.duplicate("=", 40))

    IO.puts("\nNew beliefs: #{length(new_beliefs)}")

    Enum.each(new_beliefs, fn b ->
      IO.puts("  #{b["id"]} (#{b["type"]}/#{b["kind"]})")
    end)

    IO.puts("\nBackfills: #{length(backfills)}")

    Enum.each(backfills, fn b ->
      IO.puts("  #{b["id"]}: #{inspect(b["updates"])}")
    end)
  end

  defp apply_changes(all, new_beliefs, backfills) do
    # Apply backfills first (operate on existing structs)
    backfill_map = Map.new(backfills, &{&1["id"], &1["updates"]})

    updated_existing =
      Enum.map(all, fn node ->
        case Map.get(backfill_map, node.id) do
          nil -> node
          updates -> apply_backfill(node, updates)
        end
      end)

    # Build new structs from the spec
    new_structs = Enum.map(new_beliefs, &Belief.from_map/1)

    final = updated_existing ++ new_structs

    case Store.write(final) do
      {:ok, _path} ->
        IO.puts(:stderr, "\nWrote #{length(final)} beliefs total (#{length(new_structs)} new)")
        IO.puts(:stderr, "Run `mix cb.verify.schema` to check conformance.")

      {:error, reason} ->
        IO.puts(:stderr, "Error writing belief graph: #{inspect(reason)}")
        System.halt(1)
    end
  end

  # Apply field updates to a belief struct, but only for empty fields.
  # Also ensures the field key is tracked in _keys so serialization emits it.
  defp apply_backfill(node, updates) do
    Enum.reduce(updates, node, fn {key, value}, acc ->
      atom = String.to_existing_atom(key)
      current = Map.get(acc, atom)

      if empty_value?(current) do
        acc
        |> Map.put(atom, value)
        |> add_to_keys(key)
      else
        acc
      end
    end)
  end

  defp empty_value?(nil), do: true
  defp empty_value?([]), do: true
  defp empty_value?(""), do: true
  defp empty_value?(_), do: false

  defp add_to_keys(%{_keys: keys} = struct, key) when is_struct(keys, MapSet) do
    %{struct | _keys: MapSet.put(keys, key)}
  end

  defp add_to_keys(struct, key) do
    # Defensive: if _keys is missing or not a MapSet, initialize from the key.
    %{struct | _keys: MapSet.new([key])}
  end
end
