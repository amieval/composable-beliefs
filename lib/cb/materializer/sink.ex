defmodule CB.Materializer.Sink do
  @moduledoc """
  Behaviour for the destination a directive's action items are written to.

  Materialization turns a `type: "directive"` belief into a set of
  concrete action items and persists them somewhere. *Where* is the
  host application's concern, not the framework's - a project tracker
  might create todos on issue objects, a CI system might open tickets, a
  notebook might append rows to a table. The framework only owns the
  generic `directive -> action items -> sink -> link belief.materialized`
  flow; the sink is the seam where the host plugs in.

  A sink receives the directive belief plus the derived action items and
  is responsible for persisting them. It returns one ref per persisted
  item; those refs are recorded back onto the belief's `materialized`
  field by `CB.Belief.Materializer` so the link from belief to its
  materialized artifacts is inspectable.

  The default implementation `CB.Materializer.Sink.JSON` appends generic
  todo records to a JSON file at `CB.Config.todos_path/0`.

  ## The callback

  `persist/3` takes:

  - `directive` - the `CB.Belief` being materialized (its `id` is the
    provenance link recorded on each created item)
  - `action_items` - a list of string-keyed maps, each with at least an
    `"action"` key (free text describing what to do)
  - `opts` - a keyword list for sink-specific configuration (e.g.
    `:path`, `:today`); the default sink reads `:path` and `:today`

  It returns `{:ok, refs}` where `refs` is a list of string-keyed maps
  (one per action item) recording at minimum the `"action"` and the
  sink-assigned `"id"`, or `{:error, reason}`.
  """

  alias CB.Belief

  @typedoc "A single action item to materialize. Free-form except for \"action\"."
  @type action_item :: %{required(String.t()) => term()}

  @typedoc "A reference to one persisted item, returned by the sink."
  @type ref :: %{required(String.t()) => term()}

  @callback persist(directive :: Belief.t(), action_items :: [action_item()], opts :: keyword()) ::
              {:ok, [ref()]} | {:error, term()}
end
