defmodule Mix.Tasks.Cb.Todo.Close do
  @moduledoc """
  Flip a materialized todo item from open to done, with discharge notes.

  The sanctioned front door for the todo half of a discharge - the
  counterpart of `mix cb.evidence` on the belief half. Routes through
  `CB.Todos`, the same module the materializer's JSON sink appends
  through, so the collection's serialization is pinned by one code path
  and no flip needs a hand-rolled script.

  ## Usage

      mix cb.todo.close <todo-id> --notes "..."            # Dry run
      mix cb.todo.close <todo-id> --notes "..." --write

  ## Options

  - `--notes` (required) - the discharge notes; a record that already
    carries materialization-time notes keeps them, with the discharge
    notes appended as a new paragraph
  - `--todos PATH` - operate on an alternate todo file (defaults to
    `CB.Config.todos_path/0`)
  - `--write` - apply; without it the flip is printed but not written

  ## Validation

  Exits non-zero before writing if the todo id is unknown, the record
  is not open (the flip is strictly open -> done), or the notes are
  missing or empty.
  """
  @shortdoc "Flip a materialized todo item from open to done"

  use Mix.Task

  alias CB.Todos

  @impl Mix.Task
  def run(args) do
    {opts, positional, invalid} =
      OptionParser.parse(args,
        strict: [
          notes: :string,
          todos: :string,
          write: :boolean
        ]
      )

    if invalid != [] do
      flags = Enum.map_join(invalid, ", ", fn {flag, _} -> flag end)
      halt("unknown options: #{flags}")
    end

    id =
      case positional do
        [id] ->
          id

        _ ->
          IO.puts(:stderr, usage())
          System.halt(1)
      end

    case validate_notes(opts[:notes]) do
      {:ok, notes} -> close(id, notes, opts[:todos], opts[:write] || false)
      {:error, message} -> halt(message)
    end
  end

  defp close(id, notes, path, write?) do
    path = path || CB.Config.todos_path()

    with {:ok, records} <- Todos.read(path),
         {:ok, updated, closed} <- Todos.close(records, id, notes) do
      report(closed)

      if write? do
        case Todos.write(updated, path) do
          {:ok, _path} ->
            IO.puts(:stderr, "\nClosed.")

          {:error, reason} ->
            halt("error writing todo collection: #{inspect(reason)}")
        end
      else
        IO.puts(:stderr, "\nDry run. Pass --write to apply.")
      end
    else
      {:error, {:not_found, id}} ->
        halt("no todo with id: #{id}")

      {:error, {:not_open, id, status}} ->
        halt("todo #{id} is not open (status: #{status}) - the flip is strictly open -> done")

      {:error, reason} ->
        halt("error reading todo collection: #{inspect(reason)}")
    end
  end

  defp report(closed) do
    IO.puts("Todo close")
    IO.puts(String.duplicate("=", 40))
    IO.puts("\n#{closed["id"]} (source: #{closed["source"] || "-"})")
    IO.puts("  #{truncate(closed["action"], 76)}")
    IO.puts("\nStatus: open -> done")
    IO.puts("Notes:  #{closed["notes"]}")
  end

  defp truncate(nil, _max), do: "-"

  defp truncate(text, max) do
    if String.length(text) > max, do: String.slice(text, 0, max - 1) <> "…", else: text
  end

  @doc """
  Validate the `--notes` value: required and non-empty.
  """
  @spec validate_notes(String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def validate_notes(nil), do: {:error, "--notes is required"}

  def validate_notes(notes) do
    if String.trim(notes) == "" do
      {:error, "--notes must not be empty"}
    else
      {:ok, notes}
    end
  end

  defp usage do
    "Usage: mix cb.todo.close <todo-id> --notes \"...\" [--todos PATH] [--write]"
  end

  @spec halt(String.t()) :: no_return()
  defp halt(message) do
    IO.puts(:stderr, "Error: #{message}")
    System.halt(1)
  end
end
