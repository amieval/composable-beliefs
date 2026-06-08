defmodule CB.Materializer.Sink.JSON do
  @moduledoc """
  Default `CB.Materializer.Sink` that appends todo records to a JSON file.

  Each action item becomes a generic todo record:

      {
        "id": "t0007",
        "action": "<free text from the action item>",
        "source": "<belief id that produced it>",
        "created": "2026-06-03",
        "status": "open"
      }

  Records are appended to the JSON array at `CB.Config.todos_path/0`
  (overridable via the `:path` opt, or globally via
  `config :cb, todos_path: ...`). The file is created on first write.
  IDs are `t`-prefixed, zero-padded, and continue from the highest
  existing id in the file so appends never collide.

  This is intentionally host-agnostic: there is no owner, no due date,
  no object/ref coupling. A host that needs richer todos supplies its
  own sink implementing the `CB.Materializer.Sink` behaviour.
  """

  @behaviour CB.Materializer.Sink

  alias CB.Config
  alias CB.JSON

  @impl CB.Materializer.Sink
  def persist(implication, action_items, opts \\ []) do
    path = Keyword.get(opts, :path, Config.todos_path())
    today = Keyword.get(opts, :today, Date.to_iso8601(CB.today()))
    source = implication.id

    with {:ok, existing} <- read(path) do
      {records, refs, _next} =
        Enum.reduce(action_items, {[], [], next_seq(existing)}, fn item, {recs, refs, seq} ->
          id = format_id(seq)
          action = item["action"]

          record = %{
            "id" => id,
            "action" => action,
            "source" => source,
            "created" => today,
            "status" => "open"
          }

          ref = %{"action" => action, "id" => id}
          {[record | recs], [ref | refs], seq + 1}
        end)

      updated = existing ++ Enum.reverse(records)
      content = Jason.encode!(updated, pretty: true) <> "\n"

      case JSON.write_atomic_raw(path, content) do
        {:ok, _path} -> {:ok, Enum.reverse(refs)}
        {:error, reason} -> {:error, {:write_failed, reason}}
      end
    end
  end

  # Read the existing todo array, tolerating a missing file (treated as []).
  defp read(path) do
    if File.exists?(path) do
      case JSON.read(path) do
        {:ok, list} when is_list(list) -> {:ok, list}
        {:ok, _} -> {:error, :todos_not_a_list}
        {:error, reason} -> {:error, {:read_failed, reason}}
      end
    else
      {:ok, []}
    end
  end

  # Next sequence number = one past the highest t-prefixed id present.
  defp next_seq(records) do
    records
    |> Enum.map(& &1["id"])
    |> Enum.map(&parse_seq/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> 0 end)
    |> Kernel.+(1)
  end

  defp parse_seq(id) when is_binary(id) do
    case Regex.run(~r/^t(\d+)$/, id) do
      [_, num] -> String.to_integer(num)
      _ -> nil
    end
  end

  defp parse_seq(_), do: nil

  defp format_id(n) when n < 10_000, do: "t" <> String.pad_leading(Integer.to_string(n), 4, "0")
  defp format_id(n), do: "t#{n}"
end
