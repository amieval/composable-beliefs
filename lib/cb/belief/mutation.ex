defmodule CB.Belief.Mutation do
  @moduledoc """
  Apply dag-proposal mutations to the in-memory belief list.

  Pure functions only — callers handle disk I/O
  (`CB.Belief.Store.write/2`), notifications, and commits. Per-type
  dispatch returns `{:ok, updated}` or `{:error, reason}` so
  `apply_batch/2` can short-circuit and the caller can roll back
  atomically by discarding the partial result and re-writing the
  pre-batch state.

  A mutation is a plain `map()`, atom-keyed and type-tagged via the
  `:type` field. Per-type required fields are enforced by the proposal
  loader before this module runs; this module trusts that validation and
  dispatches on `:type`.

  ## Context entries

  `type: "context"` is informational — never changes the belief list.
  `apply_one/2` returns `{:ok, beliefs}` unchanged. `apply_batch/2`
  filters context entries before iterating so they never appear in the
  apply pipeline output.

  ## Stub status

  Some per-type clauses ship as dispatch stubs only — any non-context
  type without a clause returns `{:error, {:not_implemented, type}}`.
  """

  alias CB.Belief

  @typedoc """
  Mutation map. Atom-keyed, type-tagged via the `:type` field.
  """
  @type mutation :: map()

  @typedoc """
  Reason on the second tuple element of `{:error, reason}`. `{:not_implemented, type}`
  marks a per-type clause that hasn't landed yet — the type string is included so
  the caller can surface which dispatch is missing without re-deriving it.
  """
  @type error_reason :: {:not_implemented, String.t()} | term()

  @doc """
  Apply a single mutation against the in-memory belief list.

  Returns `{:ok, updated_beliefs}` on success; `{:error, reason}` on
  failure. The `context` clause returns the input unchanged so calling
  it directly is a no-op.

  ## Options

  - `:slug` — proposal slug, used as the `session:<slug>` artifact in
    evidence entries appended to each mutated belief. Required by every
    per-type clause that mutates the belief list; the `context` clause
    ignores it.
  - `:date` — ISO date string for the evidence entry. Defaults to
    today (`Date.utc_today/0 |> Date.to_iso8601/1`). Surfaced as an
    option mainly to keep tests deterministic.
  """
  @spec apply_one(mutation(), [Belief.t()], keyword()) ::
          {:ok, [Belief.t()]} | {:error, error_reason()}
  def apply_one(mutation, beliefs, opts \\ [])

  def apply_one(%{type: "context"}, beliefs, _opts), do: {:ok, beliefs}

  def apply_one(%{type: "reclassify-kind"} = m, beliefs, opts) do
    with_belief(beliefs, m.belief_id, fn belief ->
      before_kind = get_in(m.before, ["kind"])
      after_kind = get_in(m.after, ["kind"])

      belief
      |> put_field(:kind, after_kind)
      |> append_evidence(
        evidence_entry("kind:#{before_kind} → kind:#{after_kind} via dag-proposal #{m.id}", opts)
      )
    end)
  end

  def apply_one(%{type: "set-name"} = m, beliefs, opts) do
    with_belief(beliefs, m.belief_id, fn belief ->
      new_name = get_in(m.after, ["name"])

      belief
      |> put_field(:name, new_name)
      |> append_evidence(
        evidence_entry(~s|name set to "#{new_name}" via dag-proposal #{m.id}|, opts)
      )
    end)
  end

  def apply_one(%{type: "rename-name"} = m, beliefs, opts) do
    with_belief(beliefs, m.belief_id, fn belief ->
      old_name = get_in(m.before, ["name"])
      new_name = get_in(m.after, ["name"])

      belief
      |> put_field(:name, new_name)
      |> append_evidence(
        evidence_entry(~s|name "#{old_name}" → "#{new_name}" via dag-proposal #{m.id}|, opts)
      )
    end)
  end

  def apply_one(%{type: "add-dep"} = m, beliefs, opts) do
    with_belief(beliefs, m.belief_id, fn belief ->
      new_deps = get_in(m.after, ["deps"]) || []

      belief
      |> put_field(:deps, new_deps)
      |> append_evidence(
        evidence_entry("deps + #{m.dep} via dag-proposal #{m.id}", opts)
      )
    end)
  end

  def apply_one(%{type: "drop-dep"} = m, beliefs, opts) do
    with_belief(beliefs, m.belief_id, fn belief ->
      new_deps = get_in(m.after, ["deps"]) || []

      belief
      |> put_field(:deps, new_deps)
      |> append_evidence(
        evidence_entry("deps − #{m.dep} via dag-proposal #{m.id}", opts)
      )
    end)
  end

  def apply_one(%{type: "supersede"} = m, beliefs, opts) do
    with_belief(beliefs, m.belief_id, fn belief ->
      belief
      |> put_field(:status, "superseded")
      |> put_field(:superseded_by, m.successor)
      |> append_evidence(
        evidence_entry("superseded by #{m.successor} via dag-proposal #{m.id}", opts)
      )
    end)
  end

  def apply_one(%{type: "retract"} = m, beliefs, opts) do
    with_belief(beliefs, m.belief_id, fn belief ->
      retracted_on = get_in(m.after, ["retracted_on"])
      retracted_reason = get_in(m.after, ["retracted_reason"])

      belief
      |> put_field(:status, "retracted")
      |> put_field(:retracted_on, retracted_on)
      |> put_field(:retracted_reason, retracted_reason)
      |> append_evidence(
        evidence_entry("retracted on #{retracted_on} via dag-proposal #{m.id}", opts)
      )
    end)
  end

  def apply_one(%{type: "new-belief"} = m, beliefs, opts) do
    if Enum.any?(beliefs, &(&1.id == m.belief_id)) do
      {:error, {:belief_id_conflict, m.belief_id}}
    else
      new_belief =
        m.after
        |> Belief.from_map()
        |> append_evidence(evidence_entry("created via dag-proposal #{m.id}", opts))

      {:ok, beliefs ++ [new_belief]}
    end
  end

  def apply_one(%{type: "drop-field"} = m, beliefs, opts) do
    with_belief(beliefs, m.belief_id, fn belief ->
      atom_key = String.to_existing_atom(m.field)

      belief
      |> Map.put(atom_key, nil)
      |> remove_key(atom_key)
      |> append_evidence(
        evidence_entry("#{m.field} dropped via dag-proposal #{m.id}", opts)
      )
    end)
  end

  def apply_one(%{type: type}, _beliefs, _opts), do: {:error, {:not_implemented, type}}

  @doc """
  Apply a batch of mutations sequentially.

  Filters `type: "context"` before iterating. Folds `apply_one/3` over
  the remainder, short-circuiting on the first error and returning
  `{:error, {mutation_id, reason}}` so the caller can pinpoint which
  mutation failed without scanning the batch.

  On error, the caller discards the partial result and re-writes the
  pre-batch state to disk — `Belief.Store.write/2`'s atomic tmp+rename
  ensures no half-applied state lands.

  Takes the same `opts` as `apply_one/3`; they're threaded through to
  every per-type clause.
  """
  @spec apply_batch([mutation()], [Belief.t()], keyword()) ::
          {:ok, [Belief.t()]} | {:error, {String.t(), error_reason()}}
  def apply_batch(mutations, beliefs, opts \\ []) do
    mutations
    |> Enum.reject(&(&1.type == "context"))
    |> Enum.reduce_while({:ok, beliefs}, fn mutation, {:ok, acc} ->
      case apply_one(mutation, acc, opts) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, reason} -> {:halt, {:error, {mutation.id, reason}}}
      end
    end)
  end

  @doc """
  Render a one-line, commit-message-friendly summary of a mutation.

  Used by the apply-approved pipeline to build the per-batch commit
  message body — one bullet per mutation that lands. Compact and
  type-specific so a glance at `git log` tells the reader what each
  mutation did.
  """
  @spec summary(mutation()) :: String.t()
  def summary(%{type: "reclassify-kind"} = m) do
    before = get_in(m.before, ["kind"])
    after_ = get_in(m.after, ["kind"])
    "#{m.id} (reclassify-kind) #{m.belief_id}: #{before} → #{after_}"
  end

  def summary(%{type: "set-name"} = m) do
    new_name = get_in(m.after, ["name"])
    ~s|#{m.id} (set-name) #{m.belief_id}: <null> → "#{new_name}"|
  end

  def summary(%{type: "rename-name"} = m) do
    old = get_in(m.before, ["name"])
    new = get_in(m.after, ["name"])
    ~s|#{m.id} (rename-name) #{m.belief_id}: "#{old}" → "#{new}"|
  end

  def summary(%{type: "add-dep"} = m),
    do: "#{m.id} (add-dep) #{m.belief_id}: + #{m.dep}"

  def summary(%{type: "drop-dep"} = m),
    do: "#{m.id} (drop-dep) #{m.belief_id}: − #{m.dep}"

  def summary(%{type: "supersede"} = m),
    do: "#{m.id} (supersede) #{m.belief_id}: → #{m.successor}"

  def summary(%{type: "retract"} = m) do
    reason = get_in(m.after, ["retracted_reason"]) || "—"
    "#{m.id} (retract) #{m.belief_id}: #{reason}"
  end

  def summary(%{type: "new-belief"} = m) do
    type_ = get_in(m.after, ["type"]) || "?"
    kind = get_in(m.after, ["kind"]) || "?"
    "#{m.id} (new-belief) #{m.belief_id}: new #{type_} #{kind}"
  end

  def summary(%{type: "drop-field"} = m),
    do: "#{m.id} (drop-field) #{m.belief_id}: drop #{m.field}"

  def summary(%{type: "context"} = m),
    do: "#{m.id} (context) #{m.belief_id}: noted"

  # --- Private helpers ---

  # Locate a belief by id and run `fun.(belief)` to produce the updated
  # form, then splice it back into the list at the same index. Centralizes
  # the find/replace dance so per-type clauses focus on the transformation.
  defp with_belief(beliefs, belief_id, fun) do
    case Enum.find_index(beliefs, &(&1.id == belief_id)) do
      nil ->
        {:error, {:belief_not_found, belief_id}}

      idx ->
        updated = fun.(Enum.at(beliefs, idx))
        {:ok, List.replace_at(beliefs, idx, updated)}
    end
  end

  # Set a struct field and mark its key present so `Belief.to_map/1`
  # emits it even if it wasn't in the source JSON.
  defp put_field(%Belief{} = belief, atom_key, value) do
    belief
    |> Map.put(atom_key, value)
    |> ensure_key(atom_key)
  end

  defp ensure_key(%Belief{_keys: keys} = belief, atom_key) do
    string_key = Atom.to_string(atom_key)
    %Belief{belief | _keys: MapSet.put(keys || MapSet.new(), string_key)}
  end

  defp remove_key(%Belief{_keys: keys} = belief, atom_key) do
    string_key = Atom.to_string(atom_key)
    %Belief{belief | _keys: MapSet.delete(keys || MapSet.new(), string_key)}
  end

  # Append an evidence entry, creating the list if absent and marking
  # :evidence present so it serializes back out.
  defp append_evidence(%Belief{} = belief, entry) do
    existing = belief.evidence || []

    %Belief{belief | evidence: existing ++ [entry]}
    |> ensure_key(:evidence)
  end

  # Construct an evidence entry. Requires :slug; :date defaults to today.
  defp evidence_entry(detail, opts) do
    %{
      "date" => resolve_date(opts),
      "detail" => detail,
      "artifact" => "session:#{resolve_slug!(opts)}"
    }
  end

  defp resolve_date(opts) do
    case Keyword.get(opts, :date) do
      nil -> Date.utc_today() |> Date.to_iso8601()
      iso when is_binary(iso) -> iso
    end
  end

  defp resolve_slug!(opts) do
    case Keyword.fetch(opts, :slug) do
      {:ok, slug} when is_binary(slug) and slug != "" ->
        slug

      _ ->
        raise ArgumentError,
              "CB.Belief.Mutation requires :slug in opts " <>
                "(used as `session:<slug>` artifact on evidence entries)"
    end
  end
end
