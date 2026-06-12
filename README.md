# Composable Beliefs

Composable Beliefs (CB) is an evidence ledger for LLM evaluation findings: a directed acyclic graph of small structured claims ("beliefs"), each grounded in a cited source, that compose into verdicts no single measurement states. Beliefs are never edited in place - they are superseded - so every change leaves a trail, a corrected finding visibly wears its correction, and anything still resting on a replaced premise is mechanically detectable.

Two commitments define the design:

- **Beliefs, not facts.** The unit of the graph records what is believed, on what evidence, and what would have to change - truth status is tracked and revisable, never presumed. A belief can turn out to be wrong without breaking the model; that is what retraction is for.
- **Reasoning is authored.** Humans and agents create every belief, exercising judgment at each step; CB records the derivation, keeps it walkable, and makes the reasoning inspectable, composable, and falsifiable.

## The problem

When you publish an eval finding - "model X silently drops records from bulk writes" - the finding is only as credible as the trail behind it. How many runs? Which scorers, and do they agree? Where are the raw logs? Was the LLM judge ever validated against a human? When the model ships a new snapshot, is the verdict corrected visibly or rewritten quietly?

The field now has receipts showing how fragile those trails are:

- **Judges fail systematically, not randomly.** Swap the order of two answers and most LLM judges flip their verdict in a large fraction of comparisons; pad an answer with information-free repetition and most judges reward it ([Zheng et al. 2023](https://arxiv.org/abs/2306.05685)). Judges measurably favor their own outputs ([Panickssery et al. 2024](https://arxiv.org/abs/2404.13076)). More than a dozen distinct judge biases are catalogued with effect sizes ([Ye et al. 2024](https://arxiv.org/abs/2410.02736)).
- **Awareness is not a fix.** LLMs exhibit a measured self-correction blind spot: competent at correcting errors in others' output, failing on identical errors in their own ([Liu et al. 2025](https://arxiv.org/abs/2507.02778)). Telling a system about its biases does not debias it.
- **The mitigations that work are structural.** Swap-and-require-agreement, binary grading against concrete criteria, judge panels, calibration against human labels - the verified fixes are procedures, not instructions.

That convergence has a fifty-year lineage. Human-subjects research reached the same verdict (Meehl's clinical-vs-statistical prediction; Kahneman and Tversky's heuristics-and-biases program): systematic error yields to procedure and structure, not to awareness and vigilance. CB takes that verdict literally and makes the procedures machine-checkable. The mapping from human biases to LLM failure modes is functional, not mechanistic - what transfers is the debiasing logic, and that is the part CB encodes.

## What CB does about it

Every element of a published finding becomes graph structure:

- **Every measurement is a belief** carrying an identity URI and a pointer to raw logs. Observations are immutable: a new model snapshot never rewrites what the old one did on that day.
- **Methodology is six self-enforcing contracts**, not a prose document. Each routes to a deterministic check that runs over any eval collection during verification: every verdict needs cross-ruler corroboration (or visibly wears a `single-ruler` tag), every observation needs raw-log provenance, every verdict cites at least 3 runs (no escape hatch), every LLM-judge measurement is joined by that judge's human-validation record, and every correction is a dated supersession. A failed check names the offending belief ids - the failure message is the work order. "Methodology v2" is a diffable batch of supersessions, not a doc edit.
- **The audit tree is the published artifact.** `mix cb.render.audit` renders a verdict's full evidence tree as one self-contained HTML file - verdict at the root, deps walked down to leaf observations and their raw-log pointers, superseded nodes struck through with links to their successors. No JavaScript, no network: a reader needs a browser, not Elixir.

```sh
mix cb.render.audit toy:a10 --collection toy --out audit.html
```

The boundary, held on purpose: **CB is the ledger, not the lab bench.** Running evals - orchestration, sampling, model calls - happens in an external harness (e.g. Inspect); CB ingests the harness's output record through a neutral run-manifest format and never grows toward execution. The importer emits observations only; verdicts stay authored by humans, by construction.

## The mechanism

At its core CB is a schema. The graph has four structural types, one per epistemic operation: primitive (what a source said), compound (what its deps jointly state), inference (a conclusion licensed to exceed its deps), and directive (what should happen). Structural support replaces confidence scores: how well-grounded a belief is falls out of artifacts, evidence, and dependency structure, not a declared number - subjective scores synthesized without a deterministic basis do no load-bearing work. The format is plain JSON; what ships in this repo is the schema plus the machinery that turns its promises into guarantees - an Elixir library and mix-task suite for querying, verifying, authoring, and rendering belief graphs. One dependency (Jason), pure deterministic traversal, no LLM anywhere in the read path, and CI gates every push on the test suite and the graph verifiers.

## Sixty seconds

```sh
mix deps.get && mix compile
mix bs tree cb:c047
```

```
cb:c047 [contract] Contracts carry routing tables; modules carry predicate implementations. The DSL expresses which predicates fire on which conditions; it does not express how predicates are implemented.
├── cb:a300 [primitive] A contract is the formalization of an implication - the implication states WHAT (the conclusion), the contract states HOW (rules as Given/When/Then scenarios) and ALWAYS (invariants)
├── cb:c054 [contract] A node is contract-grade iff its type is directive and its rules or invariants array is non-empty - contract is the machine-checkable grade of a directive, not a type. ...
│   ├── cb:a300 [primitive] ...
│   └── cb:a470 [primitive] The cb-schema-v2 design (plans/cb-schema-v2/design.md, decided 2026-06-10) replaces the three-type schema with four structural types, one per epistemic operation ...
└── cb:c046 [contract] Contract rules decompose into a closed registry of interpretable kinds, each with a Datalog fact shape, an Elixir interpreter module, and required fields per rule entry
```

That is the whole idea on one screen. A design rule of this framework (`cb:c047`) is data, not prose; the premises it rests on are themselves beliefs you can keep walking; and the traversal is pure - no model, no ranking, no retrieval, just the graph.

## Beyond the ledger

The ledger is one instance of a general mechanism. The same schema, query surface, and change discipline also run durable agent reasoning (rules as beliefs with provenance, staleness cascades, a compiled `CLAUDE.md`) and codepaths (code-anchored tours that double as test suites) - see **[Other applications](docs/other-applications.md)**.

If you are evaluating adoption: you adopt a JSON file format for your graph, a small Elixir library and its mix tasks to query and verify it, and (optionally) agent skills for a Claude-Code-style harness. Three things stay deliberately outside CB's scope, left to other tools: vector memory, model calls, and eval execution.

## Where this stands

**Proven now.**

- The deterministic core: the belief shell, traversal, supersession, staleness, conflict preflight and adjudication, the contract interpreters, schema and collection verification - a green test suite plus CI gates on schema verification and docs freshness.
- The eval pipeline, end to end, on genuine Inspect logs: harness run -> adapter -> run-manifest -> import -> verified collection -> rendered audit tree, with idempotent re-import, identity-conflict detection, and golden-file determinism tests on the renderer.
- The codepath and agent-reasoning layers, including an anchor-rot guard against the real source.

**Proven on a synthetic round trip only.** The end-to-end run used the zero-cost mockllm provider, so by the fixture-provenance rule everything in it is `fixture`-tagged: it proves the machine, it is not a finding.

**What needs proving next, in order.**

1. **The first real finding.** The machinery is waiting on the human parts: choosing the eval, judging load-bearing cases, authoring the compounds and verdict, standing behind the result. Leading candidates are judge biases the human-subjects literature predicts but the LLM-judge literature has not yet measured - anchoring on numeric score scales, halo effects across rubric criteria - which are cheap, well-specified, and would make the ledger's first finding a contribution to the methodology it enforces.
2. **Structure vs. awareness, measured.** A controlled comparison of agents with no self-knowledge (C0), the same knowledge as flat instructions (C1), and the same knowledge as composable beliefs (C2). The self-correction blind spot results supply the prior: awareness alone should not help; structure should. If C2 does not outperform C1, the thesis needs revision - that is the falsification condition, and it is stated here on purpose.
3. **Decision-time querying.** Beliefs are currently authored and compiled into context at session start; no hook yet queries the graph contextually at decision time. Until that exists, the graph is high-value developer-facing structure, not yet an operational runtime substrate.

Deferred by design: codepath predicates run in-process today; federation into a live BEAM app is specified but deliberately unbuilt until a predicate genuinely needs live application state. Host integration is the host's job (implement `CB.Materializer.Sink`). Out of scope here: a graph-visualization UI; the skills assume a Claude-Code-style agent harness.

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

The ledger:

- **[The eval evidence ledger](docs/eval-ledger.md)** - findings as evidence chains, methodology as self-enforcing contracts, the run-manifest seam, and the audit tree.
- **[Worked example](docs/worked-example-eval-verdict.md)** - tracing an eval verdict to its evidence, end to end, with real command output: from a published finding down to the raw logs, the methodology checks that judge it, and the supersession machinery run for real.
- **[The run-manifest spec](docs/run-manifest.md)** - the neutral JSON contract between the lab bench and the ledger, version 1.

The mechanism:

- **[The mental model](docs/mental-model.md)** - what a belief looks like, the four structural types, provenance, subjects versus deps, immutability and supersession, contracts, collections and borrowing, and what the graph compiles to.
- **[Reference](docs/reference.md)** - the command surface, artifact schemes, the schema contract family, and the repo layout.
- **[Design reference index](docs/belief-graph.md)** - points at the authoritative schema contracts in the graph rather than restating them, plus query patterns and storage layout.

Other applications:

- **[Other applications](docs/other-applications.md)** - the same mechanism as durable agent reasoning and as code-anchored tours.
- **[Codepaths](docs/codepaths.md)** - beliefs anchored to code: the `code:` locator, the render-spec, the narrate/assert gradient, and the shipped tour of CB's own pipeline.
- **[Actualization](docs/actualization.md)** - self-referential beliefs as an agent's structural self-knowledge.

Background and records:

- **[The thesis](docs/composable-beliefs-thesis.md)** - the paradigm argument: why belief structure, the ML parallel, the eval that would falsify it.
- **[CB on the BEAM](docs/cb-on-the-beam.md)** - the runtime rationale.
- **[Operational learnings](docs/operations.md)** - how to run an extraction session in practice.
- **[Operations vs artifacts](docs/operations-vs-artifacts.md)** - the hidden complexity gap between doing and recording.
- **[Field note: shared provenance](docs/2026-06-01-shared-provenance-shallow-clone-parable.md)** - "verify against ground truth" is necessary but not sufficient.

Design records and executed plans live in `plans/`; session narratives in `chronicles/`; anchored stances in `positions/`.

## Origin

CB was extracted and decoupled from a live operational system where the graph was built and battle-tested against real workflows. The proprietary domain data was removed; what ships here is the generic framework plus its own self-describing design graph. The codepath capability has its own origin story - it began as a standalone, cb-independent plugin and collapsed into the framework when the design discussion showed the alignment was total; the full record is in `plans/cb-codepath/` (decision record, four executed plans, and the design and execution transcripts).

## License

Licensed under the Apache License, Version 2.0 - see [`LICENSE`](LICENSE).
