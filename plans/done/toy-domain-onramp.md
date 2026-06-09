# Toy-Domain On-Ramp (Library Circulation Example)

**Status:** Phases 0-3 implemented 2026-06-07. Loader, example collection, tutorial, and smoke test; a generalized (collection-agnostic) `cb.verify.schema` extracted into `CB.Schema.Verifier`; and a self-describing `lib:` schema (enum contracts for kind/domain/artifact-scheme). Refinement on the original "mirror c029" sketch: the status lifecycle is framework-universal, so the collection inherits it via the verifier's canon fallback rather than restating it - vocabulary is the collection's to declare, structure is the framework's.
**Date:** 2026-06-07
**Depends on:** the cb:-only self-describing graph (restructure Stage 3); `Config.beliefs_path/0` env override; `Graph.resolve_id/2` multi-namespace resolution
**Touches:** `composable-beliefs-public/examples/` (new), `lib/mix/tasks/bs.ex`, `docs/quickstart.md`

## Context

The public graph (`beliefs/beliefs.json`) is now fully self-describing: it is the
framework reasoning about its own design - schema contracts, mechanism, positioning.
README and quickstart tour that graph. This is the right canonical artifact, but it is
pedagogically circular: a newcomer must already understand the mechanism to read the
graph that explains the mechanism. There is currently no concrete external domain a
first-time reader can use to learn primitive/compound/implication, composition,
supersession, staleness, and materialization on familiar ground.

A latent toy domain already exists in the codebase: the materializer test and the
`/materialize` skill both use a library-circulation scenario (loan periods, hold expiry,
members, queues). This spec proposes making that domain a first-class, self-contained
teaching example.

**Goal:** a newcomer can, in under 15 minutes and using only the CLI, see one of every
node type plus composition, supersession, staleness, and a materialized link - on a
domain they already understand - before meeting the self-referential graph.

## Domain choice: library circulation

Chosen over alternatives (stable-marriage already lives in `evals/` but is abstract;
recipe/release domains are less universally modeled) because it is universally
understood, already partly present in the repo, and naturally exhibits every feature:
rules (loan period), a state machine (item status), emergent composition (loan period +
hold rules together), policy change over time (supersession), and operational
consequences (materialization).

## Design decision: self-contained collection with its own namespace

Model A (recommended): the example is a **separate collection** at
`examples/library/beliefs.json` using the `lib:` namespace, isolated from the real
`cb:` graph. The just-shipped `Graph.resolve_id/2` already supports multiple namespaces
(and reports `lib:a020` vs `cb:a020` as ambiguous for a bare `a020`), so the
infrastructure is ready.

Model B (rejected): fold the example into the cb: graph reusing its enums. Rejected
because it blurs "this is the framework" against "this is a toy," and bends a library
domain into the framework's own domain enum.

## Coverage checklist (one node per feature)

The example must exercise, at minimum:

- **primitive** with `artifact` + `evidence[]` - `lib:a001` "Standard loan period is 21 days"
- **supersession** - `lib:a002` "loan period is 14 days", `superseded_by: lib:a001`
- **compound** (emergent meaning) - `lib:c010` "effective availability of a held item is governed by both loan period and hold-expiry", deps `[lib:a001, lib:a005]`
- **stale node** - `lib:c011` "overdue-fine schedule assumes a 14-day baseline", deps `[lib:a002]` -> lights up `mix bs stale` because `a002` is superseded
- **implication** (materializable) - `lib:a020` "when a hold expires, return item to available and notify next in queue", deps `[lib:a005, lib:c001]`
- **materialized implication** - `lib:a021` "when loan period changes, recompute due dates for active checkouts", carries a `materialized` block linking to example todos
- **contract-grade implication** - `lib:c001` item-status state machine (`available | checked_out | on_hold | lost | withdrawn`) with `rules`/`invariants`, `contract: true`; mirrors how `cb:c029` governs belief status, on a concrete machine
- **subjects/refs** - nodes carry `subjects` (e.g. `{type: "policy", ref: "policy/loan-period"}`) so `mix bs subjects` works

Roughly 11 nodes total - small enough to read in one sitting, complete enough to show the
whole mechanism.

## The real gap: pointing the CLI at an alternate collection

`mix bs` reads `Config.beliefs_path/0`, which is env-overridable
(`config :cb, beliefs_path: ...`) but has **no CLI flag**. For the tutorial to feel
interactive, close this first. Options:

1. **`--beliefs PATH` flag on `mix bs`** (recommended). Minimal, explicit. Cleanest
   implementation: in `Mix.Tasks.Bs.run/1`, if the flag is present,
   `Application.put_env(:cb, :beliefs_path, path)` before dispatch - reuses the existing
   env seam, no change to `Store.read/0`. ~10 lines + a test.
2. **`CB_BELIEFS` env var** honored by `Config.beliefs_path/0`. Good for "switch into
   example mode" once; pairs well with (1).
3. **First-class collections** (`mix bs --collection library`) mapping names to paths via
   config. Aligns with the multi-repo/multi-collection restructure direction, but is the
   largest change - defer.
4. **Zero-code** - document the `Application.put_env` / `config :cb` override and ship a
   tiny `examples/library/query.exs`. Works today, clunky interactively.

Recommend (1) + (2). Treat as a small prerequisite implementation task, not part of the
content authoring.

## Proposed layout

```
composable-beliefs-public/
  examples/
    library/
      beliefs.json     # the lib: collection, ~11 nodes
      todos.json       # sink target for lib:a021's materialized block
      README.md        # the guided walkthrough
```

Plus a pointer at the top of `docs/quickstart.md`: "New here? Walk `examples/library`
first - the same mechanics on a familiar domain - then come back to the self-referential
graph."

## Tutorial outline (`examples/library/README.md`)

1. Why this exists (gentle on-ramp; the real graph is self-referential by design).
2. Point the shell at it: `mix bs --beliefs examples/library/beliefs.json stats` (or `export CB_BELIEFS=...`).
3. Walk the graph: list primitives; `show lib:a001` (evidence); `show lib:c010` (explain emergence); `show lib:c001` (a contract's invariants).
4. Trace composition: `mix bs tree lib:a020` - a conclusion standing on primitives.
5. Supersession + staleness: `history lib:a001` (14 -> 21 days), then `stale` to see `lib:c011` flagged.
6. Materialize: inspect `lib:a021`'s `materialized` link; optionally run `/materialize` on an unmaterialized implication.
7. Bridge: "now read the real graph - same mechanics, applied to the framework itself."

## Schema conformance (open decision)

The example should not silently diverge from the framework's schema discipline. Two paths:

- **v1 - documented-minimal.** The example conforms to a small documented subset
  (`examples/library/SCHEMA.md`) and is guarded by a smoke test (below). The existing
  `cb.verify.schema` references the cb: contract ids, so it would not verify a `lib:`
  collection without change - acceptable for v1.
- **Phase 3 stretch - fully self-describing.** Author `lib:` schema contracts mirroring
  `cb:c038/c039/c040/c041/c029` scaled down, and generalize `cb.verify.schema` to verify
  any collection against the contracts it carries. This is the truest teaching artifact -
  the example would define and enforce its own schema, exactly as the cb: graph does -
  but it is the most work and is not required for the on-ramp to land.

## Phasing

- **Phase 0 (prereq, code):** `--beliefs PATH` + `CB_BELIEFS` override on `mix bs`; test.
- **Phase 1 (content):** author `examples/library/beliefs.json` (~11 nodes per checklist) and `examples/library/README.md`; documented-minimal schema.
- **Phase 2 (integration):** quickstart/README pointer; a smoke test in `mix test` that loads the example and asserts its shape (e.g. ~11 nodes, exactly 1 stale, 1 unlinked implication, 1 materialized) so it cannot rot silently.
- **Phase 3 (stretch):** self-describing `lib:` schema + generalized verifier.

## Acceptance criteria

- `mix bs --beliefs examples/library/beliefs.json stats` runs and reports the expected shape.
- A newcomer can read one of each node type and observe composition, supersession,
  staleness, and a materialized link, CLI-only, in under 15 minutes.
- A test guards the example's integrity against schema/loader drift.
- The example is unmistakably separate from the real graph (own dir, own `lib:` namespace, README framing).

## Risks and non-goals

- **Drift** as the schema evolves -> mitigated by the Phase 2 smoke test.
- **"Which graph is real?" confusion** -> mitigated by `examples/` isolation, the `lib:` namespace, and explicit README framing.
- **Non-goal:** exhaustiveness. This is a teaching artifact, not a reference graph.
- **Non-goal:** displacing the self-referential graph as the canonical positioning. The example is the on-ramp; the self-graph remains the thesis.

## Open questions for the author

1. Schema path: ship v1 documented-minimal, or invest in the Phase 3 self-describing `lib:` schema up front?
2. Loader: `--beliefs` flag only, or also `CB_BELIEFS` and/or a named-collection concept?
3. Should the materialized example (`lib:a021`) ship with a populated `examples/library/todos.json`, or have the tutorial generate it live via `/materialize`?
