defmodule CB.CodeLocator do
  @moduledoc """
  Parse `code:` artifact URIs - anchored sites within a repository file.

  ## Grammar

      code:<repo-relative-path>#<anchor>[@<N>]

  - The path segment runs to the **first** `#` and is repo-relative.
  - Everything after the first `#` is the anchor segment: one opaque
    literal substring (the fixed-string grep target), with no delimiter
    parsing inside it - an anchor may itself contain `#`.
  - An optional trailing `@<N>` (N >= 1) selects the Nth match. An anchor
    that must literally end in `@<digits>` percent-encodes that suffix as
    `%40<digits>`; the encoding exists only for this collision, so only a
    trailing `%40<digits>` is decoded.
  - The resolved line number is never stored; it is recomputed at
    render/run time. A missing anchor is a maintenance signal, not
    corruption. Multiple matches resolve to the first match plus a
    tighten-this-anchor warning (enforced by the renderer, not here).

  The scheme is declared in the cb: graph's artifact-scheme enum contract;
  this module is the single parser the verifier and renderer share.
  """

  @type t :: %{path: String.t(), anchor: String.t(), nth: pos_integer() | nil}

  @doc """
  Parse a `code:` URI into `%{path, anchor, nth}`.

  Returns `{:error, reason}` with reason one of `:not_code_scheme`,
  `:missing_anchor`, `:empty_path`, `:empty_anchor`, `:zero_occurrence`.
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, atom()}
  def parse("code:" <> rest) do
    case String.split(rest, "#", parts: 2) do
      [_no_hash] -> {:error, :missing_anchor}
      ["", _] -> {:error, :empty_path}
      [path, anchor_segment] -> parse_anchor(path, anchor_segment)
    end
  end

  def parse(uri) when is_binary(uri), do: {:error, :not_code_scheme}

  @doc "True if the URI parses as a valid `code:` locator."
  @spec valid?(String.t()) :: boolean()
  def valid?(uri) when is_binary(uri), do: match?({:ok, _}, parse(uri))
  def valid?(_), do: false

  defp parse_anchor(_path, ""), do: {:error, :empty_anchor}

  defp parse_anchor(path, anchor_segment) do
    {anchor, nth} = split_occurrence(anchor_segment)

    cond do
      anchor == "" -> {:error, :empty_anchor}
      nth == 0 -> {:error, :zero_occurrence}
      true -> {:ok, %{path: path, anchor: decode_at_suffix(anchor), nth: nth}}
    end
  end

  # A trailing `@<digits>` is the occurrence selector; anything else is
  # part of the opaque literal anchor.
  defp split_occurrence(segment) do
    case Regex.run(~r/^(.*)@(\d+)$/s, segment) do
      [_, anchor, digits] -> {anchor, String.to_integer(digits)}
      nil -> {segment, nil}
    end
  end

  # Decode only the defined escape: a trailing `%40<digits>` standing in
  # for a literal `@<digits>`. Other `%40` occurrences stay literal.
  defp decode_at_suffix(anchor) do
    String.replace(anchor, ~r/%40(\d+)$/, "@\\1")
  end
end
