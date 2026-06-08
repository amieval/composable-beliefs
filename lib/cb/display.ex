defmodule CB.Display do
  @moduledoc """
  Shared terminal display utilities - width detection and string truncation.
  """

  @doc "Detect terminal width, falling back to 120."
  def terminal_width do
    case :io.columns() do
      {:ok, cols} -> cols
      _ -> 120
    end
  end

  @doc "Truncate `str` to `max` columns, appending `..` if trimmed."
  def trunc(nil, _max), do: ""
  def trunc(str, max) when byte_size(str) <= max, do: str
  def trunc(str, max) when max <= 2, do: String.slice(str, 0, max)
  def trunc(str, max), do: String.slice(str, 0, max - 2) <> ".."
end
