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

  # --- Codepath output-targets ---

  @codepath_tag "output:codepath"

  @doc """
  True for an active codepath output-target: `kind: "output-target"`
  tagged `#{@codepath_tag}`. Codepath targets carry `entry` and
  `render_steps` rules instead of `render_sections`; rendering is the
  codepath renderer's job (plan-2), this module parses and validates.
  """
  def codepath_target?(%Belief{status: "active", kind: "output-target"} = b),
    do: @codepath_tag in (b.tags || [])

  def codepath_target?(_), do: false

  @doc """
  Validate a codepath output-target against the full belief list.

  Checks the shape the codepath contract declares:
  - rules carry `entry` and a non-empty `render_steps` list
  - step rows are maps with string `id` and `belief`; step ids unique
  - `entry` and every `goto` / choice `goto` name an existing step id
  - every referenced belief exists and carries a valid `code:` artifact
  - `deps` equals the union of the steps' belief ids

  Returns `:ok` or `{:error, [message]}` with every violation listed.
  """
  def validate_codepath(target, all_beliefs) do
    rules = extract_rules_map(target)
    entry = Map.get(rules, "entry")
    steps = Map.get(rules, "render_steps")

    case shape_errors(entry, steps) do
      [] ->
        case step_errors(entry, steps, target, all_beliefs) do
          [] -> :ok
          errors -> {:error, errors}
        end

      errors ->
        {:error, errors}
    end
  end

  defp shape_errors(entry, steps) do
    bad_rows =
      case steps do
        rows when is_list(rows) ->
          Enum.reject(rows, fn row ->
            is_map(row) and is_binary(row["id"]) and is_binary(row["belief"])
          end)

        _ ->
          []
      end

    [
      unless(is_binary(entry) and entry != "", do: "missing or empty 'entry' rule"),
      unless(is_list(steps) and steps != [], do: "missing or empty 'render_steps' rule"),
      if(bad_rows != [],
        do: "steps without string 'id' and 'belief': #{inspect(bad_rows)}"
      )
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp step_errors(entry, steps, target, all_beliefs) do
    by_id = Map.new(all_beliefs, &{&1.id, &1})
    step_ids = Enum.map(steps, & &1["id"])
    step_id_set = MapSet.new(step_ids)
    dupes = Enum.uniq(step_ids -- Enum.uniq(step_ids))

    bad_gotos =
      for step <- steps,
          {label, goto} <- nav_targets(step),
          not MapSet.member?(step_id_set, goto) do
        "step #{step["id"]}: #{label} -> unknown step #{inspect(goto)}"
      end

    bad_beliefs =
      steps
      |> Enum.map(& &1["belief"])
      |> Enum.uniq()
      |> Enum.flat_map(fn id ->
        case Map.get(by_id, id) do
          nil ->
            ["referenced belief #{id} not found"]

          %Belief{artifact: artifact} ->
            if CB.CodeLocator.valid?(artifact),
              do: [],
              else: ["referenced belief #{id} has no valid code: artifact (#{inspect(artifact)})"]
        end
      end)

    deps_errors =
      case deps_mismatch(target, Enum.map(steps, & &1["belief"])) do
        :ok -> []
        {:error, {:deps_mismatch, missing, extra}} ->
          ["deps do not equal referenced belief ids - missing: #{inspect(missing)}, extra: #{inspect(extra)}"]
      end

    entry_errors =
      if MapSet.member?(step_id_set, entry),
        do: [],
        else: ["entry #{inspect(entry)} is not a step id"]

    dupe_errors = if dupes == [], do: [], else: ["duplicate step ids: #{inspect(dupes)}"]

    entry_errors ++ dupe_errors ++ bad_gotos ++ bad_beliefs ++ deps_errors
  end

  # All navigation targets of a step row, labeled for error messages.
  defp nav_targets(step) do
    goto = if is_binary(step["goto"]), do: [{"goto", step["goto"]}], else: []

    choices =
      for choice <- List.wrap(step["choices"]), is_map(choice), is_binary(choice["goto"]) do
        {"choice #{inspect(choice["label"])}", choice["goto"]}
      end

    goto ++ choices
  end

  defp deps_mismatch(target, referenced_ids) do
    referenced = MapSet.new(referenced_ids)
    dep_ids = MapSet.new(target.deps || [])

    missing = MapSet.difference(referenced, dep_ids) |> MapSet.to_list()
    extra = MapSet.difference(dep_ids, referenced) |> MapSet.to_list()

    if missing == [] and extra == [] do
      :ok
    else
      {:error, {:deps_mismatch, missing, extra}}
    end
  end

  @doc """
  Validate a target's deps match the union of render_sections' beliefs.
  Returns `:ok` or `{:error, {:deps_mismatch, missing, extra}}`.
  """
  def validate_deps_match_sections(target) do
    rules = extract_rules_map(target)
    sections = Map.get(rules, "render_sections", [])

    section_ids =
      Enum.flat_map(sections, fn
        %{"beliefs" => ids} -> ids
        _ -> []
      end)

    deps_mismatch(target, section_ids)
  end
end
