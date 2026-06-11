defmodule CB.Eval.Manifest do
  @moduledoc """
  Parse, validate, and materialize run-manifests (`docs/run-manifest.md`).

  The run-manifest is the neutral JSON record a harness adapter emits;
  this module turns it into observation belief maps deterministically:
  the same manifest always yields a byte-identical list of beliefs, ids
  derive from identity tuples (never content), and `created`/evidence
  dates come from the manifest's own `date` - never from the clock.

  The importer stays mechanical: aggregates and load-bearing case
  primitives only. No compounds, no verdicts - the judgment layer is a
  human authoring through the normal write flow.

  Everything here is pure; `Mix.Tasks.Cb.Import.Eval` owns IO.
  """

  alias CB.Belief

  @supported_version 1
  @log_schemes ~w(document https)
  @hash_prefix "cb-eval-v1|"

  @type manifest :: map()
  @type error ::
          {:unsupported_manifest_version, term()}
          | {:missing_field, String.t()}
          | {:invalid_field, String.t(), String.t()}
          | {:duplicate, String.t(), term()}
          | {:manifest_unreadable, String.t(), term()}
          | {:malformed_json, String.t()}

  # --- load + validate ---

  @doc "Read and validate a manifest file. Returns `{:ok, manifest}` or `{:error, error}`."
  @spec load(String.t()) :: {:ok, manifest()} | {:error, error()}
  def load(path) do
    with {:ok, raw} <- read_file(path),
         {:ok, decoded} <- decode(raw) do
      validate(decoded)
    end
  end

  @doc """
  Validate a decoded manifest map against the version-1 spec.

  Unknown `manifest_version` values refuse rather than best-effort
  parse. Returns `{:ok, manifest}` (the input, unchanged) or the first
  `{:error, error}` encountered, with the offending field path named.
  """
  @spec validate(map()) :: {:ok, manifest()} | {:error, error()}
  def validate(%{"manifest_version" => @supported_version} = m) do
    with :ok <- require_string(m, "eval_id"),
         :ok <- require_date(m, "date"),
         :ok <- require_string(m, "model"),
         :ok <- require_string(m, "model_version"),
         :ok <- validate_harness(m["harness"]),
         :ok <- validate_tags(m["tags"]),
         :ok <- validate_runs(m["runs"]) do
      {:ok, m}
    end
  end

  def validate(%{"manifest_version" => other}),
    do: {:error, {:unsupported_manifest_version, other}}

  def validate(_), do: {:error, {:missing_field, "manifest_version"}}

  # --- materialization ---

  @doc """
  Materialize the manifest as observation belief maps for `namespace`.

  Deterministic: manifest order is preserved (runs, then scorers; each
  scorer's aggregate before its load-bearing cases), ids hash the
  identity tuple, and all dates come from the manifest. Returns plain
  string-keyed maps in on-disk shape.
  """
  @spec to_beliefs(manifest(), String.t()) :: [map()]
  def to_beliefs(manifest, namespace) do
    for run <- manifest["runs"],
        scorer <- run["scorers"],
        belief <-
          [aggregate_belief(manifest, namespace, run, scorer)] ++
            case_beliefs(manifest, namespace, run, scorer) do
      belief
    end
  end

  @doc """
  Partition generated beliefs against the existing collection.

  - `:new` - ids not present on disk; safe to import.
  - `:noop` - id present with byte-identical canonical content; a
    re-import, detected and skipped.
  - `:conflicts` - id present with *different* content: a changed
    manifest under the same observation identity. Observations are
    immutable measurements - this is a hard error upstream; a corrected
    run is a new `run_id`.
  """
  @spec plan([map()], [Belief.t()]) :: %{
          new: [map()],
          noop: [String.t()],
          conflicts: [String.t()]
        }
  def plan(generated, existing) do
    existing_canon = Map.new(existing, &{&1.id, canonical(&1)})

    Enum.reduce(generated, %{new: [], noop: [], conflicts: []}, fn b, acc ->
      case Map.fetch(existing_canon, b["id"]) do
        :error ->
          %{acc | new: acc.new ++ [b]}

        {:ok, canon} ->
          if canonical(Belief.from_map(b)) == canon do
            %{acc | noop: acc.noop ++ [b["id"]]}
          else
            %{acc | conflicts: acc.conflicts ++ [b["id"]]}
          end
      end
    end)
  end

  @doc "Render a named validation error as a human-readable message."
  @spec format_error(error()) :: String.t()
  def format_error({:unsupported_manifest_version, v}),
    do:
      "unsupported manifest_version #{inspect(v)} (this importer reads version #{@supported_version}; refusing rather than best-effort parsing)"

  def format_error({:missing_field, path}), do: "missing required field: #{path}"
  def format_error({:invalid_field, path, why}), do: "invalid field #{path}: #{why}"
  def format_error({:duplicate, path, value}), do: "duplicate #{path}: #{inspect(value)}"

  def format_error({:manifest_unreadable, path, reason}),
    do: "cannot read manifest #{path}: #{inspect(reason)}"

  def format_error({:malformed_json, message}), do: "malformed manifest JSON: #{message}"
  def format_error(other), do: inspect(other)

  # --- belief construction ---

  defp aggregate_belief(m, ns, run, scorer) do
    counts = scorer["aggregate"]["outcome_counts"]
    ruler = scorer["ruler"]

    %{
      "id" => "#{ns}:o-#{hash([m["eval_id"], run["run_id"], ruler])}",
      "type" => "primitive",
      "kind" => "observation",
      "domain" => "eval",
      "tags" => Enum.uniq(["aggregate"] ++ outcome_tags(counts) ++ (m["tags"] || [])),
      "claim" =>
        "Run #{run["run_id"]} of #{m["eval_id"]} against #{m["model_version"]}, scored by #{ruler}: " <>
          "outcomes over #{run["cases"]} case(s) - #{counts_sentence(counts)}.",
      "artifact" => "eval:#{m["eval_id"]}/#{run["run_id"]}/#{ruler}",
      "evidence" => [
        %{
          "date" => m["date"],
          "detail" =>
            "Imported from run-manifest by cb.import.eval. #{harness_sentence(m["harness"])} " <>
              "Aggregate of ruler #{ruler} over #{run["cases"]} case(s) of #{run["run_id"]}.",
          "artifact" => run["log"]
        }
      ],
      "subjects" => subjects(m, run, ruler, nil),
      "deps" => [],
      "status" => "active",
      "created" => m["date"]
    }
  end

  defp case_beliefs(m, ns, run, scorer) do
    ruler = scorer["ruler"]

    for c <- scorer["load_bearing_cases"] || [] do
      %{
        "id" => "#{ns}:o-#{hash([m["eval_id"], run["run_id"], ruler, c["case_id"]])}",
        "type" => "primitive",
        "kind" => "observation",
        "domain" => "eval",
        "tags" => Enum.uniq(["outcome:#{c["outcome"]}"] ++ (m["tags"] || [])),
        "claim" =>
          "Case #{c["case_id"]} of run #{run["run_id"]} in #{m["eval_id"]} against #{m["model_version"]}, " <>
            "scored by #{ruler}: outcome #{c["outcome"]}." <> detail_suffix(c["detail"]),
        "artifact" => "eval:#{m["eval_id"]}/#{run["run_id"]}/#{c["case_id"]}/#{ruler}",
        "evidence" => [
          %{
            "date" => m["date"],
            "detail" =>
              "Imported from run-manifest by cb.import.eval. #{harness_sentence(m["harness"])} " <>
                "Load-bearing case #{c["case_id"]} scored by ruler #{ruler} on #{run["run_id"]}.",
            "artifact" => c["log"] || run["log"]
          }
        ],
        "subjects" => subjects(m, run, ruler, c["case_id"]),
        "deps" => [],
        "status" => "active",
        "created" => m["date"]
      }
    end
  end

  defp subjects(m, run, ruler, case_id) do
    [
      %{"ref" => "eval/#{m["eval_id"]}", "type" => "eval"},
      %{"ref" => "run/#{run["run_id"]}", "type" => "run"}
    ] ++
      case_subject(case_id) ++
      [
        %{"ref" => "model/#{m["model"]}", "type" => "model"},
        %{"ref" => "model-version/#{m["model_version"]}", "type" => "model_version"},
        %{"ref" => "ruler/#{ruler}", "type" => "ruler"}
      ]
  end

  defp case_subject(nil), do: []
  defp case_subject(case_id), do: [%{"ref" => "case/#{case_id}", "type" => "case"}]

  # First 8 hex chars of sha256 over the identity tuple - normalized
  # fields joined with "|" after a fixed prefix, never raw JSON. Spec'd
  # in docs/run-manifest.md; ids are immutable once written.
  defp hash(identity_fields) do
    :crypto.hash(:sha256, @hash_prefix <> Enum.join(identity_fields, "|"))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 8)
  end

  defp outcome_tags(counts) do
    counts
    |> Enum.filter(fn {_k, v} -> v > 0 end)
    |> Enum.map(fn {k, _v} -> "outcome:#{k}" end)
    |> Enum.sort()
  end

  defp counts_sentence(counts) do
    counts
    |> Enum.sort_by(fn {k, _v} -> k end)
    |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)
  end

  defp harness_sentence(h) do
    parts =
      [
        {"Harness", h["name"]},
        {"version", h["version"]},
        {"task", h["task"]},
        {"config digest", h["config_digest"]}
      ]
      |> Enum.filter(fn {_label, v} -> is_binary(v) and v != "" end)
      |> Enum.map_join(", ", fn {label, v} -> "#{label}: #{v}" end)

    parts <> "."
  end

  defp detail_suffix(nil), do: ""
  defp detail_suffix(""), do: ""
  defp detail_suffix(detail), do: " " <> detail

  defp canonical(%Belief{} = b), do: b |> Belief.to_map() |> Jason.encode!()

  # --- validation helpers ---

  defp read_file(path) do
    case File.read(path) do
      {:ok, raw} -> {:ok, raw}
      {:error, reason} -> {:error, {:manifest_unreadable, path, reason}}
    end
  end

  defp decode(raw) do
    case Jason.decode(raw) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:ok, _} -> {:error, {:malformed_json, "manifest must be a JSON object"}}
      {:error, %Jason.DecodeError{} = e} -> {:error, {:malformed_json, Exception.message(e)}}
    end
  end

  defp require_string(map, field) do
    case map[field] do
      v when is_binary(v) and v != "" -> :ok
      nil -> {:error, {:missing_field, field}}
      _ -> {:error, {:invalid_field, field, "must be a non-empty string"}}
    end
  end

  defp require_date(map, field) do
    with :ok <- require_string(map, field) do
      case Date.from_iso8601(map[field]) do
        {:ok, _} -> :ok
        {:error, _} -> {:error, {:invalid_field, field, "must be an ISO date (YYYY-MM-DD)"}}
      end
    end
  end

  defp validate_harness(%{"name" => name} = h) when is_binary(name) and name != "" do
    optional =
      ~w(version task config_digest)
      |> Enum.find(fn k -> Map.has_key?(h, k) and not is_binary(h[k]) end)

    case optional do
      nil -> :ok
      key -> {:error, {:invalid_field, "harness.#{key}", "must be a string"}}
    end
  end

  defp validate_harness(%{}), do: {:error, {:missing_field, "harness.name"}}
  defp validate_harness(_), do: {:error, {:missing_field, "harness"}}

  defp validate_tags(nil), do: :ok

  defp validate_tags(tags) when is_list(tags) do
    if Enum.all?(tags, &(is_binary(&1) and &1 != "")) do
      :ok
    else
      {:error, {:invalid_field, "tags", "must be a list of non-empty strings"}}
    end
  end

  defp validate_tags(_), do: {:error, {:invalid_field, "tags", "must be a list"}}

  defp validate_runs(runs) when is_list(runs) and runs != [] do
    with :ok <- unique(runs, "run_id", "runs[].run_id") do
      Enum.reduce_while(runs, :ok, fn run, :ok ->
        case validate_run(run) do
          :ok -> {:cont, :ok}
          err -> {:halt, err}
        end
      end)
    end
  end

  defp validate_runs(nil), do: {:error, {:missing_field, "runs"}}
  defp validate_runs(_), do: {:error, {:invalid_field, "runs", "must be a non-empty list"}}

  defp validate_run(run) do
    rid = run["run_id"]

    with :ok <- require_string(run, "run_id"),
         :ok <- require_log_uri(run["log"], "runs[#{rid}].log"),
         :ok <- require_positive_int(run["cases"], "runs[#{rid}].cases"),
         :ok <- validate_scorers(run["scorers"], run) do
      :ok
    end
  end

  defp validate_scorers(scorers, run) when is_list(scorers) and scorers != [] do
    rid = run["run_id"]

    with :ok <- unique(scorers, "ruler", "runs[#{rid}].scorers[].ruler") do
      Enum.reduce_while(scorers, :ok, fn scorer, :ok ->
        case validate_scorer(scorer, run) do
          :ok -> {:cont, :ok}
          err -> {:halt, err}
        end
      end)
    end
  end

  defp validate_scorers(nil, run),
    do: {:error, {:missing_field, "runs[#{run["run_id"]}].scorers"}}

  defp validate_scorers(_, run),
    do: {:error, {:invalid_field, "runs[#{run["run_id"]}].scorers", "must be a non-empty list"}}

  defp validate_scorer(scorer, run) do
    rid = run["run_id"]
    ruler = scorer["ruler"]
    path = "runs[#{rid}].scorers[#{ruler}]"

    with :ok <- require_string(scorer, "ruler"),
         :ok <- validate_counts(scorer["aggregate"], path),
         :ok <- validate_cases(scorer["load_bearing_cases"] || [], run, path) do
      :ok
    end
  end

  defp validate_counts(%{"outcome_counts" => counts}, path) when is_map(counts) do
    bad =
      Enum.find(counts, fn {k, v} ->
        not (is_binary(k) and k != "" and is_integer(v) and v >= 0)
      end)

    case bad do
      nil ->
        :ok

      {k, v} ->
        {:error,
         {:invalid_field, "#{path}.aggregate.outcome_counts",
          "#{inspect(k)} => #{inspect(v)} (counts are non-negative integers keyed by outcome name)"}}
    end
  end

  defp validate_counts(_, path),
    do: {:error, {:missing_field, "#{path}.aggregate.outcome_counts"}}

  defp validate_cases(cases, run, path) when is_list(cases) do
    cond do
      length(cases) > run["cases"] ->
        {:error,
         {:invalid_field, "#{path}.load_bearing_cases",
          "#{length(cases)} load-bearing cases exceed the run's #{run["cases"]} cases"}}

      true ->
        with :ok <- unique(cases, "case_id", "#{path}.load_bearing_cases[].case_id") do
          Enum.reduce_while(cases, :ok, fn c, :ok ->
            with :ok <- require_string(c, "case_id"),
                 :ok <- require_string(c, "outcome"),
                 :ok <-
                   optional_log_uri(c["log"], "#{path}.load_bearing_cases[#{c["case_id"]}].log") do
              {:cont, :ok}
            else
              err -> {:halt, err}
            end
          end)
        end
    end
  end

  defp validate_cases(_, _run, path),
    do: {:error, {:invalid_field, "#{path}.load_bearing_cases", "must be a list"}}

  defp require_log_uri(uri, path) do
    case uri do
      v when is_binary(v) ->
        case String.split(v, ":", parts: 2) do
          [scheme, rest] when scheme in @log_schemes and rest != "" ->
            :ok

          _ ->
            {:error,
             {:invalid_field, path,
              "must be an artifact URI with scheme #{Enum.join(@log_schemes, " or ")}"}}
        end

      nil ->
        {:error, {:missing_field, path}}

      _ ->
        {:error, {:invalid_field, path, "must be a string artifact URI"}}
    end
  end

  defp optional_log_uri(nil, _path), do: :ok
  defp optional_log_uri(uri, path), do: require_log_uri(uri, path)

  defp require_positive_int(v, _path) when is_integer(v) and v > 0, do: :ok
  defp require_positive_int(nil, path), do: {:error, {:missing_field, path}}

  defp require_positive_int(_, path),
    do: {:error, {:invalid_field, path, "must be a positive integer"}}

  defp unique(items, key, path) do
    values = Enum.map(items, & &1[key])
    dupes = values -- Enum.uniq(values)

    case dupes do
      [] -> :ok
      [d | _] -> {:error, {:duplicate, path, d}}
    end
  end
end
