# Composable Beliefs

Composable Beliefs (CB) gives a system's reasoning a durable, inspectable form: a directed acyclic graph of small structured claims ("beliefs"), each grounded in a cited source, that compose into conclusions no single source states. Beliefs are never edited in place - they are superseded - so every change leaves a trail, and anything still resting on a replaced premise is mechanically detectable.

Two commitments define the design:

- **Beliefs, not facts.** The unit of the graph records what is believed, on what evidence, and what would have to change - truth status is tracked and revisable, never presumed. A belief can turn out to be wrong without breaking the model; that is what retraction is for.
- **Reasoning is authored.** Humans and agents create every belief, exercising judgment at each step; CB records the derivation, keeps it walkable, and makes the reasoning inspectable, composable, and falsifiable.

At its core CB is a schema. The format is plain JSON, and the discipline could in principle be practiced with a text editor. What ships in this repo is the schema plus the machinery that turns its promises into guarantees - an Elixir library and mix-task suite for querying, verifying, authoring, and rendering belief graphs. The schema gives you legibility; the verifiers give you guarantees. One dependency (Jason), pure deterministic traversal, no LLM anywhere in the read path, and CI gates every push on the test suite and the graph verifiers.

The result is a layer for specifying, analyzing, and evolving a system that is neither natural language nor code: more formal than prose, so it can be machine-checked; less brittle than code, so it can carry intent, provenance, and history.

## What you can use it for

The same mechanism takes three concrete shapes. They share one schema, one query surface, and one change discipline.

**1. Durable, auditable reasoning for AI agents.** Agents lose their reasoning at every session boundary, and the durable artifacts they leave behind - guidance files, system prompts, memory notes - are flat instructions: an agent can satisfy them superficially without internalizing the reasoning, and there is no structural record of *why* a rule exists or whether it is still true. In CB, every rule is a belief with provenance; when a premise is superseded, everything resting on it is flagged for review; and the agent-facing digest (this repo's own `CLAUDE.md`) is compiled from the graph, never hand-maintained.

```sh
mix bs stale --cascade        # what is resting on replaced premises?
```

**2. Codepaths: code tours that cannot rot.** A codepath is a belief collection anchored to real source files - rendered, it is a narrated, branching tour of a codebase; executed, it is a test suite over the same claims. Anchors resolve by content at render time, so refactors that move code do not break the tour.

```sh
CB_BELIEFS=codepath/beliefs.json mix cb.verify.codepath belief-pipeline
```

**3. An evidence ledger for published eval findings.** Every measurement is a belief tracing to raw logs, the house methodology is machine-enforced contracts rather than a prose document, and a corrected finding visibly wears its correction. The whole evidence tree behind a verdict renders to one self-contained HTML file a reader can walk with nothing but a browser.

```sh
mix cb.render.audit toy:a10 --collection toy --out audit.html
```

If you are evaluating adoption: you adopt a JSON file format for your graph, a small Elixir library and its mix tasks to query and verify it, and (optionally) agent skills for a Claude-Code-style harness. Three things stay deliberately outside CB's scope, left to other tools: vector memory, model calls, and eval execution.

## Sixty seconds

```sh
mix deps.get && mix compile
mix bs tree cb:c047
```

```
cb:c047 [contract] Contracts carry routing tables; modules carry predicate implementations. The DSL expresses which predicates fire on which conditions; it does not express how predicates are implemented.
├── cb:a300 [primitive] A contract is the formalization of an implication - the implication states WHAT (the conclusion), the contract states HOW (rules as Given/When/Then scenarios) and ALWAYS (invariants)
├── cb:c054 [contract] A node is contract-grade iff its type is directive and its rules or invariants array is non-empty - contract is the machine-checkable grade of a directive, not a type. The c-prefix ID convention is a naming reflection of this structural property, not the definition of contract identity. Code that operates on contracts must detect them via Belief.contract?/1 and never by ID prefix matching.
│   ├── cb:a300 [primitive] ...
│   └── cb:a470 [primitive] The cb-schema-v2 design (plans/cb-schema-v2/design.md, decided 2026-06-10) replaces the three-type schema with four structural types, one per epistemic operation: primitive (attest), compound (aggregate), inference (infer), directive (prescribe). ...
└── cb:c046 [contract] Contract rules decompose into a closed registry of interpretable kinds, each with a Datalog fact shape, an Elixir interpreter module, and required fields per rule entry
```

That is the whole idea on one screen. A design rule of this framework (`cb:c047`) is data, not prose; the premises it rests on are themselves beliefs you can keep walking; and the traversal is pure - no model, no ranking, no retrieval, just the graph. The [documentation](#documentation) builds that picture up one layer at a time.

## Quick start

```sh
mix deps.get && mix compile
mix bs stats              # graph overview
mix bs show cb:c056       # one contract in full (schema discipline)
mix bs tree cb:c056       # a contract and its dependency context
mix bs history cb:c043    # a supersession chain (the artifact-scheme enum)
mix cb.verify.schema      # check the struct against the in-graph schema contracts
```

The full command surface and a longer tour are in the [reference](docs/reference.md). For the guided version, see `../belief-collections/quickstart.md` in the sibling repo - if the self-referential `cb:` graph is a lot to meet first, start with the `lib:` lending-library collection there.

## Documentation

- **[The mental model](docs/mental-model.md)** - what a belief looks like, the four structural types, provenance, subjects versus deps, immutability and supersession, contracts, collections and borrowing, and what the graph compiles to.
- **[Codepaths](docs/codepaths.md)** - beliefs anchored to code: the `code:` locator, the render-spec, the narrate/assert gradient, and the shipped tour of CB's own pipeline.
- **[The eval evidence ledger](docs/eval-ledger.md)** - findings as evidence chains, methodology as self-enforcing contracts, the run-manifest seam, and the audit tree.
- **[Worked example](docs/worked-example-eval-verdict.md)** - tracing an eval verdict to its evidence, end to end, with real command output: from a published finding down to the raw logs, the methodology checks that judge it, and the supersession machinery run for real.
- **[Reference](docs/reference.md)** - the command surface, artifact schemes, the schema contract family, and the repo layout.
- Design documents: the [design reference index](docs/belief-graph.md) (which points into the graph rather than restating it), the [thesis](docs/composable-beliefs-thesis.md), the [BEAM rationale](docs/cb-on-the-beam.md), the [run-manifest spec](docs/run-manifest.md), and [operational learnings](docs/operations.md). Design records and executed plans live in `plans/`.

## Honest status - where this actually stands

To calibrate expectations:

- **Real and tested.** The deterministic graph layer (the belief shell, traversal, supersession, staleness, conflict preflight + adjudication, the contract interpreters, schema and collection verification), the codepath layer (the `code:` locator, the resolver/renderer, the predicate routing and dynamic verifier, test-run materialization), and the eval-ledger layer (the method-check pass, the run-manifest importer with idempotence and identity-conflict detection, the audit renderer with golden-file determinism tests) are the solid core: a green test suite that includes an anchor-rot guard against the real source, plus CI gates on schema verification and docs freshness.
- **Proven on a synthetic round trip; awaiting its first real finding.** The full eval pipeline has run end to end against genuine Inspect logs (produced under the zero-cost mockllm provider): harness run -> adapter -> run-manifest -> import -> verified collection -> rendered audit tree. By the fixture-provenance rule everything in that round trip is `fixture`-tagged - it proves the machine, it is not a finding. The first real finding requires the human parts: choosing the eval, judging load-bearing cases, authoring the compounds and verdict, standing behind the result.
- **Demonstrated, not yet load-bearing at runtime.** Beliefs are currently *authored* and *compiled into context at session start* (CLAUDE.md, rule files); no hook yet queries the graph *contextually at decision time*. Until that exists, the graph is high-value developer-facing structure, not yet an operational runtime substrate. A development state, not a refutation.
- **Deferred by design.** Codepath predicates run in-process today. Federation into a live BEAM app (Tidewave MCP, plan-3 Step B) is specified but deliberately unbuilt until a predicate genuinely needs live application state - the design refuses speculative runtime plumbing.
- **Host integration is the host's job.** The materializer ships a generic JSON sink and the test sink; wiring directives into a real task tracker means implementing `CB.Materializer.Sink` for it.
- **Out of scope here.** A graph-visualization / dashboard UI; the skills assume a Claude-Code-style agent harness.

## Origin

CB was extracted and decoupled from a live operational system where the graph was built and battle-tested against real workflows. The proprietary domain data was removed; what ships here is the generic framework plus its own self-describing design graph. The codepath capability has its own origin story - it began as a standalone, cb-independent plugin and collapsed into the framework when the design discussion showed the alignment was total; the full record is in `plans/cb-codepath/` (decision record, four executed plans, and the design and execution transcripts).

## License

Licensed under the Apache License, Version 2.0 - see [`LICENSE`](LICENSE).
