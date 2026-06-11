defmodule Mix.Tasks.Cb.Preflight do
  @moduledoc """
  Run preflight conflict detection for a proposed belief.

  Read-only authoring-time check. Loads the proposed belief from JSON,
  runs it through `CB.Belief.Conflict.preflight/1` against the live DAG,
  and prints the categorized result for the agent to render to the user.

  Preflight examines all active beliefs across all four structural types
  at authoring time so a proposal cannot land in silent
  contradiction with an existing node.

  Performs no writes. Adjudication is captured separately and applied by
  `mix cb.adjudicate`.

  ## Usage

      mix cb.preflight --file path/to/proposed.json
      mix cb.preflight             # reads JSON from stdin
      mix cb.preflight --json ...  # structured output

  ## Input shape

  A single JSON object with the belief's fields (string keys), matching
  the on-disk shape in the belief graph. The proposal has no `id` yet;
  `claim`, `subjects`, `tags`, and `domain` are the fields that drive the
  match.

      {
        "type": "primitive",
        "kind": "schema",
        "domain": "system",
        "tags": ["dag-schema", "lifecycle"],
        "claim": "...",
        "subjects": [{"ref": "docs/schema.md", "type": "doc"}]
      }

  ## Output

  Categorized text with explicit grouping (dense match lists drown the
  adjudication signal):

      1. CONTRACT-LEVEL CONFLICTS  - block the write outright
      2. DAG-SCHEMA CONFLICTS      - non-contract conflicts
      3. SUPPORTIVE                - dep candidates
      4. NEUTRAL                   - informational only

  Each entry shows the matched belief's id, match reasons, and a
  truncated claim so the agent can render it inline without a second
  lookup.

  ## Exit codes

  - `0` no contract-level conflicts (write may proceed pending
    adjudication of any non-contract conflicts)
  - `2` one or more contract-level conflicts (write must not proceed
    without explicit adjudication)
  - `1` invalid input
  """
  @shortdoc "Preflight conflict check for a proposed belief"

  use Mix.Task

  alias CB.Belief
  alias CB.Belief.Conflict
  alias CB.Belief.Store

  @claim_truncate 80

  @impl Mix.Task
  def run(args) do
    {opts, _positional, _} =
      OptionParser.parse(args,
        strict: [file: :string, json: :boolean],
        aliases: [f: :file, j: :json]
      )

    with {:ok, raw} <- read_input(opts[:file]),
         {:ok, decoded} <- decode(raw),
         {:ok, proposed} <- to_belief(decoded),
         {:ok, existing} <- Store.read() do
      grouped = group(Conflict.preflight(proposed, existing), existing)

      output =
        if opts[:json] do
          Jason.encode!(to_json(grouped), pretty: true)
        else
          render_text(grouped)
        end

      IO.puts(output)
      if grouped.contract_level != [], do: System.halt(2)
    else
      {:error, reason} ->
        IO.puts(:stderr, "preflight error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  # --- input ---

  defp read_input(nil) do
    case IO.read(:stdio, :eof) do
      :eof -> {:error, :empty_stdin}
      {:error, reason} -> {:error, {:stdin, reason}}
      data when is_binary(data) -> {:ok, data}
    end
  end

  defp read_input(path) do
    case File.read(path) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, {:file, path, reason}}
    end
  end

  defp decode(raw) do
    case Jason.decode(raw) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:ok, _} -> {:error, :input_must_be_object}
      {:error, %Jason.DecodeError{} = err} -> {:error, {:json, Exception.message(err)}}
    end
  end

  defp to_belief(map) do
    {:ok, Belief.from_map(map)}
  rescue
    e -> {:error, {:from_map, Exception.message(e)}}
  end

  # --- public for testing ---

  @doc """
  Group a `Conflict.preflight/2` result for rendering.

  Splits `conflicting` into `contract_level` (priority `:contract_level`)
  and `schema_conflicts` (everything else). Enriches each entry with
  the matched belief's `claim` looked up from `existing` so the renderer
  has everything it needs without a second pass over the DAG.
  """
  def group(%{supportive: supp, neutral: neut, conflicting: conf}, existing) do
    by_id = Map.new(existing, &{&1.id, &1})

    {contract_level, schema_only} =
      Enum.split_with(conf, &(&1[:priority] == :contract_level))

    %{
      contract_level: enrich(contract_level, by_id),
      schema_conflicts: enrich(schema_only, by_id),
      supportive: enrich(supp, by_id),
      neutral: enrich(neut, by_id)
    }
  end

  defp enrich(entries, by_id) do
    Enum.map(entries, fn entry ->
      belief = Map.get(by_id, entry.id)
      Map.put(entry, :claim, belief && belief.claim)
    end)
  end

  @doc """
  Render the grouped result as the human-readable text shown to the
  agent during authoring.
  """
  def render_text(grouped) do
    sections = [
      section(
        "CONTRACT-LEVEL CONFLICTS (block write — adjudicate)",
        grouped.contract_level
      ),
      section(
        "DAG-SCHEMA / NON-CONTRACT CONFLICTS (require adjudication)",
        grouped.schema_conflicts
      ),
      section("SUPPORTIVE MATCHES (dep candidates)", grouped.supportive),
      section("NEUTRAL MATCHES (informational)", grouped.neutral)
    ]

    summary =
      "Summary: #{length(grouped.contract_level)} contract, " <>
        "#{length(grouped.schema_conflicts)} schema, " <>
        "#{length(grouped.supportive)} supportive, " <>
        "#{length(grouped.neutral)} neutral"

    Enum.join(["Preflight result", String.duplicate("=", 40)] ++ sections ++ ["", summary], "\n")
  end

  defp section(title, []) do
    Enum.join(["", title, "  (none)"], "\n")
  end

  defp section(title, entries) do
    Enum.join(["", title | Enum.map(entries, &format_entry/1)], "\n")
  end

  defp format_entry(%{id: id, reasons: reasons} = entry) do
    reason_str = reasons |> Enum.map(&Atom.to_string/1) |> Enum.join(", ")
    "  #{id} [#{reason_str}] — #{truncate(entry[:claim])}"
  end

  defp truncate(nil), do: "(no claim)"

  defp truncate(str) when is_binary(str) do
    if String.length(str) > @claim_truncate do
      String.slice(str, 0, @claim_truncate) <> "..."
    else
      str
    end
  end

  # --- json output (optional) ---

  defp to_json(grouped) do
    %{
      contract_level: Enum.map(grouped.contract_level, &entry_to_json/1),
      schema_conflicts: Enum.map(grouped.schema_conflicts, &entry_to_json/1),
      supportive: Enum.map(grouped.supportive, &entry_to_json/1),
      neutral: Enum.map(grouped.neutral, &entry_to_json/1)
    }
  end

  defp entry_to_json(entry) do
    base = %{
      id: entry.id,
      reasons: Enum.map(entry.reasons, &Atom.to_string/1),
      claim: entry[:claim]
    }

    case entry[:priority] do
      nil -> base
      priority -> Map.put(base, :priority, Atom.to_string(priority))
    end
  end
end
