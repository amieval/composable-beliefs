defmodule CB.Anchor do
  @moduledoc """
  Resolve a bare anchor row - `%{path, anchor, nth}` - to a current line.

  This is the belief-free core of anchor resolution, extracted from
  `CB.Codepath` so unregistered artifacts (draft answers, anchored
  positions) share the one tested resolver with codepath rendering.
  `CB.Codepath` resolves a belief's `code:` artifact through this module;
  `mix cb.resolve` resolves bare rows through it with no collection
  loaded.

  ## Resolution rules (per the cb-codepath plan-1 design)

  - Anchors are literal substrings, matched per line (`grep -nF`
    semantics); the resolved line number is never stored.
  - A missing file or anchor yields `line: nil` plus a warning, never a
    crash; whether that is a maintenance signal or a hard failure is the
    caller's doctrine.
  - Multiple matches with no `nth` selector resolve to the **first**
    match plus a tighten-this-anchor warning naming the match count. An
    explicit `nth` is intentional and warns only when out of range.
  """

  @type row :: %{path: String.t(), anchor: String.t(), nth: pos_integer() | nil}

  @doc """
  Resolve one row against `root`. Returns `{line, warnings}` where
  `line` is `nil` when the file or anchor cannot be resolved.
  """
  @spec resolve(String.t(), row()) :: {pos_integer() | nil, [String.t()]}
  def resolve(root, %{path: path, anchor: anchor, nth: nth}) do
    case File.read(Path.join(root, path)) do
      {:error, reason} ->
        {nil, ["cannot read #{path} (#{inspect(reason)})"]}

      {:ok, content} ->
        matches =
          content
          |> String.split("\n")
          |> Enum.with_index(1)
          |> Enum.filter(fn {text, _n} -> String.contains?(text, anchor) end)
          |> Enum.map(fn {_text, n} -> n end)

        pick_match(matches, anchor, nth, path)
    end
  end

  defp pick_match([], anchor, _nth, path),
    do: {nil, [~s(anchor "#{anchor}" not found in #{path})]}

  defp pick_match([line], _anchor, nil, _path), do: {line, []}

  defp pick_match([first | _] = matches, anchor, nil, path) do
    warning =
      ~s(anchor "#{anchor}" matches #{length(matches)} lines in #{path}) <>
        " - tighten this anchor (rendering the first match)"

    {first, [warning]}
  end

  defp pick_match(matches, anchor, nth, path) do
    case Enum.at(matches, nth - 1) do
      nil ->
        warning =
          ~s{anchor "#{anchor}"@#{nth} requested but only #{length(matches)} match(es) in #{path}}

        {nil, [warning]}

      line ->
        {line, []}
    end
  end
end
