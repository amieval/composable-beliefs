# Composable Beliefs DAG - Design Reference

The DAG's design lives *in the graph*, as beliefs and contracts. This file is a thin index: it points at the authoritative nodes and keeps the reference that does not live in the graph (query patterns, storage layout, positioning). It does not restate the design - query it.

## Schema contracts (the source of truth)

The schema is expressed as contracts in the graph; the struct in `lib/cb/belief.ex` is the code-side SSOT those contracts govern.

| Contract | Governs |
|---|---|
| `c029` | Status lifecycle and immutability |
| `c032` | Conflict scope - when two implications overlap |
| `c038` | Schema discipline - `artifact` provenance, `contract: true` flag, no `implication` field, enum-shaped `kind`/`domain`/`artifact-scheme` |
| `c039` | Closed enum of `belief.kind` values |
| `c043` | Closed enum of artifact URI schemes (supersedes `c040`; added the `code:` locator) |
| `c041` | Closed enum of `belief.domain` values |

Query any contract for its rules and invariants - e.g. `mix bs show cb:c038`, `mix bs tree cb:c029`. Verification:

- `mix cb.verify.schema` - check a collection against the contracts it carries
- `mix cb.verify.collection <ns>` - check a collection together with its declared dependency collections
- `mix cb.audit.conflicts` - surface overlapping implications per `c032`

These run in CI on every push (`.github/workflows/composable-beliefs.yml`), alongside the test suite and a docs-freshness gate (`mix cb.generate.claude_md --check`) that fails if the committed CLAUDE.md no longer matches the graph - structural, not procedural, freshness per `cb:a386`.

## Design rationale (query, don't restate)

The reasoning is in the graph. Entry points:

| Topic | Query |
|---|---|
| Three structural types (primitive / compound / implication) | `mix bs show cb:a298`; contract form `cb:c026` / `cb:c031` |
| Contract = formalized implication | `mix bs show cb:a300` / `cb:c038` |
| Kind semantics and the `kind: policy` test | `cb:a399` / `cb:a439` / `cb:c039` |
| Immutability and the status lifecycle | `cb:a302` / `cb:c029` |
| No confidence score (structural support instead) | `cb:a448`; `CB.Belief.support/1` returns artifact / evidence / dep counts |
| Artifacts and URI schemes | `cb:a398` / `cb:a400` / `cb:a407` / `cb:c043` |
| Shared prosthetic; composition over retrieval | `cb:a460` / `cb:a462` |
| Persistence across sessions and subagents | `cb:a339` / `cb:a340` / `cb:a341` |

For the full chain behind any node, `mix bs tree <id>`.

## Field reference

Full field definitions and types are the struct in `lib/cb/belief.ex` (SSOT), governed by `c038`. In brief:

- **All types:** `id` (namespaced, `cb:a001` / `cb:c029`), `type`, `kind` (enum per `c039`), `domain` (enum per `c041`), `tags`, `claim`, `subjects` (`{ref, type}`), `status`, `created`.
- **Primitive:** `artifact` (URI, scheme enum per `c043`) + `evidence` (`{date, artifact, detail}` entries).
- **Compound / implication:** `deps` (upstream belief ids).
- **Implication:** `materialized` (`null` or `{date, tasks}`); contract-grade adds non-empty `rules` + `invariants` with `contract: true` (biconditional per `c038`).
- **Terminal:** `superseded_by` (on `superseded`), `retracted_on` + `retracted_reason` (on `retracted`).

## Query patterns (CLI)

```bash
mix bs list                 # all active beliefs (filters: type, status, kind:, domain:, tag:, subject)
mix bs show cb:a138         # full detail on one belief
mix bs tree cb:a138         # dependency tree from a node
mix bs stale                # beliefs whose deps were superseded/retracted
mix bs subjects <ref|type>  # beliefs about a subject
mix bs history cb:a443      # supersession chain
mix bs stats                # graph statistics
```

## Query patterns (jq)

```bash
# All active beliefs
jq '[.[] | select(.status == "active")]' beliefs/beliefs.json

# Unmaterialized implications (no tasks created yet)
jq '[.[] | select(.type == "implication" and .materialized == null)]' beliefs/beliefs.json

# Contract-grade implications
jq '[.[] | select(.contract == true)]' beliefs/beliefs.json

# Beliefs about a subject ref
jq '[.[] | select(.subjects[]?.ref == "policy/loan-period")]' beliefs/beliefs.json

# Stale: non-primitives depending on a superseded node
jq '
  [.[] | select(.status == "superseded") | .id] as $stale |
  [.[] | select(.type != "primitive" and (.deps // [] | any(. as $d | $stale | index($d))))]
' beliefs/beliefs.json
```

## Storage

Single file: `beliefs/beliefs.json` - an array of belief objects, queryable with `mix bs` or jq. Source documents the collaboration produces live under `sources/` (`emails/`, `analyses/`, `transcripts/`, `research/`), named `YYYY-MM-DD-slug.md` and referenced from beliefs via the `source:` scheme.

## Relationship to existing systems

The DAG does not replace existing systems; it adds a reasoning layer that connects them.

| System | DAG relationship |
|---|---|
| Per-field provenance | Coexists. Stays on entities; primitives add the composition layer on top. |
| Task collection | Coexists. Implications materialize into tasks; the `materialized` field links belief to tasks. |
| Data model | Coexists. The data model stores current state; the DAG stores the reasoning about it. |

## Skills and authoring

Query with `/assertions` (or `mix bs`). Author with `/assert` and `/assert-session`, which preflight a proposed belief for conflicts before writing; `/materialize` turns an implication into tasks. The framework CLAUDE.md (generated from the graph) carries the current command and skill set.
