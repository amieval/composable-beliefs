# Composable Beliefs

Composable Beliefs (CB) is a framework for giving AI agents **persistent, inspectable, composable reasoning**: a directed acyclic graph of structured claims ("beliefs") an agent can query, compose, supersede, and act on - with provenance, a self-describing schema, and contracts that carry their own rules and invariants.

The dependency footprint is one library (Jason). The graph layer is deterministic - pure traversal, no LLM required. The test suite and `mix cb.verify.schema` are green.

## Why

Agents lose their reasoning at every session boundary. The durable artifacts they leave behind - guidance files, system prompts, memory notes - are flat instructions: an agent can satisfy them superficially without internalizing the reasoning, and there is no structural record of *why* a rule exists or whether it is still true.

CB treats beliefs as data:

- **Composable** - small primitives combine into compounds; the whole carries more than the parts.
- **Inspectable** - every primitive cites a source; you can query the graph, trace a conclusion to its evidence, and see what depends on what.
- **Supersedable** - beliefs are immutable; change happens by superseding, retracting, or retiring, so history is traceable and staleness is detectable.
- **Self-describing** - the schema of the graph is itself expressed as contracts *in* the graph.

## Core concepts

**Three structural types**
- `primitive` - an atomic claim grounded in a single source (a fact, observation, rule, or policy).
- `compound` - a claim composed from other beliefs (its `deps`); it means more than its parts.
- `implication` - something that should happen, or a contract that enforces an invariant.

**Provenance.** Every primitive cites an `artifact` (a typed URI such as `document:`, `source:`, `session:`, `user:`, `https:`) and may carry `evidence[]` entries. Conclusions trace back to the records that produced them.

**Status lifecycle (immutability).** Beliefs are never edited in place. A belief is `active`, then may become `superseded` (replaced by a named successor), `retracted` (withdrawn, with a reason), or `retired` (a contract no longer in force). Because change is structural, a belief whose dependency was superseded is *detectably stale*.

**Contracts.** A contract is an implication with `contract: true` and non-empty `rules` / `invariants`. Interpreters give contracts a small queryable API - for example a `state-machine` (`{from, to, requires}` edges) or an `enum` (`{field, values}` closed enumeration).

**Self-referential schema.** The graph's own schema - the closed enums for `kind`, `domain`, and artifact scheme; the status lifecycle; the contract discipline - is expressed as contracts (`cb:c029`, `cb:c038`-`cb:c041`) *inside the graph*. `mix cb.verify.schema` checks the `CB.Belief` struct against those contracts, so code and declared schema cannot silently drift.

## What is in this repo

- `lib/cb/` - the framework: the `CB.Belief` struct + serialization, the deterministic graph layer (traversal, filter, conflict-preflight, supersession, staleness), the contract interpreters, a pluggable materializer, and the `mix bs` belief shell + `mix cb.*` operations. Sole dependency: Jason.
- `beliefs/beliefs.json` - the belief graph (see below).
- `docs/` - the design reference (`belief-graph.md`) and operational learnings (`operations.md`). The guided `quickstart.md` lives with the teaching material in `belief-collections`.
- `skills/` - agent skills (`/assert`, `/assertions`, `/assert-session`, `/materialize`) for working the graph in a Claude-Code-style harness.
- CI (`.github/workflows/composable-beliefs.yml`) - on every push, runs the tests, `cb.verify.schema`, and a docs-freshness gate that fails if the committed CLAUDE.md drifts from the graph (`cb.generate.claude_md --check`).

## The belief graph

`beliefs/beliefs.json` is **self-referential**: it is CB's own design expressed as beliefs - the framework describing itself in its own format (run `mix bs stats` for the live shape). It holds:

- the **schema contracts** that define the graph's own discipline - the status lifecycle (`cb:c029`), schema discipline (`cb:c038`), conflict scope (`cb:c032`), and the closed enums for `kind`, artifact-scheme, and `domain` (`cb:c039`-`cb:c041`), among others;
- the **mechanism** primitives and compounds - provenance and evidence discipline, immutability, the contract layer, the consensus/preflight workflow, materialization, cross-session and cross-subagent persistence;
- the **positioning** beliefs - what belongs in the graph versus in code, and why contracts sit between literal code and plain English.

`mix cb.verify.schema` checks the `CB.Belief` struct against the schema contracts in this graph - the graph is both the example and the specification.

> Note: because beliefs are immutable historical records, many claims predate this repo's vocabulary and still read "assertion" where the framework now says "belief." That wording is preserved deliberately - editing a belief's claim in place would violate the immutability the model is built on.

## Quick start

```sh
mix deps.get
mix bs stats              # graph overview
mix bs list               # list beliefs
mix bs show cb:c038       # one contract in full (schema discipline)
mix bs tree cb:c038       # a contract and its dependency context
mix cb.verify.schema      # check the struct against the in-graph schema contracts
```

Belief ids are namespaced (`cb:`), so the shell takes the full id. See the guided tour in `belief-collections` (`../belief-collections/quickstart.md`).

## Honest status - where this actually stands

To calibrate expectations:

- **Real and tested.** The deterministic graph layer (the belief shell, traversal, supersession, staleness, conflict-preflight, the contract interpreters, schema verification) is the solid core, with a green test suite and `cb.verify.schema`.
- **Demonstrated, not yet load-bearing at runtime.** Beliefs are currently *authored* and *compiled into context at session start*; no hook yet queries the graph *contextually at decision time*. Until that exists, the graph is high-value developer-facing structure, not yet an operational runtime substrate. A development state, not a refutation.
- **Stubbed.** The materializer (implication to action items) ships a generic JSON sink; wiring it to a real task system is the host's job (`CB.Materializer.Sink`).
- **Out of scope here.** A graph-visualization / dashboard UI; the skills assume a Claude-Code-style agent harness.

## Origin

CB was extracted and decoupled from a live operational system where the graph was built and battle-tested against real workflows. The proprietary domain data was removed; what ships here is the generic framework plus its own self-describing design graph.

## License

Licensed under the Apache License, Version 2.0 - see [`LICENSE`](LICENSE).
