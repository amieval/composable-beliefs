defmodule CB.Codepath.Predicates do
  @moduledoc """
  Repo-resident predicate bodies for codepath assertions.

  Per c037 (routing in data, implementation in code) the DAG stores only
  predicate *names* - `implies(When, Requires: "predicate_name")` on a
  contract-grade stop belief - and this module implements them. Per the
  inspection-only contract (`cb:c045`), predicates observe and never
  mutate: names end in `?` or `_check`, take no arguments, and return a
  boolean. `resolve/2` enforces the naming invariant and refuses names
  that do not resolve to an exported zero-arity function, so an
  executable string in the DAG has nothing to grab onto.

  These predicates read whatever collection `CB.Config.beliefs_path/0`
  resolves to (Step A: direct in-process invocation, no runtime channel).
  Predicates needing live application state are plan-3 Step B (Tidewave
  federation) and do not belong here.
  """

  alias CB.Belief
  alias CB.Belief.Formatter
  alias CB.Belief.Store
  alias CB.{Config, JSON}

  @name_invariant ~r/(\?|_check)$/

  @doc """
  Resolve a routed predicate name to a zero-arity function.

  Enforces the inspection-only naming invariant before any lookup, then
  requires the name to be an exported zero-arity function on `module`
  (default: this module). Returns `{:ok, fun}`,
  `{:error, :bad_name}` (invariant violated), or
  `{:error, :unknown_predicate}`.
  """
  @spec resolve(module(), String.t()) :: {:ok, (-> boolean())} | {:error, atom()}
  def resolve(module \\ __MODULE__, name) when is_binary(name) do
    cond do
      not Regex.match?(@name_invariant, name) ->
        {:error, :bad_name}

      not predicate_exported?(module, name) ->
        {:error, :unknown_predicate}

      true ->
        fun_name = String.to_existing_atom(name)
        {:ok, fn -> apply(module, fun_name, []) end}
    end
  end

  defp predicate_exported?(module, name) do
    Code.ensure_loaded?(module) and
      name in Enum.map(module.module_info(:exports), fn {f, a} -> a == 0 && Atom.to_string(f) end)
  end

  @doc """
  Resolve and invoke a routed predicate, normalized to a verdict.

  Returns `{"pass", nil}` only when the predicate returns `true`.
  `false`, a non-boolean, a raise, an invariant-violating name, or an
  unknown predicate all return `{"fail", detail}` - an assertion run
  never crashes the caller. Shared by `CB.Codepath.Assertions` and
  `CB.Materializer.Sink.Test`.
  """
  @spec invoke(module(), String.t() | nil) :: {String.t(), String.t() | nil}
  def invoke(module \\ __MODULE__, name)

  def invoke(_module, nil), do: {"fail", "no predicate named"}

  def invoke(module, name) do
    case resolve(module, name) do
      {:error, :bad_name} ->
        {"fail", "name violates the inspection-only invariant (must end in ? or _check)"}

      {:error, :unknown_predicate} ->
        {"fail", "no exported zero-arity predicate #{inspect(name)}"}

      {:ok, fun} ->
        try do
          case fun.() do
            true -> {"pass", nil}
            false -> {"fail", "predicate returned false"}
            other -> {"fail", "predicate returned non-boolean: #{inspect(other)}"}
          end
        rescue
          e -> {"fail", "predicate raised: #{Exception.message(e)}"}
        end
    end
  end

  # --- the belief-pipeline predicates ---

  @doc "The loaded collection is non-empty - the raw data is really there."
  def belief_count_positive? do
    match?({:ok, [_ | _]}, Store.read())
  end

  @doc """
  Every belief in the loaded collection survives the struct boundary:
  raw map -> `Belief.from_map/1` -> `Belief.to_map/1` -> JSON round-trips
  to the original map (the `_keys` bookkeeping preserves field presence).
  """
  def from_map_roundtrips? do
    case JSON.read(Config.beliefs_path()) do
      {:ok, raw} when is_list(raw) ->
        Enum.all?(raw, fn map ->
          map
          |> Belief.from_map()
          |> Belief.to_map()
          |> Jason.encode!()
          |> Jason.decode!() == map
        end)

      _ ->
        false
    end
  end

  @doc "The single read path hands back `%Belief{}` structs and nothing else."
  def store_reads_structs? do
    case Store.read() do
      {:ok, beliefs} -> beliefs != [] and Enum.all?(beliefs, &match?(%Belief{}, &1))
      _ -> false
    end
  end

  @doc "The render end of the pipeline produces table output for the loaded collection."
  def formatter_renders_table? do
    case Store.read() do
      {:ok, beliefs} ->
        lines = Formatter.table(beliefs, length(beliefs))
        is_list(lines) and lines != []

      _ ->
        false
    end
  end
end
