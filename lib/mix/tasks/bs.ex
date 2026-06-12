defmodule Mix.Tasks.Bs do
  @moduledoc """
  Belief shell - deterministic query interface to the composable beliefs DAG.

  Pure graph traversal - no LLM reasoning, same input always produces
  the same output.

      list [filters]       List beliefs matching filters
      show <id>            Full detail on a single belief
      tree <id>            Dependency tree visualization
      deps <id>            Direct dependencies (--deep for full tree)
      dependents <id>      Reverse dependency lookup (--deep for transitive)
      stale                Find beliefs with superseded/retracted deps (--cascade)
      recent               Graph changes in a window (--since DATE | --days N)
      path <id1> <id2>     Find connection between two beliefs
      history <id>         Supersession chain
      subjects <ref|type>  Find beliefs by subject
      stats                Graph-level statistics

  ## Ids

  Ids may be given bare (`c029`) or namespaced (`cb:c029`). A bare local id
  resolves to its namespaced form when exactly one belief matches; if more
  than one namespace carries that local id, qualify it explicitly. `mix bs
  <id>` with no verb is shorthand for `show`.

  ## Collections

  `--beliefs PATH` points the shell at an alternate belief graph for one
  command (the `CB_BELIEFS` env var does the same persistently) - used to
  explore other belief collections without touching the main graph.

  ## Filters (for list)

      primitive|compound|inference|directive    Filter by structural type
      active|superseded|retracted|all   Filter by status (default: active)
      contracts                         Contract-grade directives only
      unlinked                          Directives with no materialized items
      tag:<tag> / --tag <tag>           Filter by tag
      kind:<kind>                       Filter by semantic kind
      domain:<domain>                   Filter by domain
      subject_type:<type>              Filter by subject type
      <namespace>/<ref>                Filter by subject ref
      -v / --verbose                    Show full detail
  """
  @shortdoc "Belief shell - query and traverse the composable beliefs DAG"

  use Mix.Task

  import CB.Display

  alias CB.Belief.{Filter, Formatter, Graph, Store}

  @impl Mix.Task
  def run(args) do
    args = apply_beliefs_override(args)
    {flags, positional} = extract_flags(args)

    case positional do
      ["list" | rest] ->
        cmd_list(rest ++ flag_args(flags))

      ["show", id | _] ->
        cmd_show(id)

      ["tree", id | _] ->
        cmd_tree(id)

      ["deps", id | _] ->
        cmd_deps(id, flags)

      ["dependents", id | _] ->
        cmd_dependents(id, flags)

      ["stale" | _] ->
        cmd_stale(flags)

      ["recent" | _] ->
        cmd_recent(flags)

      ["path", id1, id2 | _] ->
        cmd_path(id1, id2)

      ["history", id | _] ->
        cmd_history(id)

      ["subjects" | rest] ->
        cmd_subjects(rest)

      ["stats" | _] ->
        cmd_stats()

      ["help" | _] ->
        cmd_help()

      [] ->
        cmd_help()

      [cmd | _] ->
        if Regex.match?(~r/^([a-z][a-z0-9-]*:)?[ac]\d+$/, cmd) do
          cmd_show(cmd)
        else
          IO.puts(:stderr, "Unknown command: #{cmd}")
          IO.puts(:stderr, "Run `mix bs help` for usage.")
          System.halt(1)
        end
    end
  end

  # --- Commands ---

  defp cmd_list(args) do
    {filters, opts} = Filter.parse_args(args)

    for arg <- Keyword.get_values(opts, :unknown) do
      IO.puts(:stderr, "Unknown filter: #{arg}")
      System.halt(1)
    end

    {:ok, beliefs} = Store.read()
    total = length(beliefs)

    filtered = beliefs |> Filter.apply_filters(filters) |> Filter.sort()

    lines =
      if Keyword.get(opts, :verbose) do
        Enum.flat_map(filtered, &Formatter.detail/1) ++
          ["#{length(filtered)} beliefs (of #{total} total)"]
      else
        Formatter.table(filtered, total)
      end

    Enum.each(lines, &IO.puts/1)
  end

  defp cmd_show(id) do
    {:ok, beliefs} = Store.read()
    id = resolve_or_halt(beliefs, id)
    belief = Enum.find(beliefs, &(&1.id == id))
    Formatter.detail(belief) |> Enum.each(&IO.puts/1)
  end

  defp cmd_tree(id) do
    {:ok, beliefs} = Store.read()
    id = resolve_or_halt(beliefs, id)
    belief = Enum.find(beliefs, &(&1.id == id))
    Formatter.tree(belief, beliefs) |> Enum.each(&IO.puts/1)
  end

  defp cmd_deps(id, flags) do
    {:ok, beliefs} = Store.read()
    id = resolve_or_halt(beliefs, id)
    idx = Graph.index(beliefs)
    belief = Map.get(idx, id)

    if Keyword.get(flags, :deep) do
      cmd_tree(id)
    else
      resolved = Graph.resolve_deps(belief, idx)

      if resolved == [] do
        IO.puts("#{id} has no dependencies (primitive).")
      else
        Formatter.table(resolved, length(beliefs)) |> Enum.each(&IO.puts/1)
      end
    end
  end

  defp cmd_dependents(id, flags) do
    {:ok, beliefs} = Store.read()
    id = resolve_or_halt(beliefs, id)
    deep = Keyword.get(flags, :deep, false)
    results = Graph.dependents(id, beliefs, deep: deep)

    if results == [] do
      IO.puts("Nothing depends on #{id}.")
    else
      label = if deep, do: "deep dependents", else: "dependents"
      IO.puts("")
      IO.puts("#{length(results)} #{label} of #{id}:")
      IO.puts("")
      Formatter.table(results, length(beliefs)) |> Enum.each(&IO.puts/1)
    end
  end

  defp cmd_stale(flags) do
    {:ok, beliefs} = Store.read()
    cascade = Keyword.get(flags, :cascade, false)
    results = Graph.stale(beliefs, cascade: cascade)

    if results == [] do
      IO.puts("No stale beliefs found.")
    else
      idx = Graph.index(beliefs)
      label = if cascade, do: " (with cascade)", else: ""
      IO.puts("")
      IO.puts("Stale beliefs#{label}:")
      IO.puts("")

      Enum.each(results, fn {a, bad_deps} ->
        IO.puts("  #{a.id} #{a.claim}")

        Enum.each(bad_deps, fn dep_id ->
          dep = Map.get(idx, dep_id)

          reason =
            cond do
              dep == nil -> "missing"
              dep.superseded_by -> "superseded by #{dep.superseded_by}"
              dep.status == "retracted" -> "retracted"
              true -> dep.status
            end

          IO.puts("    #{dep_id}: #{reason}")
        end)

        IO.puts("")
      end)

      IO.puts("#{length(results)} stale belief(s)")
    end
  end

  defp cmd_recent(flags) do
    since = resolve_since(flags)
    {:ok, beliefs} = Store.read()
    r = Graph.recent(beliefs, since)

    total =
      length(r.new) + length(r.superseded) + length(r.evidence) +
        length(r.materialized) + length(r.retracted)

    IO.puts("")
    IO.puts("Graph changes since #{Date.to_iso8601(since)} (inclusive):")
    IO.puts("")

    if total == 0 do
      IO.puts("No changes in the window.")
      IO.puts("")
    else
      recent_section("NEW", r.new, fn a ->
        "  #{a.id} [#{a.type}] #{trunc(a.claim, 56)} (#{a.created})"
      end)

      recent_section("SUPERSEDED", r.superseded, fn {old, succ} ->
        "  #{old.id} -> #{succ.id} #{trunc(succ.claim, 44)} (#{succ.created})"
      end)

      recent_section("EVIDENCE APPENDED", r.evidence, fn {a, entries} ->
        dates = entries |> Enum.map(& &1["date"]) |> Enum.uniq() |> Enum.join(", ")
        "  #{a.id} +#{length(entries)} entr#{if length(entries) == 1, do: "y", else: "ies"} #{trunc(a.claim, 44)} (#{dates})"
      end)

      recent_section("MATERIALIZED", r.materialized, fn a ->
        items = a.materialized["todos"] || []
        "  #{a.id} #{length(items)} item(s) #{trunc(a.claim, 48)} (#{a.materialized["date"]})"
      end)

      recent_section("RETRACTED", r.retracted, fn a ->
        "  #{a.id} #{trunc(a.claim, 56)} (#{a.retracted_on})"
      end)

      IO.puts("#{total} event(s)")
      IO.puts("")
    end
  end

  defp recent_section(_label, [], _line_fn), do: :ok

  defp recent_section(label, events, line_fn) do
    IO.puts("#{label} (#{length(events)})")
    Enum.each(events, &IO.puts(line_fn.(&1)))
    IO.puts("")
  end

  defp resolve_since(flags) do
    since = Keyword.get(flags, :since)
    days = Keyword.get(flags, :days)

    cond do
      since != nil ->
        case Date.from_iso8601(since) do
          {:ok, date} ->
            date

          {:error, _} ->
            IO.puts(:stderr, "Invalid --since date: #{since} (expected YYYY-MM-DD)")
            System.halt(1)
        end

      days != nil ->
        case Integer.parse(days) do
          {n, ""} when n >= 0 ->
            Date.add(CB.today(), -n)

          _ ->
            IO.puts(:stderr, "Invalid --days value: #{days} (expected a non-negative integer)")
            System.halt(1)
        end

      true ->
        Date.add(CB.today(), -7)
    end
  end

  defp cmd_path(id1, id2) do
    {:ok, beliefs} = Store.read()
    id1 = resolve_or_halt(beliefs, id1)
    id2 = resolve_or_halt(beliefs, id2)
    idx = Graph.index(beliefs)

    case Graph.path(id1, id2, idx, beliefs) do
      {:ok, path} ->
        IO.puts("")
        IO.puts("Path from #{id1} to #{id2} (#{length(path)} nodes):")
        IO.puts("")

        path
        |> Enum.with_index()
        |> Enum.each(fn {id, i} ->
          a = Map.get(idx, id)
          connector = if i == 0, do: "  ", else: "  -> "
          IO.puts("#{connector}#{a.id} [#{a.type}] #{trunc(a.claim, 60)}")
        end)

        IO.puts("")

      :no_path ->
        IO.puts("No path between #{id1} and #{id2}.")
    end
  end

  defp cmd_history(id) do
    {:ok, beliefs} = Store.read()
    id = resolve_or_halt(beliefs, id)
    idx = Graph.index(beliefs)
    target = Map.get(idx, id)
    {predecessors, successors} = Graph.history(id, beliefs)
    chain = predecessors ++ [target] ++ successors

    if length(chain) == 1 do
      IO.puts("#{id} has no supersession history (standalone).")
    else
      IO.puts("")
      IO.puts("Supersession chain (#{length(chain)} beliefs):")
      IO.puts("")

      chain
      |> Enum.with_index()
      |> Enum.each(fn {a, i} ->
        marker = if a.id == id, do: " <-- current", else: ""

        status =
          case a.status do
            "active" -> ""
            s -> " [#{s}]"
          end

        arrow = if i > 0, do: "  -> ", else: "  "
        IO.puts("#{arrow}#{a.id}#{status} #{trunc(a.claim, 50)} (#{a.created || "?"})#{marker}")
      end)

      IO.puts("")
    end
  end

  defp cmd_subjects(args) do
    {:ok, beliefs} = Store.read()

    results =
      case args do
        [] ->
          IO.puts(:stderr, "Usage: mix bs subjects <ref|--type TYPE>")
          System.halt(1)

        ["--type", type | _] ->
          Graph.by_subject(beliefs, type: type)

        [ref | _] ->
          if String.contains?(ref, "/") do
            Graph.by_subject(beliefs, ref: ref)
          else
            Graph.by_subject(beliefs, type: ref)
          end
      end

    active = Enum.filter(results, &(&1.status == "active"))

    if active == [] do
      IO.puts("No active beliefs found for that subject.")
    else
      Formatter.table(active, length(beliefs)) |> Enum.each(&IO.puts/1)
    end
  end

  defp cmd_stats do
    {:ok, beliefs} = Store.read()
    s = Graph.stats(beliefs)

    IO.puts("")
    IO.puts("Belief DAG Statistics")
    IO.puts("=====================")
    IO.puts("")
    IO.puts("Total: #{s.total}")
    IO.puts("")

    IO.puts("By type:")
    Enum.each(s.by_type, fn {k, v} -> IO.puts("  #{k}: #{v}") end)
    IO.puts("")

    IO.puts("By status:")
    Enum.each(s.by_status, fn {k, v} -> IO.puts("  #{k}: #{v}") end)
    IO.puts("")

    IO.puts("Stale: #{s.stale_count}")
    IO.puts("Unlinked directives: #{s.unlinked_directives}")
    IO.puts("")

    if s.artifact_schemes != %{} do
      IO.puts("Artifact schemes:")

      s.artifact_schemes
      |> Enum.sort_by(fn {_, v} -> -v end)
      |> Enum.each(fn {k, v} -> IO.puts("  #{k}: #{v}") end)

      IO.puts("")
    end

    if s.dep_depths != [] do
      max_depth = List.last(s.dep_depths)
      mean_depth = Enum.sum(s.dep_depths) / max(length(s.dep_depths), 1)
      IO.puts("Dependency depth:")
      IO.puts("  max: #{max_depth}")
      IO.puts("  mean: #{:erlang.float_to_binary(mean_depth * 1.0, decimals: 1)}")
      IO.puts("")
    end

    if s.most_depended != [] do
      IO.puts("Most depended-on:")

      Enum.each(s.most_depended, fn {id, count} ->
        IO.puts("  #{id}: #{count} dependents")
      end)

      IO.puts("")
    end
  end

  defp cmd_help do
    IO.puts("""

    bs - belief shell (deterministic DAG queries)

    COMMANDS
      list [filters]       List beliefs matching filters
      show <id>            Full detail on a single belief
      tree <id>            Dependency tree visualization
      deps <id>            Direct dependencies (--deep for full tree)
      dependents <id>      Reverse dependency lookup (--deep for transitive)
      stale                Find beliefs with bad deps (--cascade for transitive)
      recent               Graph changes in a window: new nodes, supersessions,
                           evidence appends, materializations, retractions
      path <id1> <id2>     Find connection between two beliefs
      history <id>         Supersession chain
      subjects <ref|type>  Find beliefs by subject
      stats                Graph-level statistics

    FILTERS (for list)
      primitive|compound|inference|directive   Filter by structural type
      active|superseded|retracted|all  Filter by status (default: active)
      contracts                        Contract-grade directives only
      unlinked                         Directives with no materialized items
      tag:<tag> / kind:<kind> / domain:<domain> / subject_type:<type>

    FLAGS
      -v / --verbose       Show full detail in list view
      --deep               Recurse through full chain (deps, dependents)
      --cascade            Include transitively stale (stale)
      --since DATE         Window start for recent, inclusive (YYYY-MM-DD)
      --days N             Window as N days back from today (recent; default 7)

    IDS
      Bare (c029) or namespaced (cb:c029). A bare id resolves to its
      namespaced form when exactly one belief matches.

    COLLECTION
      --beliefs PATH       Query an alternate graph (CB_BELIEFS env var too),
                           e.g. ../belief-collections/library/beliefs.json
    """)
  end

  # --- collection override ---

  # `--beliefs PATH` points the shell at an alternate collection (e.g. a
  # belief-collection) by setting the path the store reads, for this task run
  # only. Returns args with the flag and its value removed.
  defp apply_beliefs_override(args) do
    case Enum.split_while(args, &(&1 != "--beliefs")) do
      {before, ["--beliefs", path | rest]} ->
        Application.put_env(:cb, :beliefs_path, path)
        before ++ rest

      {_before, ["--beliefs"]} ->
        IO.puts(:stderr, "--beliefs requires a path argument")
        System.halt(1)

      _ ->
        args
    end
  end

  # --- id resolution ---

  defp resolve_or_halt(beliefs, id) do
    case Graph.resolve_id(beliefs, id) do
      {:ok, canonical} ->
        canonical

      {:error, :not_found} ->
        IO.puts(:stderr, "No belief with id: #{id}")
        System.halt(1)

      {:error, {:ambiguous, ids}} ->
        IO.puts(:stderr, "Ambiguous id '#{id}' matches: #{Enum.join(ids, ", ")}")
        IO.puts(:stderr, "Qualify it with a namespace, e.g. #{hd(ids)}.")
        System.halt(1)
    end
  end

  # --- Flag extraction ---

  defp extract_flags(args), do: extract_flags(args, [], [])

  defp extract_flags([], flags, rest), do: {flags, rest}

  defp extract_flags([arg | t], flags, rest) when arg in ~w(-v --verbose),
    do: extract_flags(t, [{:verbose, true} | flags], rest)

  defp extract_flags(["--deep" | t], flags, rest),
    do: extract_flags(t, [{:deep, true} | flags], rest)

  defp extract_flags(["--cascade" | t], flags, rest),
    do: extract_flags(t, [{:cascade, true} | flags], rest)

  defp extract_flags([flag], _flags, _rest) when flag in ~w(--since --days) do
    IO.puts(:stderr, "#{flag} requires a value")
    System.halt(1)
  end

  defp extract_flags(["--since", value | t], flags, rest),
    do: extract_flags(t, [{:since, value} | flags], rest)

  defp extract_flags(["--days", value | t], flags, rest),
    do: extract_flags(t, [{:days, value} | flags], rest)

  defp extract_flags([arg | t], flags, rest),
    do: extract_flags(t, flags, rest ++ [arg])

  defp flag_args(flags) do
    Enum.flat_map(flags, fn
      {:verbose, true} -> ["-v"]
      _ -> []
    end)
  end
end
