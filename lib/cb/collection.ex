defmodule CB.Collection do
  @moduledoc """
  Resolve and load belief collections through a local registry.

  A collection is a `beliefs.json` graph in a declared `namespace` (`cb:`,
  `lib:`, `agent-behavior:`, …) with a sibling `manifest.json` carrying its
  `namespace`, `description`, and cross-namespace `depends_on`. A registry
  (`collections.json`: `namespace -> path-to-beliefs.json`, relative to the
  registry file) maps namespaces to graphs.

  Collections are not standalone: a dependent collection's beliefs reference
  beliefs in the namespaces it `depends_on`. So loading a collection for
  rendering or verification means loading it *together with* its transitive
  dependency closure, as one union. This module is the single place that
  resolves that closure and loads the union; `mix cb.verify.collection` and the
  dashboard's belief viewer both call it rather than re-implementing it.

  Every function returns `{:ok, _}` / `{:error, reason}` — nothing halts, so the
  API is usable from a long-lived process (a LiveView) as well as a mix task.

  ## Example

      {:ok, reg} = CB.Collection.registry()
      {:ok, %{union: beliefs}} = CB.Collection.load_union("agent-behavior", reg)
      # `beliefs` is agent-behavior: plus its cb:/paradigm: dependency closure
  """

  alias CB.{Belief, JSON}

  # Registry location relative to the framework root. A staging-monorepo
  # convenience; the durable declarations live in each collection's manifest.
  @default_registry "../belief-collections/collections.json"

  defmodule Registry do
    @moduledoc """
    A loaded collections registry: the `namespace -> relative-path` map plus the
    directory those paths resolve against (the registry file's own dir).
    """
    @enforce_keys [:collections, :dir, :path]
    defstruct [:collections, :dir, :path]

    @type t :: %__MODULE__{
            collections: %{optional(String.t()) => String.t()},
            dir: String.t(),
            path: String.t()
          }
  end

  @typedoc "What `load_union/2` returns: the resolved order, per-collection beliefs, and their union."
  @type union :: %{
          target: String.t(),
          namespaces: [String.t()],
          collections: [{String.t(), [Belief.t()]}],
          union: [Belief.t()]
        }

  @doc "Absolute path of the default registry (framework-root-relative)."
  @spec default_registry_path() :: String.t()
  def default_registry_path, do: Path.expand(Path.join(CB.repo_root(), @default_registry))

  @doc """
  Load and validate a registry file. Defaults to `default_registry_path/0`.

  Returns `{:ok, %Registry{}}` or `{:error, reason}` where reason is
  `{:registry_unreadable, path, inner}` or `{:bad_registry, message}`.
  """
  @spec registry(String.t()) :: {:ok, Registry.t()} | {:error, term()}
  def registry(path \\ default_registry_path()) do
    expanded = Path.expand(path)

    case JSON.read(expanded) do
      {:ok, %{"collections" => map}} when is_map(map) ->
        {:ok, %Registry{collections: map, dir: Path.dirname(expanded), path: expanded}}

      {:ok, _} ->
        {:error, {:bad_registry, ~s(no "collections" map in #{expanded})}}

      {:error, reason} ->
        {:error, {:registry_unreadable, expanded, reason}}
    end
  end

  @doc "Available namespaces in a registry, sorted."
  @spec namespaces(Registry.t()) :: [String.t()]
  def namespaces(%Registry{collections: map}), do: map |> Map.keys() |> Enum.sort()

  @doc "Absolute path to a namespace's `beliefs.json`."
  @spec collection_path(String.t(), Registry.t()) :: {:ok, String.t()} | {:error, term()}
  def collection_path(ns, %Registry{collections: map, dir: dir}) do
    case Map.fetch(map, ns) do
      {:ok, rel} -> {:ok, Path.expand(rel, dir)}
      :error -> {:error, {:unknown_namespace, ns}}
    end
  end

  @doc """
  Declared cross-namespace dependencies for a namespace, read from its sibling
  `manifest.json`. A collection with no manifest (or a manifest without
  `depends_on`) is a leaf — `{:ok, []}`.
  """
  @spec depends_on(String.t(), Registry.t()) :: {:ok, [String.t()]} | {:error, term()}
  def depends_on(ns, %Registry{} = reg) do
    with {:ok, path} <- collection_path(ns, reg) do
      manifest = path |> Path.dirname() |> Path.join("manifest.json")

      case JSON.read(manifest) do
        {:ok, %{"depends_on" => deps}} when is_list(deps) -> {:ok, deps}
        _ -> {:ok, []}
      end
    end
  end

  @doc """
  The transitive, cycle-safe `depends_on` closure for a namespace, target first.

  Mutually-dependent collections (e.g. `agent-behavior:` ↔ `paradigm:`) resolve
  without looping. An `{:error, {:unknown_namespace, ns}}` is returned if the
  target or any dependency is absent from the registry.
  """
  @spec closure(String.t(), Registry.t()) :: {:ok, [String.t()]} | {:error, term()}
  def closure(target, %Registry{} = reg), do: do_closure([target], reg, [])

  defp do_closure([], _reg, acc), do: {:ok, Enum.reverse(acc)}

  defp do_closure([ns | rest], reg, acc) do
    cond do
      ns in acc ->
        do_closure(rest, reg, acc)

      not Map.has_key?(reg.collections, ns) ->
        {:error, {:unknown_namespace, ns}}

      true ->
        case depends_on(ns, reg) do
          {:ok, deps} -> do_closure(rest ++ deps, reg, [ns | acc])
          {:error, _} = err -> err
        end
    end
  end

  # The schema version this loader speaks. The cutover is hard: a corrected
  # collection is a migrated collection - there is no quiet coexistence of
  # v1 and v2 graphs in one union.
  @schema_version 2

  @doc "Load one collection's beliefs as `Belief` structs."
  @spec load(String.t(), Registry.t()) :: {:ok, [Belief.t()]} | {:error, term()}
  def load(ns, %Registry{} = reg) do
    with {:ok, path} <- collection_path(ns, reg),
         :ok <- check_schema_version(ns, path) do
      case JSON.read(path) do
        {:ok, data} when is_list(data) -> {:ok, Enum.map(data, &Belief.from_map/1)}
        {:ok, _} -> {:error, {:not_an_array, ns, path}}
        {:error, reason} -> {:error, {:collection_unreadable, ns, path, reason}}
      end
    end
  end

  defp check_schema_version(ns, beliefs_path) do
    manifest = beliefs_path |> Path.dirname() |> Path.join("manifest.json")

    found =
      case JSON.read(manifest) do
        {:ok, %{"schema_version" => v}} -> v
        _ -> nil
      end

    if found == @schema_version do
      :ok
    else
      {:error,
       {:schema_version, ns,
        "manifest declares schema_version #{inspect(found)}, loader requires #{@schema_version}; " <>
          "migrate with `mix cb.migrate.v2 --collection <path>`"}}
    end
  end

  @doc """
  Load a target collection together with its dependency closure.

  Returns `{:ok, %{target:, namespaces:, collections:, union:}}` — the resolved
  namespace order (target first), `{namespace, beliefs}` pairs in that order, and
  the flat union of all beliefs. The second argument is a `%Registry{}` (already
  loaded) or a registry path (loaded for you).
  """
  @spec load_union(String.t(), Registry.t() | String.t()) :: {:ok, union()} | {:error, term()}
  def load_union(target, registry_or_path \\ default_registry_path())

  def load_union(target, %Registry{} = reg) do
    with {:ok, namespaces} <- closure(target, reg),
         {:ok, loaded} <- load_all(namespaces, reg) do
      {:ok,
       %{
         target: target,
         namespaces: namespaces,
         collections: loaded,
         union: Enum.flat_map(loaded, fn {_ns, beliefs} -> beliefs end)
       }}
    end
  end

  def load_union(target, path) when is_binary(path) do
    with {:ok, reg} <- registry(path), do: load_union(target, reg)
  end

  defp load_all(namespaces, reg) do
    namespaces
    |> Enum.reduce_while({:ok, []}, fn ns, {:ok, acc} ->
      case load(ns, reg) do
        {:ok, beliefs} -> {:cont, {:ok, [{ns, beliefs} | acc]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      err -> err
    end
  end
end
