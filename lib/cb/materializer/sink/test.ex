defmodule CB.Materializer.Sink.Test do
  @moduledoc """
  A test run as materialization.

  The materializer's flow is `implication -> action items -> sink ->
  link belief.materialized`; this sink makes a predicate run one more
  destination rather than a new subsystem. Each action item names a
  routed predicate (`"predicate"` key); persisting it means *invoking*
  it (in-process, plan-3 Step A) and returning a ref carrying the
  pass/fail outcome. The caller records the refs onto the belief's
  `materialized` field, binding dated test history to the immutable
  claim; a re-run replaces the prior record (the materialized field is
  the mutable action-history axis, orthogonal to status).

  Inspection-only (cb:c045) is enforced underneath by
  `CB.Codepath.Predicates.resolve/2` - an action item naming anything
  but an exported, invariant-satisfying predicate fails its ref rather
  than executing.
  """

  @behaviour CB.Materializer.Sink

  alias CB.Codepath.Predicates

  @impl true
  def persist(_implication, action_items, opts) do
    module = Keyword.get(opts, :module, Predicates)

    refs =
      Enum.map(action_items, fn item ->
        predicate = item["predicate"]
        {result, detail} = Predicates.invoke(module, predicate)

        %{
          "id" => predicate,
          "action" => item["action"] || "invoke #{predicate}",
          "result" => result
        }
        |> put_detail(detail)
      end)

    {:ok, refs}
  end

  defp put_detail(ref, nil), do: ref
  defp put_detail(ref, detail), do: Map.put(ref, "detail", detail)
end
