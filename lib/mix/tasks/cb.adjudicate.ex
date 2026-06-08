defmodule Mix.Tasks.Cb.Adjudicate do
  @moduledoc """
  Apply a captured belief-conflict adjudication to the DAG.

  Reads a single adjudication record (the wire format the preflight step
  writes after the user chooses `accept_supersede | reject_dep_tie |
  defer`) and invokes `CB.Belief.Adjudication.apply/2` to perform the
  atomic write.

  The wire format is:

      {
        "proposed": { ...belief fields, no id... },
        "conflicting_id": "c029",
        "outcome": "accept_supersede" | "reject_dep_tie" | "defer",
        "reasoning": "user-provided text",
        "session_ref": "review-session-2026-04-21"
      }

  ## Usage

      mix cb.adjudicate --file /tmp/cb-adjudication-....json

  ## Exit codes

  - `0` success
  - `1` invalid input (missing fields, bad outcome, malformed JSON,
    missing file, conflicting id not found in DAG)
  - `2` internal conflict - the conflicting belief's status moved off
    `active` between adjudication capture and this task running, a race
    we refuse to compound
  """
  @shortdoc "Apply a captured belief adjudication outcome"

  use Mix.Task

  alias CB.Belief.Adjudication

  @impl Mix.Task
  def run(args) do
    case process(args) do
      {:ok, summary} ->
        IO.puts(render(summary))

      {:halt, code, msg} ->
        IO.puts(:stderr, msg)
        System.halt(code)
    end
  end

  @doc """
  Test-friendly core. Parses args, runs the adjudication, and returns
  either `{:ok, summary}` or `{:halt, exit_code, stderr_message}` so
  tests can assert on exit behaviour without `System.halt/1` killing
  the test VM.

  `opts` is passed through to `CB.Belief.Adjudication.apply/2`, so
  tests can point writes at a temp `:beliefs_path`.
  """
  @spec process([String.t()], keyword()) ::
          {:ok, Adjudication.summary()} | {:halt, 1 | 2, String.t()}
  def process(args, opts \\ []) do
    {parsed, _positional, _} =
      OptionParser.parse(args, strict: [file: :string], aliases: [f: :file])

    with {:ok, path} <- require_file(parsed),
         {:ok, raw} <- read_file(path),
         {:ok, decoded} <- decode(raw),
         {:ok, summary} <- Adjudication.apply(decoded, opts) do
      {:ok, summary}
    else
      {:error, :conflicting_already_terminal} ->
        {:halt, 2,
         "adjudicate: conflicting belief is already in a terminal state; refusing"}

      {:error, reason} ->
        {:halt, 1, "adjudicate error: #{inspect(reason)}"}
    end
  end

  defp require_file(parsed) do
    case parsed[:file] do
      nil -> {:error, :missing_file_option}
      path -> {:ok, path}
    end
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, {:file, path, reason}}
    end
  end

  defp decode(raw) do
    case Jason.decode(raw) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:ok, _} -> {:error, :input_must_be_object}
      {:error, %Jason.DecodeError{} = err} -> {:error, {:json, Exception.message(err)}}
    end
  end

  @doc """
  Render the summary returned by `CB.Belief.Adjudication.apply/2`
  as the human-readable success output.
  """
  def render(%{outcome: "accept_supersede"} = s) do
    """
    Adjudication applied: accept_supersede
      new belief: #{s.new_id}
      superseded: #{s.superseded_id} -> #{s.new_id}
      path: #{s.path}\
    """
  end

  def render(%{outcome: "reject_dep_tie"} = s) do
    """
    Adjudication applied: reject_dep_tie
      new belief: #{s.new_id}
      deps now include: #{s.conflicting_id}
      path: #{s.path}\
    """
  end

  def render(%{outcome: "defer"} = s) do
    """
    Adjudication applied: defer
      deferral primitive: #{s.new_id}
      conflicting: #{s.conflicting_id} (untouched)
      path: #{s.path}\
    """
  end
end
