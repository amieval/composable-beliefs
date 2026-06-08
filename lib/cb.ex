defmodule CB do
  @moduledoc """
  Composable Beliefs - root module.

  Provides `repo_root/0`, which all path computation derives from, and
  `today/0`. The framework is intentionally free of any host-application
  coupling: the only runtime dependency is Jason, and all storage routes
  through `CB.Config`.

  See `docs/belief-graph.md` for the design reference; the guided tour lives
  with the teaching material in belief-collections (`../belief-collections/quickstart.md`).
  """

  @doc """
  Returns the repository root directory.

  Resolved relative to this file (`lib/cb.ex`), so it works regardless of
  the working directory and needs no Mix at runtime.
  """
  def repo_root, do: Path.expand("..", __DIR__)

  @doc "Returns today's local date as a `Date` struct."
  def today do
    {date, _time} = :calendar.local_time()
    Date.from_erl!(date)
  end
end
