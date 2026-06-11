defmodule Mix.Tasks.Cb.Migrate.V2 do
  @moduledoc """
  Migrate a belief collection from the three-type schema (v1) to the
  four-type schema (v2): primitive, compound, inference, directive.

  The tool applies the mechanical class (M) deterministically and emits a
  triage report for everything that needs judgment (J) or an adjudicated
  split (S). It never guesses: unresolved nodes block `--write`. The
  report is the work order.

  ## Mechanical rules

  - contract-grade beliefs -> `directive` (any status)
  - v1 `implication` with a prescriptive kind -> `directive`
  - superseded/retracted v1 `implication` history is re-typed by best
    fit and never split: descriptive kind -> `inference`, otherwise
    `directive` (the v1 implication's dominant prescriptive sense)
  - `primitive` with a prescriptive kind and a stipulation artifact
    (`plan:`/`user:`/`session:`/`document:`) -> `directive` (the
    grounding rule)

  ## Triage (blocks --write until resolved)

  - active v1 `implication` with a descriptive kind (e.g. a verdict):
    split candidate - the finding and the prescription part ways
  - active `compound` whose subjects escape the union of its deps'
    subjects: inference-shaped, or a claim to trim
  - active beliefs with a dual-mood kind (`definition`, `schema`) on a
    v1 `implication`: mood decided per belief
  - prescriptive-kind primitives without a stipulation artifact

  Resolve via `--resolutions <file>`:

      {"resolutions": {"sdl:a3": {"type": "compound", "note": "trimmed"}}}

  Dual-kind primitives are listed informationally and kept primitive
  (reportive reading is the primitive default).

  ## Usage

      mix cb.migrate.v2 --collection path/to/beliefs.json            # report
      mix cb.migrate.v2 --collection path/to/beliefs.json --write    # apply

  `--write` re-types the nodes, writes the graph back, and stamps
  `"schema_version": 2` into the sibling manifest.json (creating the
  manifest if the collection has none).
  """
  @shortdoc "Migrate a belief collection to the four-type v2 schema"

  use Mix.Task

  alias CB.Belief

  # Kind -> mood groups, from the v2 design (plans/cb-schema-v2/design.md).
  # The union of the framework enum (cb:c039) and the method-collection
  # vocabulary (method:c2); the kind-type derivation-table contract carries
  # the same rows in the graph once v2 canon lands.
  @directive_only ~w(policy rule action-item convention formatting-rule
    domain-rule domain-enum governance design-principle derivation-rule
    audit-rule enum-registry state-machine derivation-table output-target
    guidance protocol implies)

  @never_directive ~w(observation fact error error-pattern reasoning-error
    meta-observation design-observation design-property design-gap
    design-rationale analogical-claim structural-parallel
    architectural-synthesis feedback-loop outcome-claim
    training-distribution training-incentive agent-architecture
    composable-belief human-factor edit-pair verdict)

  @dual ~w(definition schema)

  @stipulation_schemes ~w(plan user session document)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [collection: :string, write: :boolean, resolutions: :string]
      )

    path =
      opts[:collection] ||
        halt(
          "Usage: mix cb.migrate.v2 --collection <beliefs.json> [--write] [--resolutions <file>]"
        )

    write? = opts[:write] || false

    beliefs = read_beliefs(path)
    resolutions = read_resolutions(opts[:resolutions])

    {changes, blockers, dual_info} = classify(beliefs, resolutions)

    report(path, beliefs, changes, blockers, dual_info)

    cond do
      blockers != [] and write? ->
        halt(
          "\n--write blocked: #{length(blockers)} unresolved triage node(s). The report is the work order."
        )

      write? ->
        apply_changes(path, beliefs, changes)

      true ->
        IO.puts(:stderr, "\nDry run. Pass --write to apply (blocked while triage nodes remain).")
    end
  end

  # --- classification ---

  @doc false
  def classify(beliefs, resolutions \\ %{}) do
    by_id = Map.new(beliefs, &{&1.id, &1})

    {changes, blockers, dual_info} =
      Enum.reduce(beliefs, {[], [], []}, fn b, {changes, blockers, dual_info} ->
        # A resolution is a full override: it settles triage nodes and
        # carries judgment re-homes the deterministic rules cannot see
        # (e.g. an inference-shaped compound with empty subjects).
        case Map.get(resolutions, b.id) do
          %{"type" => to} when to in ~w(primitive compound inference directive) ->
            if to == b.type do
              {changes, blockers, dual_info}
            else
              {[{b.id, b.type, to, "resolution"} | changes], blockers, dual_info}
            end

          _ ->
            case decide(b, by_id) do
              {:retype, to, reason} when to != b.type ->
                {[{b.id, b.type, to, reason} | changes], blockers, dual_info}

              {:retype, _same, _reason} ->
                {changes, blockers, dual_info}

              :unchanged ->
                {changes, blockers, dual_info}

              {:dual_info, note} ->
                {changes, blockers, [{b.id, note} | dual_info]}

              {:triage, reason} ->
                {changes, [{b.id, reason} | blockers], dual_info}
            end
        end
      end)

    {Enum.reverse(changes), Enum.reverse(blockers), Enum.reverse(dual_info)}
  end

  defp decide(%Belief{contract: true}, _by_id) do
    {:retype, "directive", "contract-grade"}
  end

  defp decide(%Belief{type: "implication"} = b, _by_id) do
    active? = b.status == "active"

    cond do
      b.kind in @directive_only ->
        {:retype, "directive", "prescriptive kind #{b.kind}"}

      b.kind in @never_directive and active? ->
        {:triage, "active #{b.kind} implication - split candidate (finding vs prescription)"}

      b.kind in @never_directive ->
        {:retype, "inference", "history best fit (descriptive kind #{b.kind})"}

      b.kind in @dual and active? ->
        {:triage, "active dual-kind (#{b.kind}) implication - mood decided per belief"}

      b.kind in @dual ->
        {:retype, "directive", "history best fit (v1 implication, dual kind #{b.kind})"}

      true ->
        {:triage, "implication with unmapped kind #{inspect(b.kind)}"}
    end
  end

  defp decide(%Belief{type: "primitive"} = b, _by_id) do
    cond do
      b.kind in @directive_only and stipulation?(b) ->
        {:retype, "directive", "grounding rule (#{b.kind} primitive with stipulation artifact)"}

      b.kind in @directive_only and b.status == "active" ->
        {:triage, "prescriptive-kind primitive (#{b.kind}) without stipulation artifact"}

      b.kind in @dual ->
        {:dual_info, "dual kind #{b.kind} kept primitive (reportive default)"}

      true ->
        :unchanged
    end
  end

  defp decide(%Belief{type: "compound"} = b, by_id) do
    cond do
      # A prescriptive kind on a compound is a directive in conjunction
      # clothing: the kind-type table allows it exactly one type, and its
      # deps survive the re-type as grounding.
      b.kind in @directive_only ->
        {:retype, "directive", "prescriptive kind #{b.kind} on compound"}

      b.status == "active" ->
        case containment(b, by_id) do
          {:escapes, refs} ->
            {:triage,
             "compound subjects escape dep union (#{Enum.join(refs, ", ")}) - inference-shaped or trim"}

          _ ->
            :unchanged
        end

      true ->
        :unchanged
    end
  end

  defp decide(_b, _by_id), do: :unchanged

  defp containment(b, by_id) do
    refs = subject_refs(b)
    resolved = Enum.map(b.deps || [], &Map.get(by_id, &1))

    cond do
      refs == [] ->
        :contained

      Enum.any?(resolved, &is_nil/1) ->
        :unresolvable

      true ->
        union = resolved |> Enum.flat_map(&subject_refs/1) |> MapSet.new()

        case Enum.reject(refs, &MapSet.member?(union, &1)) do
          [] -> :contained
          escaped -> {:escapes, escaped}
        end
    end
  end

  defp subject_refs(%{subjects: subjects}) when is_list(subjects) do
    subjects |> Enum.map(& &1["ref"]) |> Enum.reject(&is_nil/1)
  end

  defp subject_refs(_), do: []

  defp stipulation?(%Belief{artifact: a}) when is_binary(a) do
    case String.split(a, ":", parts: 2) do
      [scheme, _] -> scheme in @stipulation_schemes
      _ -> false
    end
  end

  defp stipulation?(_), do: false

  # --- io ---

  defp read_beliefs(path) do
    with {:ok, raw} <- File.read(path),
         {:ok, data} when is_list(data) <- Jason.decode(raw) do
      Enum.map(data, &Belief.from_map/1)
    else
      _ -> halt("Cannot read belief array from #{path}")
    end
  end

  defp read_resolutions(nil), do: %{}

  defp read_resolutions(path) do
    with {:ok, raw} <- File.read(path),
         {:ok, %{"resolutions" => map}} when is_map(map) <- Jason.decode(raw) do
      map
    else
      _ -> halt("Cannot read resolutions map from #{path}")
    end
  end

  defp report(path, beliefs, changes, blockers, dual_info) do
    IO.puts("v2 migration: #{path} (#{length(beliefs)} beliefs)")
    IO.puts(String.duplicate("=", 60))

    IO.puts("\nMechanical re-types: #{length(changes)}")

    Enum.each(changes, fn {id, from, to, reason} ->
      IO.puts("  #{id}: #{from} -> #{to}  [#{reason}]")
    end)

    IO.puts("\nTriage (blocks --write): #{length(blockers)}")

    Enum.each(blockers, fn {id, reason} ->
      IO.puts("  #{id}: #{reason}")
    end)

    if dual_info != [] do
      IO.puts("\nDual-kind review (informational): #{length(dual_info)}")
      Enum.each(dual_info, fn {id, note} -> IO.puts("  #{id}: #{note}") end)
    end
  end

  defp apply_changes(path, beliefs, changes) do
    retype = Map.new(changes, fn {id, _from, to, _reason} -> {id, to} end)

    migrated =
      Enum.map(beliefs, fn b ->
        case Map.get(retype, b.id) do
          nil -> b
          to -> %{b | type: to}
        end
      end)

    ordered = Enum.map(migrated, &Belief.to_map/1)
    content = Jason.encode!(ordered, pretty: true) <> "\n"

    case CB.JSON.write_atomic_raw(path, content) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> halt("Write failed: #{inspect(reason)}")
    end

    stamp_manifest(path)

    IO.puts(
      :stderr,
      "\nWrote #{length(migrated)} beliefs (#{map_size(retype)} re-typed); manifest stamped schema_version 2."
    )

    IO.puts(:stderr, "Run `mix cb.verify.schema` / `mix cb.verify.collection` to confirm.")
  end

  defp stamp_manifest(beliefs_path) do
    manifest_path = beliefs_path |> Path.dirname() |> Path.join("manifest.json")

    manifest =
      case File.read(manifest_path) do
        {:ok, raw} ->
          case Jason.decode(raw) do
            {:ok, m} when is_map(m) -> m
            _ -> halt("Manifest at #{manifest_path} is not a JSON object")
          end

        {:error, :enoent} ->
          %{}

        {:error, reason} ->
          halt("Cannot read manifest #{manifest_path}: #{inspect(reason)}")
      end

    updated = Map.put(manifest, "schema_version", 2)
    File.write!(manifest_path, Jason.encode!(updated, pretty: true) <> "\n")
  end

  defp halt(msg) do
    IO.puts(:stderr, msg)
    System.halt(1)
  end
end
