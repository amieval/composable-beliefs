defmodule CB.Belief.Materializer do
  @moduledoc """
  Materialize a belief implication into action items via a pluggable sink.

  The flow is host-agnostic:

      implication belief -> action items -> sink -> link belief.materialized

  An implication says *what needs to happen*. Materialization turns that
  into concrete action items and hands them to a `CB.Materializer.Sink`,
  which persists them wherever the host wants (a todo file, a ticket
  tracker, a table). The sink returns one ref per persisted item, and
  those refs are recorded back onto the belief's `materialized` field so
  the link from belief to its materialized artifacts is inspectable and
  the belief is not materialized twice.

  The default sink is `CB.Materializer.Sink.JSON`, which appends generic
  todo records to `CB.Config.todos_path/0`. Pass `:sink` in `opts` to
  swap it. Remaining `opts` are threaded to the sink (e.g. `:path`,
  `:today`).
  """

  alias CB.Belief.Store, as: BeliefStore
  alias CB.Materializer.Sink

  @default_sink Sink.JSON

  @doc """
  Materialize a belief implication into action items.

  `spec` is a string-keyed map with:
  - `"belief_id"` - the implication node ID to materialize (aXXX/cXXX)
  - `"action_items"` (or legacy `"todos"`) - a list of action-item maps,
    each with at least an `"action"` key (free text). Any extra keys are
    passed through to the sink untouched.

  `opts`:
  - `:sink` - module implementing `CB.Materializer.Sink` (default
    `CB.Materializer.Sink.JSON`)
  - any other keys are forwarded to the sink's `persist/3`

  Returns `{:ok, %{belief_id: id, entries: refs}}` or `{:error, reason}`.
  """
  def materialize(spec, opts \\ []) do
    belief_id = spec["belief_id"]
    action_items = spec["action_items"] || spec["todos"] || []
    {sink, sink_opts} = Keyword.pop(opts, :sink, @default_sink)

    with :ok <- validate_spec(belief_id, action_items),
         {:ok, node} <- find_node(belief_id),
         :ok <- validate_node(node),
         {:ok, entries} <- run_sink(sink, node, action_items, sink_opts),
         :ok <- update_node(belief_id, entries) do
      {:ok, %{belief_id: belief_id, entries: entries}}
    end
  end

  defp validate_spec(nil, _), do: {:error, :missing_belief_id}
  defp validate_spec(_, []), do: {:error, :no_action_items}
  defp validate_spec(_, _), do: :ok

  defp find_node(id) do
    with {:ok, all} <- BeliefStore.read() do
      case Enum.find(all, &(&1.id == id)) do
        nil -> {:error, {:node_not_found, id}}
        belief -> {:ok, belief}
      end
    end
  end

  defp validate_node(%{type: "implication", materialized: nil}), do: :ok
  defp validate_node(%{type: type}) when type != "implication", do: {:error, {:not_implication, type}}
  defp validate_node(%{materialized: m}) when m != nil, do: {:error, :already_materialized}

  defp run_sink(sink, node, action_items, sink_opts) do
    case sink.persist(node, action_items, sink_opts) do
      {:ok, refs} -> {:ok, refs}
      {:error, reason} -> {:error, {:sink_failed, reason}}
    end
  end

  defp update_node(node_id, entries) do
    today = Date.to_iso8601(CB.today())
    materialized = %{"date" => today, "todos" => entries}

    with {:ok, all} <- BeliefStore.read() do
      updated = Enum.map(all, fn a ->
        if a.id == node_id, do: %{a | materialized: materialized}, else: a
      end)

      case BeliefStore.write(updated) do
        {:ok, _path} -> :ok
        {:error, _reason} = error -> error
      end
    end
  end
end
