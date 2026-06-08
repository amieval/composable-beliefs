defmodule Mix.Tasks.Cb.Verify.Collection do
  @moduledoc """
  Verify a belief collection together with the collections it depends on.

  A collection declares its `namespace` and cross-namespace `depends_on` in a
  `manifest.json` beside its `beliefs.json`. Many collections carry no schema
  vocabulary of their own - they borrow another collection's enum and lifecycle
  contracts (e.g. `agent-behavior:` and `paradigm:` lean on `cb:`'s
  `c039`/`c041`/`c029`). Verified in isolation, their `kind`/`domain`/
  `artifact-scheme` and status checks would *skip*, because the contracts that
  close those vocabularies are not present.

  This task resolves a collection's declared dependencies through a local
  registry, loads the union of all the graphs, and runs the same
  `CB.Schema.Verifier` over the union - so a dependent collection is actually
  checked against the vocabulary it borrows, and every cross-namespace dep is
  checked for resolvability. Where `mix cb.verify.schema` verifies one
  collection against the contracts it carries, this verifies a collection *in
  the context of* its declared dependencies.

  ## Usage

      mix cb.verify.collection NAMESPACE [--registry PATH] [--quiet]

      mix cb.verify.collection agent-behavior   # unions cb: + paradigm: + itself
      mix cb.verify.collection lib              # self-contained: loads only lib:

  The registry (default `../belief-collections/collections.json`, relative
  to the framework root) maps each namespace to its `beliefs.json`. Dependency
  resolution is transitive and cycle-safe - `agent-behavior:` and `paradigm:`
  depend on each other. A collection with no `manifest.json` is treated as a
  leaf (no dependencies).

  ## Exit codes

  0 = all pass (or skipped), 1 = resolution error or one or more failures
  """
  @shortdoc "Verify a collection together with its declared dependency collections"

  use Mix.Task

  alias CB.Belief
  alias CB.Schema.Verifier

  @default_registry "../belief-collections/collections.json"

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args,
        strict: [registry: :string, quiet: :boolean],
        aliases: [q: :quiet]
      )

    quiet = opts[:quiet] || false
    target = target_namespace(positional)

    registry_path = Path.expand(opts[:registry] || Path.join(CB.repo_root(), @default_registry))
    registry = load_registry(registry_path)

    # Target plus its transitive, cycle-safe depends_on closure (target first).
    namespaces = resolve_closure(target, registry, registry_path)

    loaded = Enum.map(namespaces, &{&1, load_collection(&1, registry, registry_path)})
    union = Enum.flat_map(loaded, fn {_ns, beliefs} -> beliefs end)

    unless quiet, do: print_context(target, loaded)

    # Cross-namespace dep resolvability over the union, then the schema checks.
    results = [check_dep_resolvability(union) | Verifier.check(union)]

    shown = if quiet, do: Enum.filter(results, fn {_, s, _} -> s == :fail end), else: results
    Enum.each(shown, &print_result/1)

    {passes, failures, skipped} = tally(results)
    IO.puts("")
    IO.puts("#{passes} passed, #{failures} failed, #{skipped} skipped (#{length(results)} checks)")

    if failures > 0, do: System.halt(1)
  end

  # --- argument + registry handling ---

  defp target_namespace([ns | _]), do: ns

  defp target_namespace([]) do
    IO.puts(:stderr, "Usage: mix cb.verify.collection NAMESPACE [--registry PATH] [--quiet]")
    System.halt(1)
  end

  defp load_registry(path) do
    case CB.JSON.read(path) do
      {:ok, %{"collections" => map}} when is_map(map) -> map
      {:ok, _} -> halt_err("registry #{path} has no \"collections\" map")
      {:error, reason} -> halt_err("cannot read registry #{path}: #{inspect(reason)}")
    end
  end

  # --- dependency closure (transitive, cycle-safe) ---

  defp resolve_closure(target, registry, registry_path),
    do: do_closure([target], registry, registry_path, [])

  defp do_closure([], _registry, _registry_path, acc), do: Enum.reverse(acc)

  defp do_closure([ns | rest], registry, registry_path, acc) do
    if ns in acc do
      do_closure(rest, registry, registry_path, acc)
    else
      unless Map.has_key?(registry, ns),
        do: halt_err("collection #{inspect(ns)} is not in the registry (#{registry_path})")

      deps = manifest_depends_on(ns, registry, registry_path)
      do_closure(rest ++ deps, registry, registry_path, [ns | acc])
    end
  end

  defp manifest_depends_on(ns, registry, registry_path) do
    manifest_path =
      ns |> collection_path(registry, registry_path) |> Path.dirname() |> Path.join("manifest.json")

    case CB.JSON.read(manifest_path) do
      {:ok, %{"depends_on" => deps}} when is_list(deps) -> deps
      # No manifest, or one without depends_on, is a leaf (e.g. the cb: graph).
      _ -> []
    end
  end

  defp collection_path(ns, registry, registry_path),
    do: Path.expand(Map.fetch!(registry, ns), Path.dirname(registry_path))

  defp load_collection(ns, registry, registry_path) do
    path = collection_path(ns, registry, registry_path)

    case CB.JSON.read(path) do
      {:ok, data} when is_list(data) -> Enum.map(data, &Belief.from_map/1)
      {:ok, _} -> halt_err("collection #{ns} at #{path} is not a JSON array")
      {:error, reason} -> halt_err("cannot read collection #{ns} at #{path}: #{inspect(reason)}")
    end
  end

  # --- checks ---

  # Every dep referenced anywhere in the union must resolve to a loaded node.
  # A dangling dep means a dependency collection is missing from depends_on.
  defp check_dep_resolvability(union) do
    ids = MapSet.new(union, & &1.id)
    dangling = for b <- union, dep <- b.deps || [], not MapSet.member?(ids, dep), do: {b.id, dep}

    if dangling == [] do
      {"cross-namespace deps resolve", :ok, "every dep resolves to a loaded node"}
    else
      {"cross-namespace deps resolve", :fail,
       "unresolved deps (missing dependency collection?): #{inspect(Enum.uniq(dangling))}"}
    end
  end

  # --- io ---

  defp print_context(target, loaded) do
    IO.puts("")
    IO.puts("Verifying #{target}: in context of #{length(loaded)} collection(s)")

    Enum.each(loaded, fn {ns, beliefs} ->
      role = if ns == target, do: "target", else: "dep"
      IO.puts("  #{String.pad_trailing(ns, 16)} #{length(beliefs)} beliefs (#{role})")
    end)

    IO.puts("")
  end

  defp tally(results) do
    {Enum.count(results, fn {_, s, _} -> s == :ok end),
     Enum.count(results, fn {_, s, _} -> s == :fail end),
     Enum.count(results, fn {_, s, _} -> s == :skip end)}
  end

  defp print_result({name, :ok, detail}), do: IO.puts("  PASS  #{name} - #{detail}")

  defp print_result({name, :fail, detail}) do
    IO.puts("  FAIL  #{name}")
    IO.puts("        #{detail}")
  end

  defp print_result({name, :skip, detail}), do: IO.puts("  SKIP  #{name} - #{detail}")

  defp halt_err(msg) do
    IO.puts(:stderr, "Error: #{msg}")
    System.halt(1)
  end
end
