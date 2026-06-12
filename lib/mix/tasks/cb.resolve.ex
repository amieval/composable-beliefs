defmodule Mix.Tasks.Cb.Resolve do
  @moduledoc """
  Resolve bare anchor rows against a root - draft-mode anchor resolution.

  `CB.Codepath` dereferences belief ids, so unregistered artifacts -
  draft answers, anchored positions - could not reach the one tested
  resolver. This task is their entry point: it validates and resolves
  `{path, anchor, nth}` rows with **no belief collection required**,
  sharing `CB.Anchor` with the codepath renderer. It is the verification
  gate for answer-time anchoring and the `/position` capture skill.

  ## Usage

      mix cb.resolve --file rows.json [--root DIR] [--json]

  The file is a JSON array; each element is either a `code:` URI string
  (the c043 grammar, parsed by `CB.CodeLocator`) or an object with
  `"path"` and `"anchor"` keys plus an optional positive-integer `"nth"`.

  Paths resolve against `--root` (default: the current working
  directory). `--json` emits the resolved rows machine-readably.

  ## Exit codes

  0 = every row valid and resolved to a line (loose-anchor warnings are
  reported but do not fail), 1 = any invalid row, any unresolved anchor,
  or an unreadable/invalid input file.
  """
  @shortdoc "Resolve bare {path, anchor, nth} rows against a root (no collection)"

  use Mix.Task

  alias CB.{Anchor, CodeLocator}

  @impl Mix.Task
  def run(args) do
    {opts, _positional, _} =
      OptionParser.parse(args, strict: [file: :string, root: :string, json: :boolean])

    file = opts[:file] || halt("--file is required (a JSON array of anchor rows)")
    root = opts[:root] || File.cwd!()

    with {:ok, content} <- File.read(file),
         {:ok, decoded} <- Jason.decode(content),
         {:ok, rows} <- parse_rows(decoded) do
      results = Enum.map(rows, &resolve_row(root, &1))

      if opts[:json] do
        IO.puts(Jason.encode!(%{root: root, rows: results}, pretty: true))
      else
        IO.puts(render_text(results))
      end

      if Enum.all?(results, & &1.line), do: :ok, else: System.halt(1)
    else
      {:error, %Jason.DecodeError{} = err} ->
        halt("#{file} is not valid JSON: #{Exception.message(err)}")

      {:error, reason} when is_atom(reason) ->
        halt("cannot read #{file} (#{inspect(reason)})")

      {:error, messages} when is_list(messages) ->
        halt("invalid rows:\n  " <> Enum.join(messages, "\n  "))
    end
  end

  @doc false
  # Public for testing - decoded JSON to anchor rows, or per-row messages.
  def parse_rows(decoded) when is_list(decoded) do
    decoded
    |> Enum.with_index()
    |> Enum.map(fn {element, index} -> parse_row(element, index) end)
    |> Enum.split_with(&match?({:ok, _}, &1))
    |> case do
      {oks, []} -> {:ok, Enum.map(oks, fn {:ok, row} -> row end)}
      {_, errors} -> {:error, Enum.map(errors, fn {:error, msg} -> msg end)}
    end
  end

  def parse_rows(_decoded), do: {:error, ["top level must be a JSON array of anchor rows"]}

  defp parse_row("code:" <> _ = uri, index) do
    case CodeLocator.parse(uri) do
      {:ok, row} -> {:ok, row}
      {:error, reason} -> {:error, "row #{index}: invalid code: URI (#{reason})"}
    end
  end

  defp parse_row(%{"path" => path, "anchor" => anchor} = element, index) do
    nth = element["nth"]

    cond do
      not (is_binary(path) and path != "") ->
        {:error, "row #{index}: \"path\" must be a non-empty string"}

      not (is_binary(anchor) and anchor != "") ->
        {:error, "row #{index}: \"anchor\" must be a non-empty string"}

      not (is_nil(nth) or (is_integer(nth) and nth >= 1)) ->
        {:error, "row #{index}: \"nth\" must be a positive integer when present"}

      true ->
        {:ok, %{path: path, anchor: anchor, nth: nth}}
    end
  end

  defp parse_row(_element, index),
    do: {:error, "row #{index}: must be a code: URI string or a {path, anchor, nth} object"}

  defp resolve_row(root, row) do
    {line, warnings} = Anchor.resolve(root, row)
    Map.merge(row, %{line: line, warnings: warnings})
  end

  @doc false
  # Public for testing - pure text rendering of resolved rows.
  def render_text(results) do
    {resolved, failed} = Enum.split_with(results, & &1.line)

    rows = Enum.flat_map(results, &render_row/1)
    summary = "#{length(results)} row(s): #{length(resolved)} resolved, #{length(failed)} failed"

    Enum.join(rows ++ [summary], "\n")
  end

  defp render_row(%{line: line, warnings: warnings} = row) do
    selector = if row.nth, do: "@#{row.nth}", else: ""

    head =
      if line do
        "ok    #{row.path}:#{line}  \"#{row.anchor}\"#{selector}"
      else
        "FAIL  #{row.path}  \"#{row.anchor}\"#{selector}"
      end

    [head | Enum.map(warnings, &"      ! #{&1}")]
  end

  defp halt(msg) do
    IO.puts(:stderr, "cb.resolve: #{msg}")
    System.halt(1)
  end
end
