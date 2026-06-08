defmodule CB.Belief.Formatter do
  import CB.Display

  @moduledoc """
  Terminal output for beliefs - table, detail, tree (DAG visualization).

  Renders the CURRENT belief schema (structural `type`, `artifact`,
  `contract`, structural `support` counts). The tree view renders a
  belief's dependency graph using box-drawing characters, recursively
  walking deps to show the full reasoning chain from implications down
  to primitives.
  """

  alias CB.Belief

  # ANSI color helpers
  defp color(:dim), do: "\e[2m"
  defp color(:reset), do: "\e[0m"
  defp color(:cyan), do: "\e[36m"
  defp color(:yellow), do: "\e[33m"
  defp color(:magenta), do: "\e[35m"
  defp color(:red), do: "\e[31m"

  defp type_color("primitive"), do: color(:cyan)
  defp type_color("compound"), do: color(:yellow)
  defp type_color("implication"), do: color(:magenta)
  defp type_color(_), do: color(:reset)

  defp status_indicator(%{status: "active"}), do: ""
  defp status_indicator(%{status: "superseded"}), do: " #{color(:dim)}[superseded]#{color(:reset)}"
  defp status_indicator(%{status: "retracted"}), do: " #{color(:red)}[retracted]#{color(:reset)}"
  defp status_indicator(%{status: "retired"}), do: " #{color(:dim)}[retired]#{color(:reset)}"
  defp status_indicator(_), do: ""

  # --- Table view ---

  def table(beliefs, total) do
    if beliefs == [] do
      ["No matching beliefs.", "", "0 beliefs (of #{total} total)"]
    else
      term_width = terminal_width()
      id_width = beliefs |> Enum.map(&String.length(&1.id)) |> Enum.max() |> max(4)
      claim_width = max(term_width - id_width - 41, 30)

      header = table_row("ID", "TYPE", "STATUS", "CLAIM", id_width, claim_width)
      sep = table_row(String.duplicate("-", id_width), "-----------", "----------", "-----", id_width, claim_width)

      rows =
        Enum.map(beliefs, fn b ->
          type_label = if Belief.contract?(b), do: "contract", else: b.type
          table_row(b.id, type_label, b.status, trunc(b.claim, claim_width), id_width, claim_width)
        end)

      count = length(beliefs)
      [header, sep] ++ rows ++ ["", "#{count} beliefs (of #{total} total)"]
    end
  end

  defp table_row(id, type, status, claim, id_width, claim_width) do
    :io_lib.format("~-*s ~-12s ~-11s ~-*s", [id_width, id, type, status, claim_width, claim])
    |> IO.iodata_to_binary()
  end

  # --- Detail view ---

  def detail(belief) do
    b = belief

    lines = [
      "",
      "ID:          #{b.id}",
      "Type:        #{b.type}#{if Belief.contract?(b), do: " (contract)", else: ""}",
      "Kind:        #{b.kind || "-"}",
      "Domain:      #{b.domain || "-"}",
      "Name:        #{b.name || "-"}",
      "Claim:       #{b.claim || "-"}",
      "Status:      #{b.status}"
    ]

    lines = lines ++ tags_lines(b.tags)
    lines = lines ++ subjects_lines(b.subjects)

    lines =
      if b.type == "primitive" do
        lines ++ ["Artifact:    #{b.artifact || "-"}"]
      else
        dep_str = Enum.join(b.deps || [], ", ")
        lines ++ ["Deps:        #{if dep_str == "", do: "-", else: dep_str}"]
      end

    lines = lines ++ contract_lines(b)
    lines = lines ++ evidence_lines(b.evidence)

    lines =
      if b.type == "implication" do
        mat =
          case b.materialized do
            nil -> "-"
            %{"date" => d, "todos" => ts} -> "#{d} (#{length(ts)} item(s))"
            other -> inspect(other)
          end

        lines ++ ["Materialized:#{String.pad_leading("", 1)}#{mat}"]
      else
        lines
      end

    s = Belief.support(b)

    lines =
      lines ++
        [
          "Support:     artifacts=#{s.artifact_count} evidence=#{s.evidence_count} deps=#{s.dep_count}",
          "Created:     #{b.created || "-"}"
        ]

    lines =
      if b.superseded_by do
        lines ++ ["Superseded:  #{b.superseded_by}"]
      else
        lines
      end

    lines ++ [""]
  end

  defp tags_lines([]), do: ["Tags:        -"]
  defp tags_lines(tags) when is_list(tags), do: ["Tags:        #{Enum.join(tags, ", ")}"]
  defp tags_lines(_), do: ["Tags:        -"]

  defp contract_lines(%Belief{rules: rules, invariants: invariants}) do
    rule_lines =
      if is_list(rules) and rules != [] do
        ["Rules:       #{length(rules)} rule(s)"]
      else
        []
      end

    invariant_lines =
      if is_list(invariants) and invariants != [] do
        ["Invariants:"] ++ Enum.map(invariants, &"             - #{&1}")
      else
        []
      end

    rule_lines ++ invariant_lines
  end

  defp evidence_lines(evidence) when is_list(evidence) and length(evidence) > 0 do
    evidence
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {e, idx} ->
      header = if length(evidence) == 1, do: "Evidence:", else: "Evidence #{idx}:"
      lines = ["#{String.pad_trailing(header, 13)}#{e["detail"] || "-"}"]
      lines = if e["artifact"], do: lines ++ ["             artifact: #{e["artifact"]}"], else: lines
      if e["date"], do: lines ++ ["             date: #{e["date"]}"], else: lines
    end)
  end

  defp evidence_lines(_), do: []

  defp subjects_lines(subjects) when is_list(subjects) and length(subjects) > 0 do
    formatted =
      subjects
      |> Enum.map(fn s -> "#{s["ref"]} (#{s["type"]})" end)
      |> Enum.join(", ")

    ["Subjects:    #{formatted}"]
  end

  defp subjects_lines(_), do: ["Subjects:    -"]

  # --- Tree view (DAG visualizer) ---

  def tree(root, all_beliefs) do
    index = Map.new(all_beliefs, &{&1.id, &1})
    lines = tree_lines(root, index, :root, true, MapSet.new())
    [""] ++ lines ++ [""]
  end

  defp tree_lines(belief, index, prefix, is_last, visited) do
    b = belief
    is_root = prefix == :root

    connector =
      cond do
        is_root -> ""
        is_last -> "└── "
        true -> "├── "
      end

    display_prefix = if is_root, do: "", else: prefix

    tc = type_color(b.type)
    rst = color(:reset)
    si = status_indicator(b)
    type_label = if Belief.contract?(b), do: "contract", else: b.type

    line =
      "#{display_prefix}#{connector}#{tc}#{b.id}#{rst} #{color(:dim)}[#{type_label}]#{rst} #{b.claim}#{si}"

    meta_prefix = if is_root, do: "", else: child_prefix(prefix, is_last)

    extra =
      cond do
        b.type == "primitive" and b.artifact ->
          art_line = "#{meta_prefix}  #{color(:dim)}artifact: #{b.artifact}#{rst}"

          evidence_lines =
            (b.evidence || [])
            |> Enum.flat_map(fn e ->
              detail = e["detail"]

              if detail do
                wrapped = wrap_text(detail, max(terminal_width() - String.length(meta_prefix) - 4, 40))
                Enum.map(wrapped, fn l -> "#{meta_prefix}  #{color(:dim)}> #{l}#{rst}" end)
              else
                []
              end
            end)

          [art_line] ++ evidence_lines

        b.type == "implication" and b.materialized ->
          mat = b.materialized
          count = length(mat["todos"] || [])
          ["#{meta_prefix}  #{color(:dim)}materialized: #{mat["date"]} (#{count} item(s))#{rst}"]

        true ->
          []
      end

    subj =
      if is_list(b.subjects) and length(b.subjects) > 0 do
        types = b.subjects |> Enum.map(fn s -> s["type"] end) |> Enum.uniq() |> Enum.join(", ")
        ["#{meta_prefix}  #{color(:dim)}subjects: #{types}#{rst}"]
      else
        []
      end

    deps = b.deps || []

    if b.id in visited do
      ["#{line} #{color(:dim)}(circular ref)#{rst}"]
    else
      new_visited = MapSet.put(visited, b.id)
      child_pref = if is_root, do: "", else: child_prefix(prefix, is_last)

      dep_lines =
        deps
        |> Enum.with_index()
        |> Enum.flat_map(fn {dep_id, idx} ->
          case Map.get(index, dep_id) do
            nil ->
              dep_connector = if idx == length(deps) - 1, do: "└── ", else: "├── "
              ["#{child_pref}#{dep_connector}#{color(:red)}#{dep_id} (missing)#{rst}"]

            dep ->
              tree_lines(dep, index, child_pref, idx == length(deps) - 1, new_visited)
          end
        end)

      [line] ++ subj ++ extra ++ dep_lines
    end
  end

  defp child_prefix(prefix, true), do: prefix <> "    "
  defp child_prefix(prefix, false), do: prefix <> "│   "

  # --- Helpers ---

  defp wrap_text(text, width) do
    words = String.split(text)

    {lines, current} =
      Enum.reduce(words, {[], ""}, fn word, {lines, current} ->
        candidate = if current == "", do: word, else: current <> " " <> word

        if String.length(candidate) > width and current != "" do
          {[current | lines], word}
        else
          {lines, candidate}
        end
      end)

    Enum.reverse(if current == "", do: lines, else: [current | lines])
  end
end
