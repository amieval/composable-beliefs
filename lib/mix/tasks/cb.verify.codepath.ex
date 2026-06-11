defmodule Mix.Tasks.Cb.Verify.Codepath do
  @moduledoc """
  Run a codepath's assertions as a batch suite - the dynamic verifier.

  This is a **sibling** of `mix cb.verify.schema`, not a generalization
  of it: `verify.schema` stays static, deterministic, and runtime-free,
  while this task *invokes* the routed predicates of every contract-grade
  stop (plan-3 Step A: direct in-process invocation - no booted app, no
  MCP). Non-contract stops narrate only and are reported as such: that is
  the gradient.

  ## Usage

      mix cb.verify.codepath [<id>] [--beliefs PATH] [--record] [--json]

  Without `<id>`, every codepath output-target in the collection runs.
  `--record` materializes each contract stop's results onto its belief's
  `materialized` field via `CB.Materializer.Sink.Test` (dated; a re-run
  replaces the prior record - materialized is the mutable action-history
  axis, orthogonal to status). `--json` emits the result rows.

  ## Exit codes

  0 = all routed predicates pass, 1 = any failure / unknown id / invalid target
  """
  @shortdoc "Run a codepath's routed predicates as a batch suite (dynamic verifier)"

  use Mix.Task

  alias CB.Belief
  alias CB.Belief.Store
  alias CB.Codepath
  alias CB.Codepath.Assertions
  alias CB.Materializer.Sink

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args, strict: [beliefs: :string, record: :boolean, json: :boolean])

    if path = opts[:beliefs], do: Application.put_env(:cb, :beliefs_path, path)

    with {:ok, beliefs} <- Store.read(),
         {:ok, targets} <- select_targets(beliefs, positional) do
      results = Enum.flat_map(targets, &run_target(&1, beliefs))

      if opts[:record], do: record(results, beliefs)

      if opts[:json] do
        IO.puts(Jason.encode!(results, pretty: true))
      else
        report(targets, results, beliefs)
      end

      unless Assertions.passed?(results), do: System.halt(1)
    else
      {:error, message} -> halt(message)
    end
  end

  defp select_targets(beliefs, []) do
    case Codepath.targets(beliefs) do
      [] -> {:error, "no codepath output-targets (output:codepath) in this collection"}
      targets -> {:ok, targets}
    end
  end

  defp select_targets(beliefs, [id | _]) do
    case Codepath.find_target(beliefs, id) do
      {:ok, target} ->
        {:ok, [target]}

      {:error, :not_found} ->
        {:error, "no codepath output-target with id #{inspect(id)}"}

      {:error, {:ambiguous, ids}} ->
        {:error, "id #{inspect(id)} is ambiguous: #{Enum.join(ids, ", ")}"}
    end
  end

  defp run_target(target, beliefs) do
    case CB.OutputTarget.validate_codepath(target, beliefs) do
      :ok ->
        Assertions.run(target, beliefs)

      {:error, messages} ->
        halt("invalid codepath target #{target.id}:\n  " <> Enum.join(messages, "\n  "))
    end
  end

  # --- recording (test run as materialization) ---

  # Group results by stop belief, persist each group through Sink.Test's
  # ref shape, and replace that belief's materialized record. One atomic
  # write for the whole run.
  defp record([], _beliefs), do: :ok

  defp record(results, beliefs) do
    today = Date.to_iso8601(CB.today())

    refs_by_belief =
      results
      |> Enum.group_by(& &1.belief)
      |> Map.new(fn {belief_id, rows} ->
        items =
          Enum.map(rows, &%{"action" => "invoke #{&1.predicate}", "predicate" => &1.predicate})

        belief = Enum.find(beliefs, &(&1.id == belief_id))
        {:ok, refs} = Sink.Test.persist(belief, items, [])
        {belief_id, %{"date" => today, "todos" => refs}}
      end)

    updated =
      Enum.map(beliefs, fn b ->
        case Map.get(refs_by_belief, b.id) do
          nil -> b
          materialized -> put_materialized(b, materialized)
        end
      end)

    case Store.write(updated) do
      {:ok, path} ->
        IO.puts("Recorded #{map_size(refs_by_belief)} materialized test record(s) -> #{path}")

      {:error, reason} ->
        halt("failed to record results: #{inspect(reason)}")
    end
  end

  defp put_materialized(%Belief{_keys: keys} = b, materialized) do
    %{b | materialized: materialized, _keys: MapSet.put(keys || MapSet.new(), "materialized")}
  end

  # --- reporting ---

  defp report(targets, results, beliefs) do
    by_id = Map.new(beliefs, &{&1.id, &1})

    Enum.each(targets, fn target ->
      IO.puts("#{target.id}#{if target.name, do: " (#{target.name})"}")

      steps = CB.OutputTarget.rules_map(target)["render_steps"] || []

      Enum.each(steps, fn step ->
        belief = by_id[step["belief"]]

        case Enum.filter(results, &(&1.step == step["id"] and &1.belief == belief.id)) do
          [] ->
            IO.puts("  --    #{step["id"]} - narrates only (non-contract)")

          rows ->
            Enum.each(rows, fn row ->
              tag = if row.result == "pass", do: "PASS", else: "FAIL"
              IO.puts("  #{tag}  #{step["id"]} - #{row.predicate}")
              if row.detail, do: IO.puts("        #{row.detail}")
            end)
        end
      end)
    end)

    {passes, failures} = {count(results, "pass"), count(results, "fail")}
    narrate_only = narrate_only_count(targets, results, by_id)

    IO.puts("")
    IO.puts("#{passes} passed, #{failures} failed, #{narrate_only} narrate-only stop(s)")
  end

  defp count(results, verdict), do: Enum.count(results, &(&1.result == verdict))

  defp narrate_only_count(targets, results, by_id) do
    asserted = MapSet.new(results, & &1.step)

    targets
    |> Enum.flat_map(&(CB.OutputTarget.rules_map(&1)["render_steps"] || []))
    |> Enum.count(fn step ->
      not MapSet.member?(asserted, step["id"]) and not Belief.contract?(by_id[step["belief"]])
    end)
  end

  defp halt(msg) do
    IO.puts(:stderr, "cb.verify.codepath: #{msg}")
    System.halt(1)
  end
end
