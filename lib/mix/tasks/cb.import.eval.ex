defmodule Mix.Tasks.Cb.Import.Eval do
  @moduledoc """
  Import a run-manifest as observation beliefs in an eval collection.

  The run-manifest (`docs/run-manifest.md`) is the contract between the
  lab bench and the ledger: a harness adapter emits it, this task
  materializes it - deterministically - through the existing import
  path. The importer is mechanical and emits **primitives only**: one
  aggregate observation per `(run, ruler)` pair, one six-subject
  primitive per load-bearing case. Cross-ruler agreement compounds and
  verdicts are authored by a human through the normal write flow.

  ## Usage

      mix cb.import.eval <manifest.json> --collection <path/to/beliefs.json>            # dry run
      mix cb.import.eval <manifest.json> --collection <path/to/beliefs.json> --write    # apply

  The target collection's namespace is read from the `manifest.json`
  beside its `beliefs.json`. The dry run prints the generated import
  spec; `--write` hands it to `mix cb.import`'s apply path.

  ## Determinism and idempotence

  Belief ids hash the observation's identity tuple (eval, run, ruler
  [, case]), so the same manifest always generates the same spec.
  Observations that already exist with identical content are detected
  and skipped (a re-import is a no-op); an existing id with *different*
  content is a hard error - observations are immutable measurements,
  and a corrected run is a new `run_id`.

  ## Guards

  - Each fresh observation is preflighted against the collection;
    contract-level conflicts block the import (a conflict is a signal,
    not an obstacle to bypass).
  - An import yielding more than #{50} beliefs warns: the manifest's
    load-bearing list is probably wrong - the graph must stay
    human-readable.

  ## Exit codes

  0 = imported / clean dry run / detected no-op; 1 = invalid manifest,
  unresolvable collection, changed content under an existing identity,
  or contract-level preflight conflict.
  """
  @shortdoc "Import a run-manifest as observation beliefs (see docs/run-manifest.md)"

  use Mix.Task

  alias CB.Belief
  alias CB.Belief.Conflict
  alias CB.Eval.Manifest
  alias CB.JSON

  @volume_threshold 50

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args, strict: [collection: :string, write: :boolean])

    with {:ok, manifest_path} <- one_positional(positional),
         {:ok, collection_path} <- require_collection(opts[:collection]) do
      case process(manifest_path, collection_path) do
        {:ok, result} -> emit(result, collection_path, opts[:write] || false)
        {:error, reason} -> halt(format_error(reason))
      end
    else
      {:error, usage} -> halt(usage)
    end
  end

  @doc """
  Test-friendly core: validate the manifest, generate the spec, and
  partition it against the collection. Pure of IO besides reads.

  Returns `{:ok, %{namespace, generated, new, noop, warnings}}` or
  `{:error, reason}` - including `{:identity_conflicts, ids}` when the
  manifest changed under existing observation ids, and
  `{:preflight_conflicts, entries}` when a fresh observation collides
  with the collection at contract level.
  """
  def process(manifest_path, collection_path) do
    with {:ok, namespace} <- read_namespace(collection_path),
         {:ok, manifest} <- Manifest.load(manifest_path),
         {:ok, existing} <- read_collection(collection_path) do
      generated = Manifest.to_beliefs(manifest, namespace)
      plan = Manifest.plan(generated, existing)

      cond do
        plan.conflicts != [] ->
          {:error, {:identity_conflicts, plan.conflicts}}

        contract_conflicts(plan.new, existing) != [] ->
          {:error, {:preflight_conflicts, contract_conflicts(plan.new, existing)}}

        true ->
          {:ok,
           %{
             namespace: namespace,
             generated: generated,
             new: plan.new,
             noop: plan.noop,
             warnings: volume_warnings(generated)
           }}
      end
    end
  end

  # --- core helpers ---

  defp contract_conflicts(new_beliefs, existing) do
    for b <- new_beliefs,
        entry <- Conflict.preflight(Belief.from_map(b), existing).conflicting,
        entry[:priority] == :contract_level do
      {b["id"], entry.id, entry.reasons}
    end
  end

  defp volume_warnings(generated) do
    if length(generated) > @volume_threshold do
      [
        "manifest yields #{length(generated)} beliefs (threshold #{@volume_threshold}): " <>
          "the load-bearing case list is probably too broad - the graph must stay human-readable"
      ]
    else
      []
    end
  end

  defp read_namespace(collection_path) do
    manifest_path = collection_path |> Path.dirname() |> Path.join("manifest.json")

    case JSON.read(manifest_path) do
      {:ok, %{"namespace" => ns}} when is_binary(ns) and ns != "" ->
        {:ok, ns}

      {:ok, _} ->
        {:error, {:no_namespace, manifest_path}}

      {:error, reason} ->
        {:error, {:collection_manifest_unreadable, manifest_path, reason}}
    end
  end

  defp read_collection(path) do
    cond do
      not File.exists?(path) ->
        {:ok, []}

      true ->
        case JSON.read(path) do
          {:ok, data} when is_list(data) -> {:ok, Enum.map(data, &Belief.from_map/1)}
          {:ok, _} -> {:error, {:collection_not_a_list, path}}
          {:error, reason} -> {:error, {:collection_unreadable, path, reason}}
        end
    end
  end

  # --- io / apply ---

  defp emit(result, collection_path, write?) do
    Enum.each(result.warnings, &IO.puts(:stderr, "warning: #{&1}"))

    IO.puts(:stderr, summary(result))

    cond do
      result.new == [] ->
        IO.puts(:stderr, "No-op: nothing to import.")

      write? ->
        apply_via_import(result.new, collection_path)

      true ->
        IO.puts(spec_json(result.new))
        IO.puts(:stderr, "\nDry run. Pass --write to apply.")
    end
  end

  defp summary(result) do
    aggregates = Enum.count(result.generated, &("aggregate" in (&1["tags"] || [])))
    cases = length(result.generated) - aggregates

    "Run-manifest -> #{result.namespace}: #{length(result.generated)} observation(s) " <>
      "(#{aggregates} aggregate, #{cases} load-bearing case), " <>
      "#{length(result.new)} new, #{length(result.noop)} already present (no-op)."
  end

  # Hand the fresh beliefs to the existing import path: serialize the
  # canonical spec, point the store at the collection, run cb.import.
  defp apply_via_import(new_beliefs, collection_path) do
    spec_path =
      Path.join(System.tmp_dir!(), "cb-import-eval-spec-#{System.os_time(:millisecond)}.json")

    File.write!(spec_path, spec_json(new_beliefs))
    Application.put_env(:cb, :beliefs_path, collection_path)
    Mix.Tasks.Cb.Import.run([spec_path, "--write"])
  after
    Application.delete_env(:cb, :beliefs_path)
  end

  @doc false
  # Canonical spec JSON: each belief routed through the struct boundary
  # so key order is the on-disk order - same manifest, same bytes.
  def spec_json(new_beliefs) do
    ordered = Enum.map(new_beliefs, &(&1 |> Belief.from_map() |> Belief.to_map()))
    Jason.encode!(%{"new_beliefs" => ordered}, pretty: true)
  end

  # --- argument handling / errors ---

  defp one_positional([manifest_path]), do: {:ok, manifest_path}

  defp one_positional(_),
    do:
      {:error,
       "Usage: mix cb.import.eval <manifest.json> --collection <path/to/beliefs.json> [--write]"}

  defp require_collection(nil),
    do:
      {:error,
       "Usage: mix cb.import.eval <manifest.json> --collection <path/to/beliefs.json> [--write]"}

  defp require_collection(path), do: {:ok, path}

  defp format_error({:identity_conflicts, ids}) do
    "manifest changed under existing observation identity: #{Enum.join(ids, ", ")}. " <>
      "Observations are immutable measurements - a corrected run is a new run_id."
  end

  defp format_error({:preflight_conflicts, entries}) do
    rendered =
      Enum.map_join(entries, "; ", fn {new_id, existing_id, reasons} ->
        "#{new_id} vs #{existing_id} (#{Enum.join(Enum.map(reasons, &to_string/1), ", ")})"
      end)

    "preflight found contract-level conflicts: #{rendered}. " <>
      "A conflict is a signal - adjudicate through the write flow rather than importing over it."
  end

  defp format_error({:no_namespace, path}),
    do: "collection manifest #{path} declares no namespace"

  defp format_error({:collection_manifest_unreadable, path, reason}),
    do: "cannot read collection manifest #{path}: #{inspect(reason)}"

  defp format_error({:collection_not_a_list, path}), do: "collection #{path} is not a JSON array"

  defp format_error({:collection_unreadable, path, reason}),
    do: "cannot read collection #{path}: #{inspect(reason)}"

  defp format_error(other), do: Manifest.format_error(other)

  defp halt(msg) do
    IO.puts(:stderr, "cb.import.eval: #{msg}")
    System.halt(1)
  end
end
