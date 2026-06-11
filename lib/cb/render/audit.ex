defmodule CB.Render.Audit do
  @moduledoc """
  Render a belief's full evidence tree as a publishable artifact.

  Three layers, each a pure function of the one before:

  1. `build/3` - the render-neutral tree: the requested belief at the
     root, deps walked depth-first, every node annotated with status,
     staleness (`--cascade` semantics applied at render time), full
     evidence entries **including their artifacts** (closing the
     `bs tree`/`bs show` gap), and supersession linkage. Cross-namespace
     deps become labeled leaf links by default - the evidence chain, not
     the vocabulary closure.
  2. `to_json/1` - the same tree as data, with pinned key order. The
     format is the offer: anyone can build their own viewer.
  3. `to_html/1` - one self-contained file: inline CSS, zero JS
     (collapse/expand is native `<details>`), no external assets, no
     CDN. Renders fully in a browser with no network access.

  Determinism: output is byte-stable for a given graph + id + options.
  The only date that can appear is the explicit `:date` option (plus the
  dated fields already in beliefs); the footer's graph digest is
  computed from the canonical serialization of the loaded union.
  """

  alias CB.Belief
  alias CB.Belief.Graph

  @renderer "cb.render.audit/1"

  @doc """
  Build the render-neutral audit tree for `root_id` over `beliefs`.

  Options:
  - `:depth` - maximum dep depth to walk (default: unlimited within the
    root's namespace). Nodes with unwalked deps are marked truncated.
  - `:date` - explicit render date string for the footer (default: none,
    keeping re-renders byte-identical).
  - `:source` - label for the footer's source line (e.g. the collection
    namespace or beliefs path).

  Returns `{:ok, tree}` or `{:error, :not_found | {:ambiguous, ids}}`.
  """
  @spec build(String.t(), [Belief.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def build(root_id, beliefs, opts \\ []) do
    with {:ok, id} <- Graph.resolve_id(beliefs, root_id) do
      index = Graph.index(beliefs)
      stale = stale_map(beliefs)
      depth = Keyword.get(opts, :depth)

      root = walk(id, index, stale, namespace(id), depth, MapSet.new())

      {:ok,
       %{
         root: root,
         meta: %{
           root: id,
           source: Keyword.get(opts, :source),
           namespaces: beliefs |> Enum.map(&namespace(&1.id)) |> Enum.uniq() |> Enum.sort(),
           belief_count: length(beliefs),
           digest: digest(beliefs),
           renderer: @renderer,
           date: Keyword.get(opts, :date)
         }
       }}
    end
  end

  # --- tree construction ---

  defp walk(id, index, stale, root_ns, depth, path) do
    cond do
      MapSet.member?(path, id) ->
        leaf(id, :circular)

      index[id] == nil ->
        leaf(id, :missing)

      namespace(id) != root_ns and path != MapSet.new() ->
        link_leaf(index[id])

      true ->
        belief_node(index[id], index, stale, root_ns, depth, path)
    end
  end

  defp belief_node(b, index, stale, root_ns, depth, path) do
    deps = b.deps || []
    truncated = depth == 0 and deps != []

    children =
      if truncated do
        []
      else
        next = if is_integer(depth), do: depth - 1, else: depth
        Enum.map(deps, &walk(&1, index, stale, root_ns, next, MapSet.put(path, b.id)))
      end

    %{
      role: :belief,
      id: b.id,
      type: b.type,
      kind: b.kind,
      contract: b.contract == true,
      name: b.name,
      claim: b.claim,
      status: b.status,
      superseded_by: b.superseded_by,
      retracted_reason: b.retracted_reason,
      stale_deps: Map.get(stale, b.id, []),
      tags: b.tags || [],
      subjects: Enum.map(b.subjects || [], &%{ref: &1["ref"], type: &1["type"]}),
      artifact: b.artifact,
      evidence:
        Enum.map(
          b.evidence || [],
          &%{date: &1["date"], detail: &1["detail"], artifact: &1["artifact"]}
        ),
      truncated: truncated,
      children: children
    }
  end

  # A dep in another namespace: rendered as a labeled leaf link, not walked.
  defp link_leaf(b) do
    %{
      role: :link,
      id: b.id,
      type: b.type,
      kind: b.kind,
      contract: b.contract == true,
      name: b.name,
      claim: b.claim,
      status: b.status,
      superseded_by: b.superseded_by,
      retracted_reason: nil,
      stale_deps: [],
      tags: [],
      subjects: [],
      artifact: nil,
      evidence: [],
      truncated: false,
      children: []
    }
  end

  defp leaf(id, role) do
    %{
      role: role,
      id: id,
      type: nil,
      kind: nil,
      contract: false,
      name: nil,
      claim: nil,
      status: nil,
      superseded_by: nil,
      retracted_reason: nil,
      stale_deps: [],
      tags: [],
      subjects: [],
      artifact: nil,
      evidence: [],
      truncated: false,
      children: []
    }
  end

  defp stale_map(beliefs) do
    beliefs
    |> Graph.stale(cascade: true)
    |> Map.new(fn {b, bad} -> {b.id, bad} end)
  end

  defp namespace(id) do
    case String.split(id, ":", parts: 2) do
      [ns, _] -> ns
      _ -> ""
    end
  end

  defp digest(beliefs) do
    canonical = beliefs |> Enum.map(&Belief.to_map/1) |> Jason.encode!()
    "sha256:" <> (:crypto.hash(:sha256, canonical) |> Base.encode16(case: :lower))
  end

  # --- JSON ---

  @doc "Encode the tree as pretty JSON with pinned key order."
  @spec to_json(map()) :: String.t()
  def to_json(%{root: root, meta: meta}) do
    Jason.encode!(
      ordered(
        meta:
          ordered(
            root: meta.root,
            source: meta.source,
            namespaces: meta.namespaces,
            belief_count: meta.belief_count,
            digest: meta.digest,
            renderer: meta.renderer,
            date: meta.date
          ),
        root: json_node(root)
      ),
      pretty: true
    )
  end

  defp json_node(n) do
    ordered(
      id: n.id,
      role: n.role,
      type: n.type,
      kind: n.kind,
      contract: n.contract,
      name: n.name,
      claim: n.claim,
      status: n.status,
      superseded_by: n.superseded_by,
      retracted_reason: n.retracted_reason,
      stale_deps: n.stale_deps,
      tags: n.tags,
      subjects: Enum.map(n.subjects, &ordered(ref: &1.ref, type: &1.type)),
      artifact: n.artifact,
      evidence:
        Enum.map(n.evidence, &ordered(date: &1.date, detail: &1.detail, artifact: &1.artifact)),
      truncated: n.truncated,
      children: Enum.map(n.children, &json_node/1)
    )
  end

  defp ordered(pairs),
    do: Jason.OrderedObject.new(Enum.map(pairs, fn {k, v} -> {Atom.to_string(k), v} end))

  # --- HTML ---

  @doc "Encode the tree as one self-contained HTML document."
  @spec to_html(map()) :: String.t()
  def to_html(%{root: root, meta: meta}) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Audit tree: #{esc(meta.root)}</title>
    <style>#{css()}</style>
    </head>
    <body>
    <main>
    <h1>Audit tree: <code>#{esc(meta.root)}</code></h1>
    #{html_node(root)}
    </main>
    <footer>
    #{footer(meta)}
    </footer>
    </body>
    </html>
    """
  end

  defp html_node(%{role: :missing} = n) do
    ~s(<details class="node missing"><summary><code>#{esc(n.id)}</code> <span class="badge missing">missing</span></summary></details>\n)
  end

  defp html_node(%{role: :circular} = n) do
    ~s(<details class="node circular"><summary><code>#{esc(n.id)}</code> <span class="badge">circular reference</span></summary></details>\n)
  end

  defp html_node(n) do
    classes = Enum.join(["node", to_string(n.role), n.status || ""], " ")

    """
    <details open class="#{classes}"><summary>#{summary(n)}</summary>
    <div class="body">
    #{body(n)}</div>
    #{Enum.map_join(n.children, "", &html_node/1)}</details>
    """
  end

  defp summary(n) do
    kind_label = [n.type, n.kind] |> Enum.reject(&is_nil/1) |> Enum.join("/")

    badges =
      [
        ~s(<span class="badge type">#{esc(kind_label)}</span>),
        n.contract && ~s(<span class="badge contract">contract</span>),
        n.role == :link && ~s(<span class="badge link">#{esc(namespace(n.id))}: dep</span>),
        n.status not in [nil, "active"] &&
          ~s(<span class="badge #{esc(n.status)}">#{esc(n.status)}</span>),
        n.stale_deps != [] && ~s(<span class="badge stale">stale</span>)
      ]
      |> Enum.filter(& &1)
      |> Enum.join(" ")

    name = if n.name, do: ~s( <span class="name">#{esc(n.name)}</span>), else: ""

    ~s(<code>#{esc(n.id)}</code> #{badges}#{name} <span class="claim">#{esc(n.claim)}</span>)
  end

  defp body(n) do
    [
      n.superseded_by &&
        ~s(<p class="succession">superseded by <code>#{esc(n.superseded_by)}</code></p>),
      n.retracted_reason && ~s(<p class="succession">retracted: #{esc(n.retracted_reason)}</p>),
      n.stale_deps != [] &&
        ~s(<p class="stale-note">stale: depends on #{esc(Enum.join(n.stale_deps, ", "))}</p>),
      n.subjects != [] &&
        ~s(<p class="meta">subjects: #{esc(Enum.map_join(n.subjects, ", ", fn s -> "#{s.ref} (#{s.type})" end))}</p>),
      n.tags != [] && ~s(<p class="meta">tags: #{esc(Enum.join(n.tags, ", "))}</p>),
      n.artifact && ~s(<p class="meta">artifact: #{artifact_html(n.artifact)}</p>),
      evidence_html(n.evidence),
      n.truncated && ~s|<p class="meta truncated">deps not walked (depth limit)</p>|
    ]
    |> Enum.filter(& &1)
    |> Enum.map_join("", &(&1 <> "\n"))
  end

  defp evidence_html([]), do: nil

  defp evidence_html(entries) do
    items =
      Enum.map_join(entries, "\n", fn e ->
        parts =
          [
            e.date && ~s(<span class="date">#{esc(e.date)}</span>),
            e.detail && esc(e.detail),
            e.artifact && ~s(<span class="evidence-artifact">#{artifact_html(e.artifact)}</span>)
          ]
          |> Enum.filter(& &1)
          |> Enum.join(" — ")

        "<li>#{parts}</li>"
      end)

    "<ul class=\"evidence\">\n#{items}\n</ul>"
  end

  defp artifact_html(artifact) do
    if String.starts_with?(artifact, "https://") do
      ~s(<a href="#{esc(artifact)}">#{esc(artifact)}</a>)
    else
      "<code>#{esc(artifact)}</code>"
    end
  end

  defp footer(meta) do
    [
      meta.source && "source: #{esc(meta.source)}",
      "namespaces: #{esc(Enum.join(meta.namespaces, ", "))}",
      "beliefs in union: #{meta.belief_count}",
      "graph digest: <code>#{esc(meta.digest)}</code>",
      "renderer: #{esc(meta.renderer)}",
      meta.date && "rendered: #{esc(meta.date)}"
    ]
    |> Enum.filter(& &1)
    |> Enum.map_join("\n", &"<p>#{&1}</p>")
  end

  defp esc(nil), do: ""

  defp esc(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp esc(other), do: esc(to_string(other))

  defp css do
    """
    body{font-family:ui-sans-serif,system-ui,sans-serif;margin:2rem auto;max-width:60rem;padding:0 1rem;color:#1a1a1a;background:#fff}
    h1{font-size:1.2rem}
    code{font-family:ui-monospace,monospace;font-size:0.92em;background:#f4f4f4;padding:0 0.2em;border-radius:3px}
    details.node{margin:0.4rem 0 0.4rem 1.2rem;border-left:2px solid #d8d8d8;padding-left:0.8rem}
    main>details.node{margin-left:0}
    summary{cursor:pointer;line-height:1.5}
    .badge{font-size:0.72em;padding:0.1em 0.45em;border-radius:8px;background:#e8e8e8;color:#444;vertical-align:middle}
    .badge.contract{background:#e3d9f5;color:#4b2d83}
    .badge.superseded,.badge.retracted{background:#f6d6d6;color:#8a1f1f}
    .badge.stale{background:#fdeec9;color:#8a6100}
    .badge.link{background:#d8e9f7;color:#1c4f7c}
    .badge.missing{background:#f6d6d6;color:#8a1f1f}
    .name{font-weight:600}
    details.superseded>summary .claim,details.retracted>summary .claim{text-decoration:line-through;color:#777}
    .body{margin:0.2rem 0 0.4rem 0.2rem;font-size:0.9em;color:#444}
    .body p{margin:0.15rem 0}
    .succession,.stale-note{color:#8a1f1f}
    ul.evidence{margin:0.2rem 0 0.2rem 1rem;padding:0}
    ul.evidence li{margin:0.15rem 0;list-style:disc}
    .date{color:#666}
    footer{margin-top:2rem;border-top:1px solid #ddd;padding-top:0.6rem;font-size:0.8em;color:#666}
    footer p{margin:0.15rem 0}
    """
  end
end
