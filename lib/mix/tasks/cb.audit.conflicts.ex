defmodule Mix.Tasks.Cb.Audit.Conflicts do
  @moduledoc """
  Detect potential conflicts in the DAG.

  Makes contradictions expensive by surfacing pairs of implications that
  share scope, plus stale dependencies on superseded/retracted nodes.

  Overlap is structural (same domain, shared tags/subjects). Whether
  two overlapping nodes actually contradict, are redundant, or are
  compatible is a judgment call - this task surfaces candidate pairs
  for review.

  ## Usage

      mix cb.audit.conflicts                   # Full scan
      mix cb.audit.conflicts --tag git         # Scope to a tag
      mix cb.audit.conflicts --domain agent    # Scope to a domain
      mix cb.audit.conflicts --related c030    # Show pairs involving c030
      mix cb.audit.conflicts --contracts       # Contract-grade implications only
      mix cb.audit.conflicts --summary         # Counts only, no pair listing
      mix cb.audit.conflicts --limit 3         # Limit pairs shown per category

  ## Exit codes

  0 = no conflicts found, 1 = one or more conflicts
  """
  @shortdoc "Surface potential conflicts between active DAG implications"

  use Mix.Task

  alias CB.Audit.Conflicts

  @default_limit 5

  @impl Mix.Task
  def run(args) do
    {opts, _positional, _} =
      OptionParser.parse(args,
        strict: [
          tag: :string,
          domain: :string,
          related: :string,
          contracts: :boolean,
          summary: :boolean,
          limit: :integer,
          quiet: :boolean
        ],
        aliases: [q: :quiet]
      )

    scan_opts =
      []
      |> put_if(:tag, opts[:tag])
      |> put_if(:domain, opts[:domain])
      |> put_if(:contracts_only, opts[:contracts] || false)

    result =
      case opts[:related] do
        nil ->
          Conflicts.scan(scan_opts)

        node_id ->
          case Conflicts.related(node_id, scan_opts) do
            {:ok, pairs} ->
              %{
                stale_overrides: [],
                scope_overlaps: pairs,
                total_implications: length(pairs),
                total_nodes: nil,
                related_to: node_id
              }

            {:error, {:not_found, id}} ->
              IO.puts(:stderr, "Node not found: #{id}")
              System.halt(1)
          end
      end

    print_result(result, opts)

    total = length(result.stale_overrides) + length(result.scope_overlaps)
    if total > 0 and not (opts[:quiet] || false), do: System.halt(1)
  end

  # --- Output ---

  defp print_result(result, opts) do
    scope_desc = scope_description(opts)
    limit = opts[:limit] || @default_limit
    summary = opts[:summary] || false

    IO.puts("")
    IO.puts("DAG conflict audit")
    IO.puts(String.duplicate("=", 40))

    if scope_desc != "" do
      IO.puts("Scope: #{scope_desc}")
    end

    stale = result.stale_overrides
    overlaps = result.scope_overlaps

    IO.puts("")
    IO.puts("Stale overrides: #{length(stale)}")

    unless summary do
      Enum.each(stale, fn {node, bad_deps} ->
        IO.puts("  #{node.id} (#{truncate(node.claim, 60)})")
        IO.puts("    depends on: #{Enum.join(bad_deps, ", ")}")
      end)
    end

    IO.puts("")
    IO.puts("Scope overlaps: #{length(overlaps)} pairs")

    unless summary do
      overlaps
      |> Enum.group_by(&overlap_category/1)
      |> Enum.sort_by(fn {cat, _} -> cat end)
      |> Enum.each(fn {category, pairs} ->
        IO.puts("")
        IO.puts("  [#{category}] #{length(pairs)} pairs")

        pairs
        |> Enum.take(limit)
        |> Enum.each(&print_pair/1)

        if length(pairs) > limit do
          IO.puts("    ... and #{length(pairs) - limit} more")
        end
      end)
    end

    IO.puts("")
    summary_line =
      if result[:related_to] do
        "Related to #{result.related_to}: #{length(overlaps)} overlapping implications"
      else
        "#{length(stale) + length(overlaps)} potential conflicts across #{result.total_implications} active implications"
      end

    IO.puts("Summary: #{summary_line}")
  end

  defp scope_description(opts) do
    parts = []
    parts = if opts[:tag], do: ["tag=#{opts[:tag]}" | parts], else: parts
    parts = if opts[:domain], do: ["domain=#{opts[:domain]}" | parts], else: parts
    parts = if opts[:related], do: ["related-to=#{opts[:related]}" | parts], else: parts
    parts = if opts[:contracts], do: ["contracts-only" | parts], else: parts
    Enum.join(Enum.reverse(parts), ", ")
  end

  defp overlap_category({_a, _b, {:shared_tags, tags}}),
    do: "shared tags: #{Enum.join(tags, ", ")}"

  defp overlap_category({_a, _b, {:shared_subject_refs, refs}}),
    do: "shared subject refs: #{Enum.join(refs, ", ")}"

  defp overlap_category({_a, _b, {:shared_subject_types, types}}),
    do: "shared subject types: #{Enum.join(types, ", ")}"

  defp overlap_category({_a, _b, {:domain_global, domain}}),
    do: "domain-global: #{domain}"

  defp print_pair({a, b, _reason}) do
    IO.puts("    #{a.id} <-> #{b.id}")
    IO.puts("      #{a.id}: #{truncate(a.claim, 80)}")
    IO.puts("      #{b.id}: #{truncate(b.claim, 80)}")
  end

  defp truncate(nil, _), do: "(no claim)"

  defp truncate(str, max) when is_binary(str) do
    if String.length(str) > max do
      String.slice(str, 0, max) <> "..."
    else
      str
    end
  end

  defp put_if(keyword, _key, nil), do: keyword
  defp put_if(keyword, _key, false), do: keyword
  defp put_if(keyword, key, value), do: Keyword.put(keyword, key, value)
end
