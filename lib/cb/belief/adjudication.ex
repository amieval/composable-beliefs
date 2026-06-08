defmodule CB.Belief.Adjudication do
  @moduledoc """
  Apply the structural writes that follow a human-adjudicated belief
  conflict.

  A preflight step captures an adjudication record - `proposed`,
  `conflicting_id`, `outcome`, `reasoning`, `session_ref` - whenever a
  proposal collides with an existing belief. `apply/2` consumes that
  record and performs the writes the outcome mandates:

  - `accept_supersede` - new belief is written, conflicting belief's
    status transitions to `superseded` with `superseded_by` pointing at
    the new id. The transition is the only edit the status lifecycle
    contract permits on the conflicting node.
  - `reject_dep_tie` - new belief is written with the conflicting id
    added to `deps` and an evidence entry recording the rejection.
    Conflicting belief is untouched. Reshaping the claim to constrain
    on the conflicting belief is the author's job and happens before
    this function runs; this unit does not rewrite claims.
  - `defer` - no proposed belief is written. Instead, a deferral
    primitive is authored with `tag:adjudication:deferred`, `deps` on
    the conflicting belief, and the proposed content folded into its
    claim / evidence.

  ## Atomicity

  Both beliefs involved in a supersede live in the same JSON file, so
  the atomicity guarantee reduces to a single atomic write of the full
  list via `CB.Belief.Store.write/2`, which uses `CB.JSON`'s tmp-file +
  rename pattern. Either both the status flip and the new belief land,
  or neither does.

  ## Race detection

  Before writing, `apply/2` re-reads the DAG and verifies the
  conflicting belief's status is still `active`. If it has moved to a
  terminal state between the captured adjudication and this call, we
  refuse with `{:error, :conflicting_already_terminal}` rather than
  compound the inconsistency.

  ## Return

  `{:ok, summary}` where `summary` is a map describing the new id
  assigned, the outcome applied, any supersession linkage, and the
  path written. `{:error, reason}` on validation or I/O failure.
  """

  alias CB.Belief
  alias CB.Belief.Store
  alias CB.Config
  alias CB.JSON

  @outcomes ~w(accept_supersede reject_dep_tie defer)
  @required_keys ~w(proposed conflicting_id outcome reasoning session_ref)

  @type outcome :: String.t()
  @type input :: map()
  @type summary :: %{
          new_id: String.t(),
          outcome: outcome(),
          conflicting_id: String.t(),
          superseded_id: String.t() | nil,
          path: String.t()
        }

  @doc """
  Apply an adjudication outcome to the DAG.

  `input` is the captured adjudication record. `opts` supports:

  - `:beliefs_path` - override the target file path (tests)
  - `:today` - override the evidence date (tests)
  """
  @spec apply(input(), keyword()) :: {:ok, summary()} | {:error, term()}
  def apply(input, opts \\ []) when is_map(input) do
    path = Keyword.get(opts, :beliefs_path, Config.beliefs_path())
    today = Keyword.get(opts, :today, Date.to_iso8601(CB.today()))

    with {:ok, record} <- normalize(input),
         {:ok, existing} <- read(path),
         {:ok, conflicting} <- find_conflicting(record.conflicting_id, existing),
         :ok <- ensure_active(conflicting),
         {:ok, updated, summary} <- apply_outcome(record, conflicting, existing, today),
         {:ok, _} <- Store.write(updated, path) do
      {:ok, Map.put(summary, :path, path)}
    end
  end

  # --- normalization ---

  defp normalize(input) do
    stringed = stringify_outer(input)

    with :ok <- require_keys(stringed),
         :ok <- check_outcome(stringed["outcome"]),
         :ok <- check_nonempty(stringed, "conflicting_id"),
         :ok <- check_nonempty(stringed, "reasoning"),
         :ok <- check_nonempty(stringed, "session_ref"),
         {:ok, proposed_map} <- check_proposed(stringed["proposed"]) do
      {:ok,
       %{
         proposed_map: proposed_map,
         proposed: Belief.from_map(proposed_map),
         conflicting_id: stringed["conflicting_id"],
         outcome: stringed["outcome"],
         reasoning: stringed["reasoning"],
         session_ref: stringed["session_ref"]
       }}
    end
  end

  defp stringify_outer(m) do
    Map.new(m, fn {k, v} -> {to_string(k), v} end)
  end

  defp require_keys(m) do
    missing = Enum.reject(@required_keys, &Map.has_key?(m, &1))
    if missing == [], do: :ok, else: {:error, {:missing_fields, missing}}
  end

  defp check_outcome(outcome) when outcome in @outcomes, do: :ok
  defp check_outcome(other), do: {:error, {:bad_outcome, other}}

  defp check_nonempty(m, key) do
    case Map.get(m, key) do
      v when is_binary(v) and v != "" -> :ok
      _ -> {:error, {:invalid_field, key}}
    end
  end

  defp check_proposed(m) when is_map(m), do: {:ok, m}
  defp check_proposed(_), do: {:error, {:invalid_field, "proposed"}}

  # --- lookup + guards ---

  defp read(path) do
    if File.exists?(path) do
      case JSON.read(path) do
        {:ok, data} when is_list(data) -> {:ok, Enum.map(data, &Belief.from_map/1)}
        {:ok, _} -> {:error, :beliefs_not_a_list}
        {:error, reason} -> {:error, {:read_failed, reason}}
      end
    else
      {:error, :beliefs_missing}
    end
  end

  defp find_conflicting(id, existing) do
    case Enum.find(existing, &(&1.id == id)) do
      nil -> {:error, {:conflicting_not_found, id}}
      belief -> {:ok, belief}
    end
  end

  defp ensure_active(%Belief{status: status}) when status in [nil, "active"], do: :ok
  defp ensure_active(%Belief{}), do: {:error, :conflicting_already_terminal}

  # --- outcome application ---

  defp apply_outcome(%{outcome: "accept_supersede"} = r, conflicting, existing, today) do
    new_id = next_id(existing, r.proposed)

    evidence =
      evidence_entry(
        today,
        "Accepted via human adjudication against #{r.conflicting_id}. Reasoning: #{r.reasoning}",
        "adjudication:human:#{r.session_ref}"
      )

    new_belief = build_new_belief(r.proposed_map, new_id, evidence, [], today)

    superseded =
      conflicting
      |> put_field(:status, "superseded")
      |> put_field(:superseded_by, new_id)

    patched =
      Enum.map(existing, fn b -> if b.id == conflicting.id, do: superseded, else: b end)

    updated = patched ++ [new_belief]

    summary = %{
      new_id: new_id,
      outcome: "accept_supersede",
      conflicting_id: r.conflicting_id,
      superseded_id: r.conflicting_id
    }

    {:ok, updated, summary}
  end

  defp apply_outcome(%{outcome: "reject_dep_tie"} = r, _conflicting, existing, today) do
    new_id = next_id(existing, r.proposed)

    evidence =
      evidence_entry(
        today,
        "Rejected as dep-tie against #{r.conflicting_id}. Reasoning: #{r.reasoning}",
        "adjudication:human:#{r.session_ref}"
      )

    new_belief = build_new_belief(r.proposed_map, new_id, evidence, [r.conflicting_id], today)

    summary = %{
      new_id: new_id,
      outcome: "reject_dep_tie",
      conflicting_id: r.conflicting_id,
      superseded_id: nil
    }

    {:ok, existing ++ [new_belief], summary}
  end

  defp apply_outcome(%{outcome: "defer"} = r, _conflicting, existing, today) do
    new_id = next_a_id(existing)
    deferral = build_deferral_primitive(new_id, r, today)

    summary = %{
      new_id: new_id,
      outcome: "defer",
      conflicting_id: r.conflicting_id,
      superseded_id: nil
    }

    {:ok, existing ++ [deferral], summary}
  end

  # --- construction ---

  defp build_new_belief(proposed_map, new_id, evidence_entry, extra_deps, today) do
    existing_evidence = proposed_map["evidence"] || []
    existing_deps = proposed_map["deps"] || []

    deps = Enum.uniq(existing_deps ++ extra_deps)

    proposed_map
    |> Map.put("id", new_id)
    |> Map.put("evidence", existing_evidence ++ [evidence_entry])
    |> Map.put("deps", deps)
    |> Map.put_new("status", "active")
    |> Map.put("created", today)
    |> Belief.from_map()
  end

  defp build_deferral_primitive(new_id, record, today) do
    proposed = record.proposed
    conflicting_id = record.conflicting_id
    reasoning = record.reasoning
    session_ref = record.session_ref

    proposed_claim = proposed.claim || "(no claim captured on proposed belief)"

    claim =
      "Adjudication deferred against #{conflicting_id}. Proposed claim: #{proposed_claim} " <>
        "Deferral reasoning: #{reasoning}"

    tags = Enum.uniq(["adjudication:deferred" | proposed.tags || []])

    evidence =
      evidence_entry(
        today,
        "Deferred adjudication against #{conflicting_id}. Reasoning: #{reasoning}",
        "adjudication:deferred:#{session_ref}"
      )

    # No top-level artifact: the artifact-scheme enum does not declare an
    # "adjudication:" scheme. Adjudication provenance lives in the
    # evidence entry's artifact field + the "adjudication:deferred" tag,
    # which is sufficient.
    Belief.from_map(%{
      "id" => new_id,
      "type" => "primitive",
      "kind" => "observation",
      "domain" => proposed.domain,
      "tags" => tags,
      "claim" => claim,
      "evidence" => [evidence],
      "subjects" => proposed.subjects || [],
      "deps" => [conflicting_id],
      "status" => "active",
      "created" => today
    })
  end

  defp evidence_entry(date, detail, artifact) do
    %{"date" => date, "detail" => detail, "artifact" => artifact}
  end

  defp put_field(%Belief{_keys: keys} = b, field, value) do
    string_key = Atom.to_string(field)
    new_keys = MapSet.put(keys || MapSet.new(), string_key)
    Map.put(%{b | _keys: new_keys}, field, value)
  end

  # --- id generation ---

  # Dispatch to a- or c-prefix based on whether the proposed belief is
  # contract-grade (has non-empty rules or invariants). c-prefix is
  # reserved for contracts; everything else is a-prefix.
  defp next_id(existing, %Belief{} = proposed) do
    if Belief.contract?(proposed) do
      next_c_id(existing)
    else
      next_a_id(existing)
    end
  end

  defp next_a_id(existing), do: next_prefixed_id(existing, "a")
  defp next_c_id(existing), do: next_prefixed_id(existing, "c")

  # Local-number generator. Ids may be namespaced (`cb:a381`) or bare
  # (`a381`); the prefix + serial number live on the LOCAL id, so the scan
  # strips the namespace before reading the serial. Local serials are
  # globally unique across the whole graph, so the max is taken over all
  # ids regardless of namespace.
  #
  # NOTE (Stage 1 restructure): the returned id is still a BARE local id
  # (`a###` / `c###`). Which namespace a newly authored belief belongs to is
  # a collection-assignment decision that the multi-repo restructure defers
  # to a later stage; this generator deliberately does not invent one.
  defp next_prefixed_id(existing, prefix) do
    pattern = ~r/^#{prefix}(\d+)$/

    max =
      existing
      |> Enum.map(& &1.id)
      |> Enum.map(&parse_id_num(&1, pattern))
      |> Enum.reject(&is_nil/1)
      |> Enum.max(fn -> 0 end)

    format_id(prefix, max + 1)
  end

  defp parse_id_num(nil, _), do: nil

  defp parse_id_num(id, pattern) do
    local = id |> String.split(":") |> List.last()

    case Regex.run(pattern, local) do
      [_, num] -> String.to_integer(num)
      _ -> nil
    end
  end

  defp format_id(prefix, n) when n < 1000 do
    prefix <> String.pad_leading(Integer.to_string(n), 3, "0")
  end

  defp format_id(prefix, n), do: "#{prefix}#{n}"
end
