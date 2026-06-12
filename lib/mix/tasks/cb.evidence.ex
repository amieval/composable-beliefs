defmodule Mix.Tasks.Cb.Evidence do
  @moduledoc """
  Append a dated evidence entry to an existing belief.

  The sanctioned front door for evidence appends - the one in-place
  growth point on an immutable node. Routes through
  `CB.Belief.Mutation` and `CB.Belief.Store.write/2`, so the entry's
  key order and the graph's serialization are pinned by the same code
  every other write uses - no hand-rolled store scripts, no encoder
  drift.

  ## Usage

      mix cb.evidence <belief-id> --detail "..." --artifact <uri>   # Dry run
      mix cb.evidence <belief-id> --detail "..." --artifact <uri> --write

  The belief id may be bare (`a522`) or namespaced (`cb:a522`); a bare
  id resolves when exactly one belief matches.

  ## Options

  - `--detail` (required) - the evidence text
  - `--artifact` (required) - artifact URI (`document:...`, `session:...`)
  - `--date` - ISO date for the entry; defaults to today
  - `--beliefs PATH` - operate on an alternate collection (`CB_BELIEFS`
    env var works too)
  - `--write` - apply; without it the entry is printed but not written

  ## Validation

  Exits non-zero before writing if the belief id is missing or
  ambiguous, the detail is empty, the artifact is not a `scheme:rest`
  URI, or the date is not a valid ISO date. The artifact scheme is not
  checked against the artifact-scheme enum (cb:c043) - that enum closes
  the set of top-level `artifact` schemes, while evidence artifacts
  also carry provenance schemes like `adjudication:`.
  """
  @shortdoc "Append a dated evidence entry to an existing belief"

  use Mix.Task

  alias CB.Belief.Graph
  alias CB.Belief.Mutation
  alias CB.Belief.Store

  @impl Mix.Task
  def run(args) do
    {opts, positional, invalid} =
      OptionParser.parse(args,
        strict: [
          detail: :string,
          artifact: :string,
          date: :string,
          write: :boolean,
          beliefs: :string
        ]
      )

    if invalid != [] do
      flags = Enum.map_join(invalid, ", ", fn {flag, _} -> flag end)
      halt("unknown options: #{flags}")
    end

    if path = opts[:beliefs], do: Application.put_env(:cb, :beliefs_path, path)

    id =
      case positional do
        [id] ->
          id

        _ ->
          IO.puts(:stderr, usage())
          System.halt(1)
      end

    with {:ok, detail} <- validate_detail(opts[:detail]),
         {:ok, artifact} <- validate_artifact(opts[:artifact]),
         {:ok, date} <- validate_date(opts[:date]) do
      append(id, detail, artifact, date, opts[:write] || false)
    else
      {:error, message} -> halt(message)
    end
  end

  defp append(id, detail, artifact, date, write?) do
    with {:ok, beliefs} <- Store.read(),
         {:ok, canonical} <- resolve(beliefs, id) do
      mutation =
        %{
          type: "append-evidence",
          id: "cb.evidence",
          belief_id: canonical,
          detail: detail,
          artifact: artifact
        }
        |> put_date(date)

      {:ok, updated} = Mutation.apply_one(mutation, beliefs)
      report(beliefs, updated, canonical)

      if write? do
        case Store.write(updated) do
          {:ok, _path} ->
            IO.puts(:stderr, "\nAppended. Run `mix cb.verify.schema` to check conformance.")

          {:error, reason} ->
            halt("error writing belief graph: #{inspect(reason)}")
        end
      else
        IO.puts(:stderr, "\nDry run. Pass --write to apply.")
      end
    else
      {:error, reason} when is_binary(reason) -> halt(reason)
      {:error, reason} -> halt(inspect(reason))
    end
  end

  defp put_date(mutation, nil), do: mutation
  defp put_date(mutation, date), do: Map.put(mutation, :date, date)

  defp resolve(beliefs, id) do
    case Graph.resolve_id(beliefs, id) do
      {:ok, canonical} ->
        {:ok, canonical}

      {:error, :not_found} ->
        {:error, "no belief with id: #{id}"}

      {:error, {:ambiguous, ids}} ->
        {:error, "ambiguous id '#{id}' matches: #{Enum.join(ids, ", ")} - qualify the namespace"}
    end
  end

  defp report(before, updated, canonical) do
    belief = Enum.find(updated, &(&1.id == canonical))
    prior = Enum.find(before, &(&1.id == canonical))
    entry = List.last(belief.evidence)

    IO.puts("Evidence append")
    IO.puts(String.duplicate("=", 40))
    IO.puts("\n#{belief.id} (#{belief.type}/#{belief.kind})")
    IO.puts("  #{truncate(belief.claim, 76)}")
    IO.puts("\nEvidence #{length(prior.evidence || []) + 1}:")
    IO.puts("  date:     #{entry["date"]}")
    IO.puts("  detail:   #{entry["detail"]}")
    IO.puts("  artifact: #{entry["artifact"]}")
  end

  defp truncate(nil, _max), do: "-"

  defp truncate(text, max) do
    if String.length(text) > max, do: String.slice(text, 0, max - 1) <> "…", else: text
  end

  @doc """
  Validate the `--detail` value: required and non-empty.
  """
  @spec validate_detail(String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def validate_detail(nil), do: {:error, "--detail is required"}

  def validate_detail(detail) do
    if String.trim(detail) == "" do
      {:error, "--detail must not be empty"}
    else
      {:ok, detail}
    end
  end

  @doc """
  Validate the `--artifact` value: required, and shaped `scheme:rest`
  with a lowercase scheme and a non-empty rest.
  """
  @spec validate_artifact(String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def validate_artifact(nil), do: {:error, "--artifact is required"}

  def validate_artifact(artifact) do
    if artifact =~ ~r/^[a-z][a-z0-9-]*:.+/ do
      {:ok, artifact}
    else
      {:error, "--artifact must be a scheme:rest URI (e.g. document:plans/x.md), got: #{artifact}"}
    end
  end

  @doc """
  Validate the optional `--date` value as an ISO 8601 date. `nil`
  passes through - the mutation defaults to today.
  """
  @spec validate_date(String.t() | nil) :: {:ok, String.t() | nil} | {:error, String.t()}
  def validate_date(nil), do: {:ok, nil}

  def validate_date(date) do
    case Date.from_iso8601(date) do
      {:ok, _} -> {:ok, date}
      {:error, _} -> {:error, "--date must be an ISO date (YYYY-MM-DD), got: #{date}"}
    end
  end

  defp usage do
    "Usage: mix cb.evidence <belief-id> --detail \"...\" --artifact <uri> [--date YYYY-MM-DD] [--write]"
  end

  @spec halt(String.t()) :: no_return()
  defp halt(message) do
    IO.puts(:stderr, "Error: #{message}")
    System.halt(1)
  end
end
