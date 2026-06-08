defmodule CB.Config do
  @moduledoc """
  Centralized configuration for storage paths.

  Plain functions rather than scattered literals - keeps paths greppable.
  Each path can be overridden via application env (key `:cb`) so a host
  application can point the framework at its own belief graph:

      config :cb, beliefs_path: "/path/to/my/beliefs.json"

  The belief graph path additionally honors the `CB_BELIEFS` environment
  variable, and `mix bs --beliefs PATH` sets the same app env for the
  duration of a task - so an alternate collection (e.g. a belief-collection)
  can be queried without editing config. Precedence: app env,
  then `CB_BELIEFS`, then the default path.
  """

  @doc "Absolute path to the belief graph JSON file."
  def beliefs_path do
    Application.get_env(:cb, :beliefs_path) ||
      System.get_env("CB_BELIEFS") ||
      Path.join(CB.repo_root(), "beliefs/beliefs.json")
  end

  @doc """
  Absolute path to the materialized-todos JSON file.

  This is the sink the default materializer (`CB.Materializer.Sink.JSON`)
  appends action items to. Override via application env to point at a
  host application's own todo collection.
  """
  def todos_path do
    Application.get_env(:cb, :todos_path) ||
      Path.join(CB.repo_root(), "beliefs/todos.json")
  end
end
