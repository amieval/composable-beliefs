defmodule CB.Eval.Predicates do
  @moduledoc """
  Collection-scoped predicate bodies for methodology contracts.

  Per `cb:c047` the DAG stores only predicate *names* - an `implies`
  rule `{"when": {"verify": "collection"}, "requires": "name?"}` on a
  contract-grade belief - and this module implements them. Where
  codepath predicates (`CB.Codepath.Predicates`) are zero-arity and
  read app state dynamically, collection predicates take the **loaded
  collection union** as an argument and are pure traversal: they run on
  the deterministic side of the boundary, as a static pass inside
  `mix cb.verify.collection` (`CB.Method.Checks`). The two worlds stay
  visibly distinct - separate modules, separate runners - and share only
  the resolve gate (`CB.PredicateGate`).

  ## Signature and verdict convention

  Every predicate is `name?(beliefs, params)` where `beliefs` is the
  loaded union (`[CB.Belief.t()]`) and `params` is the routing rule's
  optional `"params"` map (default `%{}`) - untrusted shape, validated
  before use, never converted to atoms. A predicate returns `true` when
  the invariant holds, or `{false, detail}` where the detail names the
  offending belief ids - the failure message is the work order. Plain
  `false`, a non-boolean, or a raise normalize to fail-with-detail in
  `invoke/4`; a check run never crashes the verifier.

  The `cb:c050` discipline carries over verbatim: names end in `?` or
  `_check`, predicates observe and never mutate, and `resolve/2`
  refuses anything that is not an exported arity-2 predicate.

  ## The v1 library

  Each predicate implements one `method:` methodology contract:

  | predicate | contract |
  |---|---|
  | `verdicts_corroborated?` | m-corroboration |
  | `observations_cite_runlogs?` | m-provenance |
  | `observation_subjects_complete?` | m-subjects |
  | `min_runs_met?` (params: `min`) | m-runs |
  | `llm_judges_validated?` | m-judge-validation |
  | `corrections_are_supersessions?` | m-correction |
  """

  alias CB.Belief

  @runlog_schemes ~w(document https)
  @core_subject_types ~w(eval run model model_version ruler)

  @doc """
  Resolve a routed predicate name to an arity-2 function.

  Same gate as the codepath world (`CB.PredicateGate`), with the arity
  fixed at 2. Returns `{:ok, fun}`, `{:error, :bad_name}`, or
  `{:error, :unknown_predicate}`.
  """
  @spec resolve(module(), String.t()) ::
          {:ok, ([Belief.t()], map() -> term())} | {:error, atom()}
  def resolve(module \\ __MODULE__, name) when is_binary(name) do
    with {:ok, fun_name} <- CB.PredicateGate.resolve(module, name, 2) do
      {:ok, fn beliefs, params -> apply(module, fun_name, [beliefs, params]) end}
    end
  end

  @doc """
  Resolve and invoke a routed predicate, normalized to a verdict.

  Returns `{"pass", nil}` only when the predicate returns `true`.
  `{false, detail}` fails with the predicate's own detail; plain
  `false`, a non-boolean, a raise, an invariant-violating name, or an
  unknown predicate all fail with a generated detail - a check run
  never crashes the caller.
  """
  @spec invoke(module(), String.t() | nil, [Belief.t()], map()) ::
          {String.t(), String.t() | nil}
  def invoke(module \\ __MODULE__, name, beliefs, params)

  def invoke(_module, nil, _beliefs, _params), do: {"fail", "no predicate named"}

  def invoke(module, name, beliefs, params) do
    case resolve(module, name) do
      {:error, :bad_name} ->
        {"fail", "name violates the inspection-only invariant (must end in ? or _check)"}

      {:error, :unknown_predicate} ->
        {"fail", "no exported arity-2 predicate #{inspect(name)}"}

      {:ok, fun} ->
        try do
          case fun.(beliefs, params) do
            true -> {"pass", nil}
            {false, detail} when is_binary(detail) -> {"fail", detail}
            false -> {"fail", "predicate returned false"}
            other -> {"fail", "predicate returned non-boolean: #{inspect(other)}"}
          end
        rescue
          e -> {"fail", "predicate raised: #{Exception.message(e)}"}
        end
    end
  end

  # --- the v1 predicate library ---

  @doc """
  m-corroboration: every active `kind:verdict` inference depends,
  directly or transitively, on at least one active compound tagged
  `cross-ruler-agreement`, or carries the tag `single-ruler` explicitly.
  """
  def verdicts_corroborated?(beliefs, _params) do
    index = index(beliefs)

    violations =
      for v <- verdicts(beliefs),
          "single-ruler" not in (v.tags || []),
          not Enum.any?(closure(v, index), &agreement_compound?/1) do
        v.id
      end

    pass_or_detail(
      violations,
      "verdicts with neither a cross-ruler-agreement compound in their dep closure nor the single-ruler tag"
    )
  end

  @doc """
  m-provenance: every active `kind:observation` primitive carries an
  `eval:` artifact and at least one evidence entry whose artifact is a
  raw-log pointer (`document:` or `https:`).
  """
  def observations_cite_runlogs?(beliefs, _params) do
    violations =
      for o <- observation_primitives(beliefs),
          scheme(o.artifact) != "eval" or not cites_runlog?(o) do
        o.id
      end

    pass_or_detail(
      violations,
      "observations missing an eval: artifact or a document:/https: raw-log evidence artifact"
    )
  end

  @doc """
  m-subjects: every active `kind:observation` primitive carries the
  six-subject convention (`eval`, `run`, `case`, `model`,
  `model_version`, `ruler`); an observation tagged `aggregate` may omit
  `case`.
  """
  def observation_subjects_complete?(beliefs, _params) do
    violations =
      for o <- observation_primitives(beliefs),
          missing = missing_subjects(o),
          missing != [] do
        "#{o.id} (missing: #{Enum.join(missing, ", ")})"
      end

    pass_or_detail(violations, "observations missing conventional subjects")
  end

  @doc """
  m-runs: every active `kind:verdict` inference cites at least
  `params["min"]` distinct run subject refs across itself and its
  transitive dep closure. `min` must be a positive integer; there is no
  escape hatch - a result that cannot cite the minimum is authored as
  an observation or guidance, not a verdict.
  """
  def min_runs_met?(beliefs, params) do
    case params do
      %{"min" => min} when is_integer(min) and min > 0 ->
        index = index(beliefs)

        violations =
          for v <- verdicts(beliefs),
              runs = distinct_runs(v, index),
              length(runs) < min do
            "#{v.id} (#{length(runs)} run(s): #{Enum.join(runs, ", ")})"
          end

        pass_or_detail(violations, "verdicts citing fewer than #{min} distinct runs")

      _ ->
        {false, "params.min missing or not a positive integer: #{inspect(params)}"}
    end
  end

  @doc """
  m-judge-validation: every active observation whose ruler subject ref
  begins `ruler/llm-judge` is joined by an active belief tagged
  `judge-validation` sharing that ruler subject ref and the
  observation's eval subject ref.
  """
  def llm_judges_validated?(beliefs, _params) do
    validations =
      beliefs
      |> Enum.filter(&(active?(&1) and "judge-validation" in (&1.tags || [])))

    violations =
      for o <- Enum.filter(beliefs, &(active?(&1) and &1.kind == "observation")),
          ruler <- subject_refs(o, "ruler"),
          String.starts_with?(ruler, "ruler/llm-judge"),
          not validated?(ruler, subject_refs(o, "eval"), validations) do
        "#{o.id} (#{ruler})"
      end
      |> Enum.uniq()

    pass_or_detail(
      violations,
      "LLM-judge observations with no judge-validation record for their (ruler, eval) pair"
    )
  end

  @doc """
  m-correction: every active belief tagged `correction` is the
  successor of a superseded belief and carries a dated evidence entry;
  every retracted belief carries the tag `withdrawn` (retraction
  without successor is reserved for full withdrawal).
  """
  def corrections_are_supersessions?(beliefs, _params) do
    successor_of = MapSet.new(beliefs, & &1.superseded_by)

    orphan_corrections =
      for c <- beliefs,
          active?(c) and "correction" in (c.tags || []),
          not MapSet.member?(successor_of, c.id) or not dated_evidence?(c) do
        c.id
      end

    bare_retractions =
      for r <- beliefs,
          r.status == "retracted" and "withdrawn" not in (r.tags || []) do
        r.id
      end

    case {orphan_corrections, bare_retractions} do
      {[], []} ->
        true

      _ ->
        parts =
          [
            detail_part(
              orphan_corrections,
              "correction-tagged beliefs that supersede nothing or lack dated evidence"
            ),
            detail_part(bare_retractions, "retracted beliefs without the withdrawn tag")
          ]
          |> Enum.reject(&is_nil/1)

        {false, Enum.join(parts, "; ")}
    end
  end

  # --- shared traversal helpers ---

  defp index(beliefs), do: Map.new(beliefs, &{&1.id, &1})

  defp active?(b), do: b.status == "active"

  defp verdicts(beliefs) do
    Enum.filter(beliefs, &(active?(&1) and &1.type == "inference" and &1.kind == "verdict"))
  end

  defp observation_primitives(beliefs) do
    Enum.filter(beliefs, &(active?(&1) and &1.type == "primitive" and &1.kind == "observation"))
  end

  defp agreement_compound?(b) do
    active?(b) and b.type == "compound" and "cross-ruler-agreement" in (b.tags || [])
  end

  # Transitive dep closure of a belief (excluding itself), cycle-safe.
  defp closure(belief, index) do
    do_closure(belief.deps || [], index, MapSet.new([belief.id]), [])
  end

  defp do_closure([], _index, _visited, acc), do: acc

  defp do_closure([id | rest], index, visited, acc) do
    if MapSet.member?(visited, id) do
      do_closure(rest, index, visited, acc)
    else
      visited = MapSet.put(visited, id)

      case Map.get(index, id) do
        nil -> do_closure(rest, index, visited, acc)
        b -> do_closure((b.deps || []) ++ rest, index, visited, [b | acc])
      end
    end
  end

  defp scheme(uri) when is_binary(uri) do
    case String.split(uri, ":", parts: 2) do
      [s, _] -> s
      _ -> nil
    end
  end

  defp scheme(_), do: nil

  defp cites_runlog?(belief) do
    Enum.any?(belief.evidence || [], fn e -> scheme(e["artifact"]) in @runlog_schemes end)
  end

  defp dated_evidence?(belief) do
    Enum.any?(belief.evidence || [], fn e -> is_binary(e["date"]) and e["date"] != "" end)
  end

  defp subject_types(belief) do
    (belief.subjects || []) |> Enum.map(& &1["type"]) |> Enum.reject(&is_nil/1)
  end

  defp subject_refs(belief, type) do
    for s <- belief.subjects || [], s["type"] == type, ref = s["ref"], is_binary(ref), do: ref
  end

  defp missing_subjects(observation) do
    required =
      if "aggregate" in (observation.tags || []) do
        @core_subject_types
      else
        @core_subject_types ++ ["case"]
      end

    required -- subject_types(observation)
  end

  defp distinct_runs(verdict, index) do
    [verdict | closure(verdict, index)]
    |> Enum.flat_map(&subject_refs(&1, "run"))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp validated?(ruler_ref, eval_refs, validations) do
    Enum.any?(validations, fn v ->
      ruler_ref in subject_refs(v, "ruler") and
        Enum.any?(eval_refs, &(&1 in subject_refs(v, "eval")))
    end)
  end

  defp pass_or_detail([], _label), do: true
  defp pass_or_detail(violations, label), do: {false, "#{label}: #{Enum.join(violations, "; ")}"}

  defp detail_part([], _label), do: nil
  defp detail_part(ids, label), do: "#{label}: #{Enum.join(ids, ", ")}"
end
