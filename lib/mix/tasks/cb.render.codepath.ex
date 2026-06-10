defmodule Mix.Tasks.Cb.Render.Codepath do
  @moduledoc """
  Render a codepath linearly - the deterministic, non-interactive face of
  the codepath resolver.

  Loads the collection, selects a codepath output-target, resolves every
  step's `code:` anchor to a current `path:line`, and emits the stops in
  deterministic traversal order (entry first, depth-first; branches are
  listed inline rather than waited on). The interactive presentation is
  the `present-codepath` skill; both share `CB.Codepath`, so this task is
  the CI-testable, harness-independent proof of the resolver.

  ## Usage

      mix cb.render.codepath                    - list available codepaths
      mix cb.render.codepath <id>               - render one (bare or namespaced id)
      mix cb.render.codepath <id> --json        - machine-readable stops (for the skill)
      mix cb.render.codepath <id> --beliefs P   - target an alternate collection

  Paths resolve against the current working directory (the project root
  under mix). A missing or loose anchor is a `!` maintenance warning,
  never a crash.

  ## Exit codes

  0 = rendered (warnings included), 1 = unknown id / invalid target / read error
  """
  @shortdoc "Render a codepath output-target as linear, anchored stops"

  use Mix.Task

  alias CB.Belief.Store
  alias CB.Codepath

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args, strict: [beliefs: :string, json: :boolean])

    if path = opts[:beliefs], do: Application.put_env(:cb, :beliefs_path, path)

    case Store.read() do
      {:ok, beliefs} -> run_with(beliefs, positional, opts[:json] || false)
      {:error, reason} -> halt("cannot read belief collection: #{inspect(reason)}")
    end
  end

  defp run_with(beliefs, [], _json) do
    case Codepath.targets(beliefs) do
      [] ->
        IO.puts("No codepath output-targets (output:codepath) in this collection.")

      targets ->
        IO.puts("Available codepaths:")
        Enum.each(targets, &IO.puts("  #{&1.id} - #{truncate(&1.claim)}"))
    end
  end

  defp run_with(beliefs, [id | _], json) do
    with {:ok, target} <- Codepath.find_target(beliefs, id),
         {:ok, resolved} <- Codepath.resolve(target, beliefs) do
      if json do
        IO.puts(Jason.encode!(resolved, pretty: true))
      else
        IO.puts(render_text(resolved))
      end
    else
      {:error, :not_found} ->
        halt("no codepath output-target with id #{inspect(id)} (run without args to list)")

      {:error, {:ambiguous, ids}} ->
        halt("id #{inspect(id)} is ambiguous: #{Enum.join(ids, ", ")}")

      {:error, messages} when is_list(messages) ->
        halt("invalid codepath target:\n  " <> Enum.join(messages, "\n  "))
    end
  end

  @doc false
  # Public for testing - pure text rendering of a resolved codepath.
  def render_text(%{id: id, claim: claim, entry: entry, stops: stops}) do
    header = ["#{id} (entry: #{entry})", claim && truncate(claim, 120), ""]

    body = Enum.flat_map(stops, &render_stop/1)

    (header ++ body)
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp render_stop(stop) do
    ref = if stop.line, do: "#{stop.path}:#{stop.line}", else: stop.path
    head = "[#{stop.step}] `#{ref}` - #{stop.claim}"
    warnings = Enum.map(stop.warnings, &"  ! #{&1}")

    choices =
      Enum.map(stop.choices, fn c -> "  -> #{c.label || "(unlabeled)"}: #{c.goto}" end)

    [head | warnings ++ choices] ++ [""]
  end

  defp truncate(text, max \\ 80)
  defp truncate(nil, _max), do: "(no claim)"

  defp truncate(text, max) when is_binary(text) do
    if String.length(text) > max, do: String.slice(text, 0, max) <> "...", else: text
  end

  defp halt(msg) do
    IO.puts(:stderr, "cb.render.codepath: #{msg}")
    System.halt(1)
  end
end
