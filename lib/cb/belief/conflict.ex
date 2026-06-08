defmodule CB.Belief.Conflict do
  @moduledoc """
  Preflight conflict detection for proposed beliefs.

  Before a belief is written to the DAG, `preflight/1` searches for
  existing nodes that overlap on subject, tag, or claim content, and
  classifies each overlap as supportive, neutral, or conflicting. The
  output feeds an adjudication path - this module performs no writes and
  has no side effects.

  Authoring-time preflight examines all active beliefs so that primitives
  and compounds can also surface potential contradictions before the
  write lands.

  ## Match axes

  For each active belief in the DAG, three axes of overlap are checked:

  - **Subject overlap** - any shared `subjects[].ref`
  - **Tag overlap** - any shared entry in `tags`
  - **Claim overlap** - same non-nil `domain` plus token intersection in
    `claim`. Tokens are lowercased alphanumerics of length >= 4 with a
    small stopword list stripped; a match requires the intersection to
    cover at least `@claim_overlap_threshold` of the smaller token set

  ## Classification

  - **Conflicting** when the matched belief is contract-grade
    (`CB.Belief.contract?/1` or c-prefix ID) or carries the `dag-schema`
    tag. v1 errs on the side of flagging schema-adjacent matches and
    lets the adjudication path decide. Contract-grade matches also
    receive a `priority: :contract_level` marker.
  - **Supportive** when the match shares a subject ref and the matched
    belief is not schema/contract. Subject-level agreement is the
    coarsest "speaks to the same thing" signal.
  - **Neutral** when overlap exists but none of the above apply (e.g.
    tag-only match on a non-schema tag).

  Sentiment-inversion detection (whether the proposal negates or extends
  an enum a contract closes) is deferred. v1 relies on contract-grade
  matches raising adjudication regardless of content direction.

  ## Entry shape

      %{id: "c029", reasons: [:tag_overlap], priority: :contract_level}

  `priority` is only present when the match is contract-grade.

  ## Example

      iex> proposed = %CB.Belief{type: "primitive", domain: "system",
      ...>   tags: ["dag-schema"], claim: "A fifth status value..."}
      iex> CB.Belief.Conflict.preflight(proposed)
      %{supportive: [...], neutral: [...], conflicting: [%{id: "c029", ...}]}
  """

  alias CB.Belief
  alias CB.Belief.Store

  @claim_overlap_threshold 0.25
  @min_token_length 4

  @stopwords MapSet.new(~w(
    about above after again against along also among because been before
    being below between both came come could does doing down during each
    every from have having here into itself just like made make many more
    most much must only other over same some such than that them then
    there these they this those through under until very what when where
    which while with within without would your yours
  ))

  @type reason :: :subject_overlap | :tag_overlap | :claim_overlap
  @type entry :: %{required(:id) => String.t(), required(:reasons) => [reason()], optional(:priority) => :contract_level}
  @type result :: %{supportive: [entry()], neutral: [entry()], conflicting: [entry()]}

  @doc """
  Run preflight against the live DAG.

  Reads the belief graph via `CB.Belief.Store`. Returns a `result` map.
  Empty DAG returns all empty lists.

  For tests and callers that already have a belief list in hand,
  pass it explicitly via `preflight/2` - this avoids disk reads and
  lets the function stay deterministic against a fixture.
  """
  @spec preflight(Belief.t()) :: result()
  def preflight(%Belief{} = proposed) do
    case Store.read() do
      {:ok, existing} -> preflight(proposed, existing)
      {:error, _} -> %{supportive: [], neutral: [], conflicting: []}
    end
  end

  @doc """
  Run preflight against an explicit list of existing beliefs.

  Pure: no disk reads, no side effects. Used by tests and by callers
  that hold the DAG in memory already.
  """
  @spec preflight(Belief.t(), [Belief.t()]) :: result()
  def preflight(%Belief{} = proposed, existing) when is_list(existing) do
    proposed_tokens = tokenize(proposed.claim)

    matches =
      for candidate <- existing,
          not skip?(candidate, proposed),
          reasons = match_reasons(proposed, candidate, proposed_tokens),
          reasons != [],
          do: {candidate, reasons}

    {supp, neut, conf} =
      Enum.reduce(matches, {[], [], []}, fn {candidate, reasons}, {s, n, c} ->
        entry = build_entry(candidate, reasons)

        case classify(candidate, reasons) do
          :supportive -> {[entry | s], n, c}
          :neutral -> {s, [entry | n], c}
          :conflicting -> {s, n, [entry | c]}
        end
      end)

    %{
      supportive: Enum.reverse(supp),
      neutral: Enum.reverse(neut),
      conflicting: Enum.reverse(conf)
    }
  end

  # --- internals ---

  defp skip?(%Belief{id: id}, %Belief{id: proposed_id})
       when is_binary(id) and is_binary(proposed_id) and id == proposed_id,
       do: true

  defp skip?(%Belief{status: status}, _)
       when status in ["superseded", "retracted", "retired"],
       do: true

  defp skip?(_, _), do: false

  defp match_reasons(proposed, candidate, proposed_tokens) do
    reasons = []

    reasons =
      if subject_overlap?(proposed, candidate), do: [:subject_overlap | reasons], else: reasons

    reasons =
      if tag_overlap?(proposed, candidate), do: [:tag_overlap | reasons], else: reasons

    reasons =
      if claim_overlap?(proposed, candidate, proposed_tokens),
        do: [:claim_overlap | reasons],
        else: reasons

    Enum.reverse(reasons)
  end

  defp subject_overlap?(a, b) do
    a_refs = subject_refs(a)
    b_refs = subject_refs(b)
    a_refs != [] and b_refs != [] and Enum.any?(a_refs, &(&1 in b_refs))
  end

  defp subject_refs(%Belief{subjects: subjects}) do
    (subjects || [])
    |> Enum.map(&Map.get(&1, "ref"))
    |> Enum.reject(&is_nil/1)
  end

  defp tag_overlap?(%Belief{tags: a_tags}, %Belief{tags: b_tags}) do
    a_set = MapSet.new(a_tags || [])
    b_set = MapSet.new(b_tags || [])
    not MapSet.disjoint?(a_set, b_set)
  end

  defp claim_overlap?(%Belief{domain: pd}, %Belief{domain: cd}, _) when is_nil(pd) or pd != cd,
    do: false

  defp claim_overlap?(_proposed, candidate, proposed_tokens) do
    candidate_tokens = tokenize(candidate.claim)

    case {proposed_tokens, candidate_tokens} do
      {[], _} ->
        false

      {_, []} ->
        false

      {pt, ct} ->
        p_set = MapSet.new(pt)
        c_set = MapSet.new(ct)
        inter = MapSet.intersection(p_set, c_set) |> MapSet.size()
        denom = min(MapSet.size(p_set), MapSet.size(c_set))
        denom > 0 and inter / denom >= @claim_overlap_threshold
    end
  end

  defp tokenize(nil), do: []

  defp tokenize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.split(~r/[^a-z0-9]+/u, trim: true)
    |> Enum.filter(&(String.length(&1) >= @min_token_length))
    |> Enum.reject(&MapSet.member?(@stopwords, &1))
  end

  defp classify(candidate, reasons) do
    cond do
      contract_level?(candidate) -> :conflicting
      schema_tagged?(candidate) -> :conflicting
      :subject_overlap in reasons -> :supportive
      true -> :neutral
    end
  end

  defp contract_level?(%Belief{id: id} = b) do
    (is_binary(id) and String.starts_with?(local_id(id), "c")) or Belief.contract?(b)
  end

  # Local id is the segment after the last namespace separator. The c-prefix
  # convention lives on the local id (`cb:c038` -> `c038`), so the heuristic
  # must look past the namespace.
  defp local_id(id) when is_binary(id), do: id |> String.split(":") |> List.last()
  defp local_id(id), do: id

  defp schema_tagged?(%Belief{tags: tags}), do: "dag-schema" in (tags || [])

  defp build_entry(candidate, reasons) do
    base = %{id: candidate.id, reasons: reasons}

    if contract_level?(candidate) do
      Map.put(base, :priority, :contract_level)
    else
      base
    end
  end
end
