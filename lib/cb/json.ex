defmodule CB.JSON do
  @moduledoc """
  Shared JSON file I/O utilities.

  The atomic write pattern (tmp + rename) plus common JSON read/list
  operations used by the store. Stores encode their own data via
  `Jason.encode!/2` so key ordering is explicit at each call site.
  """

  @doc """
  Atomically write pre-encoded content to `path`.

  Writes to a `.tmp` sibling, then renames. On failure the `.tmp` file is
  cleaned up and the original is untouched. Returns `{:ok, path}` or
  `{:error, reason}`.
  """
  def write_atomic_raw(path, content) when is_binary(content) do
    File.mkdir_p!(Path.dirname(path))
    tmp_path = path <> ".tmp"

    with :ok <- File.write(tmp_path, content),
         :ok <- File.rename(tmp_path, path) do
      {:ok, path}
    else
      {:error, reason} ->
        File.rm(tmp_path)
        {:error, reason}
    end
  end

  @doc "Read and JSON-decode a file. Returns `{:ok, decoded}` or `{:error, reason}`."
  def read(path) do
    with {:ok, content} <- File.read(path),
         {:ok, data} <- Jason.decode(content) do
      {:ok, data}
    end
  end

  @doc "List non-hidden `.json` files in a flat directory."
  def list_dir(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        paths =
          files
          |> Enum.filter(&(String.ends_with?(&1, ".json") and not String.starts_with?(&1, ".")))
          |> Enum.map(&Path.join(dir, &1))

        {:ok, paths}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "List non-hidden `.json` files recursively under `dir`."
  def list_recursive(dir) do
    Path.join(dir, "**/*.json")
    |> Path.wildcard()
    |> Enum.reject(&(Path.basename(&1) |> String.starts_with?(".")))
  end
end
