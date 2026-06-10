defmodule CB.Codepath do
  @moduledoc """
  Resolve a codepath output-target into ordered, anchored stops.

  A codepath output-target (see the codepath contract, `cb:c044`) carries
  `entry` plus `render_steps` rows; each row's belief anchors to source
  via a `code:` locator. This module owns load-resolve-emit: it validates
  the target, walks the step graph deterministically, and resolves every
  anchor to a current `path:line`. The `mix cb.render.codepath` task and
  the `present-codepath` skill are both thin presenters over it - one
  tested resolver, two faces.

  ## Resolution rules (per the cb-codepath plan-1 design)

  - Anchors are literal substrings, matched per line (`grep -nF`
    semantics); the resolved line number is never stored.
  - A missing file or anchor is a **maintenance warning**, never a crash;
    the stop still emits with `line: nil`.
  - Multiple matches with no `@N` selector resolve to the **first** match
    plus a tighten-this-anchor warning naming the match count. An
    explicit `@N` is intentional and warns only when out of range.

  ## Traversal

  Steps emit depth-first from `entry`, following `goto` then `choices`
  in declared order, visiting each step once (re-convergence is allowed,
  cycles terminate). The order is deterministic for a given target.
  """

  alias CB.{Belief, CodeLocator, OutputTarget}

  @type stop :: %{
          step: String.t(),
          belief: String.t(),
          claim: String.t() | nil,
          path: String.t(),
          line: pos_integer() | nil,
          warnings: [String.t()],
          goto: String.t() | nil,
          choices: [%{label: String.t() | nil, goto: String.t()}]
        }

  @doc "All active codepath output-targets in a belief list."
  @spec targets([Belief.t()]) :: [Belief.t()]
  def targets(beliefs), do: Enum.filter(beliefs, &OutputTarget.codepath_target?/1)

  @doc """
  Find a codepath target by exact id, belief name, or bare local id
  (`c001` matches `codepath:c001` when the bare form is unambiguous).
  """
  @spec find_target([Belief.t()], String.t()) ::
          {:ok, Belief.t()} | {:error, :not_found | {:ambiguous, [String.t()]}}
  def find_target(beliefs, id) do
    candidates = targets(beliefs)

    case Enum.find(candidates, &(&1.id == id)) do
      %Belief{} = exact ->
        {:ok, exact}

      nil ->
        case Enum.filter(candidates, &(&1.name == id or local_id(&1.id) == id)) do
          [one] -> {:ok, one}
          [] -> {:error, :not_found}
          many -> {:error, {:ambiguous, Enum.map(many, & &1.id)}}
        end
    end
  end

  @doc """
  Validate and resolve a codepath target into ordered stops.

  `opts`:
  - `:root` - directory anchored paths resolve against (default: cwd,
    which for a mix task is the project root).

  Returns `{:ok, %{id, claim, entry, stops}}` or `{:error, [message]}`
  (the validation messages from `CB.OutputTarget.validate_codepath/2`).
  """
  @spec resolve(Belief.t(), [Belief.t()], keyword()) ::
          {:ok, %{id: String.t(), claim: String.t() | nil, entry: String.t(), stops: [stop()]}}
          | {:error, [String.t()]}
  def resolve(target, all_beliefs, opts \\ []) do
    with :ok <- OutputTarget.validate_codepath(target, all_beliefs) do
      root = Keyword.get(opts, :root, File.cwd!())
      rules = OutputTarget.rules_map(target)
      entry = rules["entry"]
      steps = rules["render_steps"]
      steps_by_id = Map.new(steps, &{&1["id"], &1})
      by_belief_id = Map.new(all_beliefs, &{&1.id, &1})

      stops =
        entry
        |> traversal_order(steps_by_id)
        |> Enum.map(&resolve_stop(steps_by_id[&1], by_belief_id, root))

      {:ok, %{id: target.id, claim: target.claim, entry: entry, stops: stops}}
    end
  end

  # --- traversal ---

  # Depth-first from entry: goto first, then choices in declared order.
  # Visited-set handles re-convergence and terminates cycles.
  defp traversal_order(entry, steps_by_id), do: walk([entry], steps_by_id, MapSet.new(), [])

  defp walk([], _steps_by_id, _seen, acc), do: Enum.reverse(acc)

  defp walk([id | rest], steps_by_id, seen, acc) do
    if MapSet.member?(seen, id) do
      walk(rest, steps_by_id, seen, acc)
    else
      step = Map.fetch!(steps_by_id, id)
      next = List.wrap(step["goto"]) ++ Enum.map(choices(step), & &1.goto)
      walk(next ++ rest, steps_by_id, MapSet.put(seen, id), [id | acc])
    end
  end

  defp choices(step) do
    for choice <- List.wrap(step["choices"]), is_map(choice) do
      %{label: choice["label"], goto: choice["goto"]}
    end
  end

  # --- per-stop resolution ---

  defp resolve_stop(step, by_belief_id, root) do
    belief = Map.fetch!(by_belief_id, step["belief"])
    {:ok, locator} = CodeLocator.parse(belief.artifact)
    {line, warnings} = resolve_anchor(root, locator)

    %{
      step: step["id"],
      belief: belief.id,
      claim: belief.claim,
      path: locator.path,
      line: line,
      warnings: Enum.map(warnings, &"step #{step["id"]}: #{&1}"),
      goto: step["goto"],
      choices: choices(step)
    }
  end

  defp resolve_anchor(root, %{path: path, anchor: anchor, nth: nth}) do
    case File.read(Path.join(root, path)) do
      {:error, reason} ->
        {nil, ["cannot read #{path} (#{inspect(reason)})"]}

      {:ok, content} ->
        matches =
          content
          |> String.split("\n")
          |> Enum.with_index(1)
          |> Enum.filter(fn {text, _n} -> String.contains?(text, anchor) end)
          |> Enum.map(fn {_text, n} -> n end)

        pick_match(matches, anchor, nth, path)
    end
  end

  defp pick_match([], anchor, _nth, path),
    do: {nil, [~s(anchor "#{anchor}" not found in #{path})]}

  defp pick_match([line], _anchor, nil, _path), do: {line, []}

  defp pick_match([first | _] = matches, anchor, nil, path) do
    warning =
      ~s(anchor "#{anchor}" matches #{length(matches)} lines in #{path}) <>
        " - tighten this anchor (rendering the first match)"

    {first, [warning]}
  end

  defp pick_match(matches, anchor, nth, path) do
    case Enum.at(matches, nth - 1) do
      nil ->
        warning =
          ~s{anchor "#{anchor}"@#{nth} requested but only #{length(matches)} match(es) in #{path}}

        {nil, [warning]}

      line ->
        {line, []}
    end
  end

  defp local_id(id) when is_binary(id), do: id |> String.split(":") |> List.last()
end
