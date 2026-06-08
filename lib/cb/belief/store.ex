defmodule CB.Belief.Store do
  @moduledoc """
  Reads and writes the belief graph JSON file. Atomic writes via tmp +
  rename. All entries are beliefs - contract-grade beliefs are
  distinguished by having `rules` and/or `invariants` fields.
  """

  alias CB.Belief
  alias CB.Config
  alias CB.JSON

  @doc "Read all entries from the belief graph as beliefs."
  def read do
    path = Config.beliefs_path()

    if File.exists?(path) do
      with {:ok, data} <- JSON.read(path) do
        {:ok, Enum.map(data, &Belief.from_map/1)}
      end
    else
      {:ok, []}
    end
  end

  @doc "Alias for read/0. Reads all entries."
  def read_all, do: read()

  @doc "Find a belief by ID or name."
  def find(id_or_name) do
    with {:ok, all} <- read() do
      case Enum.find(all, &(&1.id == id_or_name || &1.name == id_or_name)) do
        nil -> {:error, :not_found}
        belief -> {:ok, belief}
      end
    end
  end

  def write(beliefs, path \\ nil) do
    path = path || Config.beliefs_path()
    ordered = Enum.map(beliefs, &Belief.to_map/1)
    content = Jason.encode!(ordered, pretty: true) <> "\n"
    JSON.write_atomic_raw(path, content)
  end
end
