defmodule CB.OutputTarget do
  @moduledoc """
  Shared logic for compiling output-target contracts into markdown files.

  An output-target contract is a `type: "implication"` node with
  `kind: "output-target"` that declares:
  - `output_path` (in rules): where to write the file
  - `header_comment` (in rules, optional): top-of-file comment
  - `paths` (in rules, optional): frontmatter for scoped rule files
  - `render_sections` (in rules): [{"title": "...", "beliefs": [ids]}]

  The compiler reads the contract, dereferences each belief ID in
  render_sections to its claim field, and emits the file. Every
  line in the output traces to exactly one belief claim.
  """

  alias CB.Belief
  alias CB.Belief.Store, as: BeliefStore

  @doc """
  Find all active output-target contracts matching an optional filter tag.

  Pass `tag: "output:claude-md"` for a CLAUDE.md manifest, or
  `tag: "output:rule"` for rule file manifests.
  """
  def find_targets(opts \\ []) do
    filter_tag = Keyword.get(opts, :tag)

    with {:ok, all} <- BeliefStore.read() do
      targets =
        all
        |> Enum.filter(&output_target?/1)
        |> filter_by_tag(filter_tag)

      {:ok, targets, all}
    end
  end

  @doc """
  Compile one output-target contract into its rendered markdown string.

  Takes the contract struct plus the full list of beliefs (used to
  dereference IDs in render_sections). Returns `{:ok, path, content}`
  or `{:error, reason}`.
  """
  def compile(target, all_beliefs) do
    by_id = Map.new(all_beliefs, &{&1.id, &1})
    rules = extract_rules_map(target)

    with {:ok, output_path} <- fetch_rule(rules, "output_path"),
         {:ok, sections} <- fetch_rule(rules, "render_sections") do
      header_comment = Map.get(rules, "header_comment", "")
      paths = Map.get(rules, "paths", nil)

      content =
        build_content(
          header_comment: header_comment,
          paths: paths,
          sections: sections,
          by_id: by_id,
          target_id: target.id
        )

      {:ok, output_path, content}
    end
  end

  # --- Private ---

  defp output_target?(%Belief{status: "active", kind: "output-target"}), do: true
  defp output_target?(_), do: false

  defp filter_by_tag(targets, nil), do: targets
  defp filter_by_tag(targets, tag), do: Enum.filter(targets, &(tag in (&1.tags || [])))

  # Rules on a contract is a list of single-key maps; flatten into one.
  defp extract_rules_map(%{rules: rules}) when is_list(rules) do
    Enum.reduce(rules, %{}, fn
      rule, acc when is_map(rule) -> Map.merge(acc, rule)
      _, acc -> acc
    end)
  end

  defp extract_rules_map(_), do: %{}

  defp fetch_rule(rules, key) do
    case Map.fetch(rules, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_rule, key}}
    end
  end

  defp build_content(opts) do
    frontmatter = render_frontmatter(opts[:paths])
    header = render_header(opts[:header_comment])
    body = render_sections(opts[:sections], opts[:by_id], opts[:target_id])

    [frontmatter, header, body]
    |> Enum.reject(&(&1 == "" or is_nil(&1)))
    |> Enum.join("\n")
    |> ensure_trailing_newline()
  end

  defp render_frontmatter(nil), do: ""
  defp render_frontmatter([]), do: ""

  defp render_frontmatter(paths) when is_list(paths) do
    path_lines = Enum.map_join(paths, "\n", &"  - \"#{&1}\"")
    "---\npaths:\n#{path_lines}\n---\n"
  end

  defp render_header(nil), do: ""
  defp render_header(""), do: ""
  defp render_header(comment) when is_binary(comment), do: "#{comment}\n"

  defp render_sections(sections, by_id, target_id) when is_list(sections) do
    sections
    |> Enum.map(&render_section(&1, by_id, target_id))
    |> Enum.join("\n")
  end

  defp render_section(%{"title" => title, "beliefs" => belief_ids}, by_id, _target_id) do
    lines =
      belief_ids
      |> Enum.map(fn id ->
        case Map.get(by_id, id) do
          nil -> "<!-- BELIEF NOT FOUND: #{id} -->"
          belief -> belief.claim || "<!-- NO CLAIM: #{id} -->"
        end
      end)
      |> Enum.join("\n\n")

    "## #{title}\n\n#{lines}\n"
  end

  defp render_section(_bad_section, _by_id, target_id) do
    "<!-- BAD SECTION in #{target_id} -->\n"
  end

  defp ensure_trailing_newline(content) do
    if String.ends_with?(content, "\n"), do: content, else: content <> "\n"
  end

  @doc """
  Validate a target's deps match the union of render_sections' beliefs.
  Returns `:ok` or `{:error, {:deps_mismatch, missing, extra}}`.
  """
  def validate_deps_match_sections(target) do
    rules = extract_rules_map(target)
    sections = Map.get(rules, "render_sections", [])

    section_ids =
      sections
      |> Enum.flat_map(fn
        %{"beliefs" => ids} -> ids
        _ -> []
      end)
      |> MapSet.new()

    dep_ids = MapSet.new(target.deps || [])

    missing = MapSet.difference(section_ids, dep_ids) |> MapSet.to_list()
    extra = MapSet.difference(dep_ids, section_ids) |> MapSet.to_list()

    if missing == [] and extra == [] do
      :ok
    else
      {:error, {:deps_mismatch, missing, extra}}
    end
  end
end
