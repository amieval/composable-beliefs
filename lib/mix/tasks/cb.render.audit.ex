defmodule Mix.Tasks.Cb.Render.Audit do
  @moduledoc """
  Render a belief's evidence tree as a self-contained HTML file (or its
  JSON twin) suitable for publishing beside a finding.

  Verdict at the root, deps walked to the leaf observations, every
  artifact and evidence pointer visible - including the raw-log
  artifacts inside evidence entries that `bs tree` elides - plus
  supersession strike-through, successor links, and `--cascade`-style
  stale badges, so a corrected finding visibly wears its correction.
  No reader installs Elixir: the HTML opens in a browser with no
  network access and no external assets.

  ## Usage

      mix cb.render.audit <belief-id> [options]

      --collection NS     load NS plus its dependency closure (registry-resolved)
      --registry PATH     registry for --collection (default: the local registry)
      --beliefs PATH      load a single graph file instead
      --out FILE          write to FILE instead of stdout
      --json              emit the JSON twin instead of HTML
      --depth N           walk at most N dep levels (default: unlimited;
                          cross-namespace deps are always leaf links)
      --date YYYY-MM-DD   stamp the footer with an explicit render date
                          (omitted by default so re-renders are byte-identical)
      --check             with --out: re-render and fail if FILE differs -
                          CI gates a committed tree against the graph the
                          same way CLAUDE.md is gated

  ## Determinism

  Output is byte-stable for a given graph + id + options. The footer
  records the union's namespaces, belief count, content digest, and the
  renderer version - the reader's reproducibility anchor.

  ## Exit codes

  0 = rendered / check passed, 1 = unknown id, resolution error, or
  check failed.
  """
  @shortdoc "Render a belief's evidence tree as a publishable HTML/JSON audit tree"

  use Mix.Task

  alias CB.Belief.Store
  alias CB.Collection
  alias CB.Render.Audit

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args,
        strict: [
          collection: :string,
          registry: :string,
          beliefs: :string,
          out: :string,
          json: :boolean,
          depth: :integer,
          date: :string,
          check: :boolean
        ]
      )

    id = positional |> List.first() || halt("Usage: mix cb.render.audit <belief-id> [options]")
    {beliefs, source} = load(opts)

    build_opts = [depth: opts[:depth], date: opts[:date], source: source]

    content =
      case Audit.build(id, beliefs, build_opts) do
        {:ok, tree} ->
          if opts[:json], do: Audit.to_json(tree), else: Audit.to_html(tree)

        {:error, :not_found} ->
          halt("no belief with id #{inspect(id)}")

        {:error, {:ambiguous, ids}} ->
          halt("id #{inspect(id)} is ambiguous: #{Enum.join(ids, ", ")}")
      end

    deliver(content, opts[:out], opts[:check] || false)
  end

  # --- loading ---

  defp load(opts) do
    cond do
      ns = opts[:collection] ->
        registry = opts[:registry] || Collection.default_registry_path()

        case Collection.load_union(ns, registry) do
          {:ok, %{union: union}} -> {union, ns}
          {:error, reason} -> halt("cannot load collection #{ns}: #{inspect(reason)}")
        end

      path = opts[:beliefs] ->
        Application.put_env(:cb, :beliefs_path, path)
        {read_store(), path}

      true ->
        {read_store(), nil}
    end
  end

  defp read_store do
    case Store.read() do
      {:ok, beliefs} -> beliefs
      {:error, reason} -> halt("cannot read belief collection: #{inspect(reason)}")
    end
  end

  # --- output ---

  defp deliver(_content, nil, true), do: halt("--check requires --out FILE")

  defp deliver(content, out, true) do
    case File.read(out) do
      {:ok, ^content} ->
        IO.puts("#{out} is current")

      {:ok, _stale} ->
        halt("#{out} is stale - the graph moved under it; re-render without --check")

      {:error, :enoent} ->
        halt("#{out} does not exist - run without --check to render it")

      {:error, reason} ->
        halt("cannot read #{out}: #{inspect(reason)}")
    end
  end

  defp deliver(content, nil, false), do: IO.puts(content)

  defp deliver(content, out, false) do
    File.write!(out, content)
    IO.puts(:stderr, "wrote #{out} (#{byte_size(content)} bytes)")
  end

  defp halt(msg) do
    IO.puts(:stderr, "cb.render.audit: #{msg}")
    System.halt(1)
    # Unreachable; keeps callers' with/case shapes happy in tests where
    # System.halt is trapped.
    exit(:halted)
  end
end
