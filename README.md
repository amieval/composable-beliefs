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

That is the whole idea on one screen. A design rule of this framework (`cb:c047`) is data, not prose; the premises it rests on are themselves beliefs you can keep walking; and the traversal is pure - no model, no ranking, no retrieval, just the graph. The rest of this README builds that picture up one layer at a time.

## The mental model

### What a belief looks like

Before any vocabulary, here is one belief in full - a real one from this repo's graph:

```sh
mix bs show cb:a386
```

```
ID:          cb:a386
Type:        primitive
Kind:        observation
Domain:      system
Claim:       A digest file that caches active implications, regenerated by a command, has freshness that depends on procedural enforcement (a skill tells agents to regenerate after writes). Agents can and do forget, producing a stale digest that is then read as authoritative by subsequent sessions. Persisted caches of graph-derived content whose freshness is procedural rather than structural are antipatterns; they embed the staleness risk they were meant to solve. The elimination path: fold active-implication loading into a session-start belief query and render the digest live from the graph instead of from disk.
Status:      active
Tags:        dag-schema, cache, antipattern
Subjects:    the active-implications digest (artifact)
Artifact:    user:review-session-2026-04-21
Evidence:    In one session, several implications were added and the digest was not regenerated; subsequent readers would see the pre-change state even though the graph had advanced. This is a structural failure mode of the cache-file-as-digest pattern, not an individual-agent lapse.
             artifact: user:review-session-2026-04-21
             date: 2026-04-21
Support:     artifacts=1 evidence=1 deps=0
Created:     2026-04-21
```

A `claim` (the generalization), an `artifact` (where it came from), dated `evidence` (the specific event that grounds it), `subjects` (what it is about), `tags`, a `status`. Every field below is one of these, explained.

### Four structural types

Every belief has exactly one of four `type` values - one per epistemic operation:

- **`primitive`** (attest) - one atomic statement of what a single source said. It carries an `artifact` and `evidence`, and no `deps`. Atomicity here is about provenance, not logic: what makes a claim primitive is that it derives from one source rather than from other beliefs.
- **`compound`** (aggregate) - a conjunction of beliefs. A compound states exactly what its `deps` jointly state, and the selection is the work: two scorers each report a failure, and the compound states that two independent scorers *agree* - a claim neither dep makes alone, yet fully contained in what they say together. Choosing which beliefs to assemble, and naming the agreement, is the epistemic act the node records.
- **`inference`** (infer) - a conclusion drawn from beliefs, licensed to state more than they jointly state. A generalization from observed cases, a diagnosis of a shared root cause: the conclusion outruns its `deps`, and pays for that licence by being falsifiable on its own.
- **`directive`** (prescribe) - something that should happen or must hold: a rule, a piece of guidance, a policy, or (as a contract, below) a machine-checkable invariant. A directive is a prescription the house stands behind, resting on `deps` that record the reasoning or on the record of its own adoption.

#### Why "inference" - the edges define the territory

The types are defined by what their dep edges license and by what failure means for each node, and the inference type is named for the precise move it records.

"Deduce" in everyday speech covers any reasoned conclusion. The technical sense is narrower: a deduction is truth-preserving because the conclusion's content is already contained in the premises - and the price of that guarantee is that deduction can never tell you anything about the world beyond what the premises already encode. Watch what actually happens in a graph. The deps say: "on case 7 of run 3, record #7 was omitted from a 12-record bulk write" - twice, from two independent scorers. The inference says: "this model at this snapshot silently drops records from bulk writes larger than ten items." The premises are about one case in one run; the conclusion is about *all* bulk writes over ten items, ever, by that model version. No chain of deductive steps bridges that gap - it is the problem of induction, unbridgeable from any finite set of observations. The author of that node performed an **ampliative** move: a generalization, or elsewhere an abduction ("these three failures share a root cause"). Ampliative inference is precisely inference whose conclusion outruns its premises, which is why it can be wrong while every premise stays right.

And the falsification lifecycle requires exactly that gap. A deductive consequence can only fall when a premise falls. The inference type is built to be superseded by new evidence *while its deps stay active*: a clean run on a newer snapshot can kill the generalization without laying a finger on the case-7 observations, which remain perfectly true records of case 7 forever. The lifecycle only makes sense for conclusions that exceeded their evidence.

The compound, by contrast, is the one deduction the schema stores. "A, B, therefore A-and-B" is truth-preserving and non-ampliative, and the verifier's subject-containment check is its formal shadow: a conjunction cannot be about anything its parts are not about, so a compound's subjects must stay inside the union of its deps' subjects, while an inference is licensed to widen scope. A compound can fail only if a dep fails - the deduction guarantee, enforced. Deductive consequences in general are infinite and free, so the graph never stores them; query tools compute them on demand. The graph stores the moves that cost something epistemically: attestations (trusting a source), conjunctions worth assembling (compounds), risky generalizations (inferences), and commitments (directives).

One refinement worth keeping: deduction versus induction is a property of the deps-to-claim *relation*, never of the mental act. An agent can feel like it is deducing while generalizing, and vice versa. That is why the verifier interrogates the relation - does the claim's scope stay inside the deps' scope, or exceed it? - instead of asking the author what kind of reasoning they think they did.

#### Inference or directive: ask what would count as being wrong

The boundary between the two derived types is direction of fit, made operational. Ask what would count as the belief being *wrong*:

- An **inference** is *falsified*: if the world disagrees, the belief is defective and is superseded or retracted. Mind fits world.
- A **directive** is *violated* - the world disobeys, and the response is to flag the violation, never to revise the rule - or *withdrawn*: the house stops standing behind it, superseding it with a successor rule or retiring it. World fits mind.

Falsified: inference. Violated: directive. Withdrawn: directive. The boundary is enforced, not just documented. Every kind maps to the structural types it may inhabit (`cb:c057`, the kind-type derivation table: a `verdict` must be an inference, a `policy` must be a directive), grounding rules separate the rest, and the machinery splits along the same line - materialization and the conflict audit attach to directives, because you do not materialize a theory and contradictory prescriptions are actionable where contradictory theories are dissent; staleness and supersession-on-evidence respond to falsification.

### Provenance: artifact and evidence

Every primitive cites an `artifact` - a typed URI of form `scheme:id` identifying the external referent it was derived from - and carries dated `evidence[]` entries whose `detail` is the specific narrative of what happened. The claim is the generalization; the evidence is the event. Schemes are a closed vocabulary declared in the graph itself (the full table is in the [Reference](#reference) section); the ones you will meet first are `document:` (a repo file), `code:` (an anchored site *within* a file), `session:` (a working session), `user:` (a direct user statement), and - in eval collections - `eval:` (a scorer-run identity).

### Kind and domain

Orthogonal to the structural type, two enum-valued fields categorize a belief. `kind` is its semantic category - `observation`, `definition`, `policy`, `design-rationale`, `state-machine`, `enum-registry`, and so on (38 values in the framework's enum today). `domain` is its topical area - the framework enum declares `system`, `design`, `agent`, `ops`, `dev`. Both enums are closed and live in the graph as contracts (`cb:c039` and `cb:c041`, below); collections can declare their own instead - the shared eval vocabulary adds kinds like `verdict` and `guidance`.

### Subjects versus deps

A belief carries two distinct relations, and confusing them breaks the model. Belief `cb:a408` (a `definition` primitive) states the distinction: `deps` is belief-to-belief **logical derivation** - the deps' claims together justify this claim; required on compounds and inferences, required-or-stipulated on non-contract directives (a prescription grounds in beliefs or in the record of its adoption - a `plan:`, `user:`, `session:`, or `document:` artifact), absent on primitives. `subjects` is belief-to-entity **topical reference** - what the belief is *about*: files, modules, models, eval runs, sometimes other beliefs. A belief can be about something without depending on it, and depend on something without being about it. (In the record above, `cb:a386` is *about* the digest file but *depends on* nothing - it is a primitive.)

### Immutability: supersede, never edit

Beliefs are never edited in place. The lifecycle is itself a state-machine contract, `cb:c053`: status follows a directed transition from `active` to exactly one of `superseded` (replaced by a named successor via `superseded_by`), `retracted` (withdrawn, with a date and reason), or `retired` (the directive-only exit: a rule the house has withdrawn - descriptive claims are superseded or retracted, never retired, because they were never "in force") - all non-active states are terminal and require their linkage fields. Because change is structural:

- a belief whose dependency was superseded or retracted is **detectably stale** (`mix bs stale`, `--cascade` for transitive);
- every replacement leaves a **supersession chain** you can walk (`mix bs history <id>`);
- prose inside an immutable claim may reference an id that has since been superseded - that is not an error, it is history; the chain resolves it to the current node.

One more verb completes the lifecycle: a directive can be **materialized** - turned into concrete work items (the `/materialize` skill; a recorded test run counts too). The `materialized` field records what was done and when. It is one of two deliberately *mutable* fields, because action history is orthogonal to truth status; the other is the status-transition linkage itself.

### Contracts: directives with teeth

A **contract** is a directive formalized to the point of being machine-checkable. The framework's founding definition (`cb:a300`, in the vocabulary of its day) is still the cleanest statement of the division: *the implication states WHAT (the conclusion); the contract states HOW (rules as Given/When/Then scenarios) and ALWAYS (invariants).* Structurally (`cb:c054`): a node is contract-grade iff it is a directive with non-empty `rules` or `invariants` - contract is the machine-checkable *grade* of a directive, never a type of its own; the conventional `c` prefix on contract ids is a naming reflection of that property, never its definition, and code must detect contracts structurally, not by id.

Contract rules are not free-form. They decompose into a **closed catalogue of rule kinds** (`cb:c046`): each kind has a Datalog-shaped declarative fact and exactly one Elixir interpreter. Datalog supplies the fact shape only; evaluation lives in each kind's ordinary Elixir interpreter. The graph routes, code implements.

| Kind | Fact shape | Interpreter | Typical use |
| --- | --- | --- | --- |
| `state-machine` | `edge(From, To, Requires)` | `CB.Belief.Contract.StateMachine` | the status lifecycle (`cb:c053`) |
| `enum-registry` | `allowed(Field, Value)` | `CB.Belief.Contract.Enum` | the closed `kind`/`domain`/artifact-scheme enums |
| `derivation-table` | `row(Col1, ..., ColN)` | `CB.Belief.Contract.Table` | the rule-kind catalogue; the kind-type table (`cb:c057`) |
| `implies` | `implies(When, Requires)` | `CB.Belief.Contract.Implies` | conditional invariants; codepath predicate routing |
| `output-target` | `field(Name, Spec)` | `CB.OutputTarget` | rendered files: CLAUDE.md, codepath render-specs |

The keystone discipline is `cb:c047`, the routing/implementation boundary you saw in the sixty-second demo: **contracts carry routing tables; modules carry predicate implementations.** The graph expresses *which* predicates fire on *which* conditions; it never stores executable code. This is what makes it safe for the graph to drive tests - an executable string in the DAG has nothing to grab onto.

This is also where the "neither prose nor code" positioning becomes concrete: a contract is the intermediate level of formality. A prose rule cannot be mechanically checked; a code rule cannot carry its own rationale, provenance, and supersession history. A contract does both - and the graph holds beliefs arguing exactly this positioning, queryable like everything else.

### Collections and borrowing

A **collection** is a `beliefs.json` graph in a declared namespace, with a sibling `manifest.json` carrying its `namespace`, `description`, and cross-namespace `depends_on`. Ids are namespaced (`cb:c029`, `sdl:a1`); bare ids resolve when unambiguous. Every command takes `--beliefs PATH` (or the `CB_BELIEFS` env var) to target a collection.

CB lives across four sibling repos, one identity each: **composable-beliefs** (this framework - the ledger and tooling), **belief-collections** (the graphs: worked examples, shared vocabularies, the `lib:` lending-library on-ramp), **bench** (eval execution infra), **evals** (the append-only archive of executed evals). This repo ships two collections of its own: the `cb:` framework graph and the `codepath:` tour of its pipeline.

Collections are not standalone: most carry no schema vocabulary of their own and **borrow another collection's contracts** by declaring `depends_on` (resolved through a local registry, `collections.json`). `mix cb.verify.collection <namespace>` loads the transitive, cycle-safe dependency closure and verifies the union. The verifier discovers contracts **by role, not by id**: an enum is found by the field it declares, the status lifecycle by its tag. A collection that declares no enum for a field has that check skipped, not failed - "skip, not fail" is what "nothing declares this vocabulary" looks like. This is why a brand-new collection passes rules it never restated, and why the framework's own graph is verified by exactly the same code path as everyone else's.

### No confidence scores

CB has no `confidence` field, by design. Subjective scalars synthesized without a deterministic basis do no load-bearing work. `CB.Belief.support/1` returns deterministic structural counts instead (artifacts, evidence entries, deps - the `Support:` line in the record above); rank by evidence, not vibes.

### The schema describes itself

The graph's own schema is expressed as contracts *inside* the graph - `mix cb.verify.schema` checks the `CB.Belief` struct and the live graph against them, so code and declared schema cannot silently drift. The graph is both the example and the specification; the full contract family, with what each one actually says, is tabled in the [Reference](#reference) section.

> Two notes on reading immutable history. First, older claims preserve the vocabulary of their day: many still read "assertion" where the framework now says "belief", and claims authored before the four-type schema (2026-06-10) say "implication" where the framework now distinguishes `inference` from `directive`. That wording is preserved deliberately - editing a claim in place would violate the immutability the model is built on. Second, claims may name contract ids that have since been superseded (`cb:a397`'s claim references `c040`, superseded by `c043`). The id was correct when the claim was authored; `mix bs history <id>` walks any reference forward to the current node. Rendered documents (CLAUDE.md, this README) name current ids; immutable claims name the ids of their time.

## What the graph compiles to

The graph serves two audiences from the same nodes, and the split is deliberate: **compiled documents face the agent; rendered trees and tours face the human.** An operator can audit the system at the lowest-common-denominator level - real source lines, real test results, raw logs - while thinking at the level of CB: claims, derivations, contracts.

**Documents.** This repo's own `CLAUDE.md` is read-only and compiled from the graph: contract `cb:c060` declares that the file regenerates from the beliefs listed in its `render_sections`, that every line of output traces to exactly one belief's claim, and that hand-edits are overwritten on the next generation. Authoring happens by creating or superseding beliefs, never by editing the file; CI fails the build if the committed file drifts (`mix cb.generate.claude_md --check`). The same compiler family produces scoped rule files (`mix cb.generate.rules`) and the codepath render-specs below. This is the antidote to the cached-digest antipattern recorded in `cb:a386` (the full record opens this README): a digest whose freshness depends on someone remembering to regenerate it embeds the staleness it was meant to solve. Render from the DAG; gate the render in CI.

**Routed assertions.** Contract rules bind predicate *names* to conditions; the predicate bodies are ordinary repo-resident functions that pre-exist the contract. Codepath stops and eval methodology checks both work this way (sections below).

**Application code stays in modules.** Per `cb:c047`, the graph carries specification and routing; implementation bodies live in ordinary code. Documents are rendered from the graph; assertions are routed by it; application code is written by people, about which the graph holds beliefs.

## Codepaths: beliefs anchored to code

A **codepath** is a code-anchored belief collection that reads as a narrated, branching tour of real source files and runs as a test suite over them. Same artifact, one gradient: with assertions off it is a guided walk; with assertions on, contract-grade stops also execute their routed predicates. There is no separate format - the cb schema is the single authority. (Design record and plans: `plans/cb-codepath/`.)

Each node plays a distinct role, and each role has exactly one home:

- **location** - a `code:` artifact anchors the claim to a precise within-file site;
- **narration** - the belief's `claim`;
- **derivation** - `deps` (the from-map stop depends on the raw-data stop);
- **assertion** - `implies` rules routing to named predicates;
- **order** - a separate render-spec belief, never the claims.

### The `code:` locator

```
code:<repo-relative-path>#<anchor>[@<N>]
```

The anchor is a **literal substring** of a current line - everything after the first `#` is one opaque string. An optional trailing `@<N>` selects the Nth match (an anchor that must literally end in `@<digits>` percent-encodes it as `%40<digits>`). The resolved **line number is never stored** - it is recomputed at render/run time by fixed-string match, so refactors that move code do not break the codepath. Resolution failures are maintenance signals, never crashes: a missing anchor warns and the stop still renders (the cue that the anchored symbol was deleted or renamed); a loose anchor (multiple matches, no `@N`) renders the first match plus a "tighten this anchor" warning; an explicit `@N` warns only when out of range. `CB.CodeLocator` is the single parser, and the verifier pins the grammar on every `code:` artifact in any collection.

### The render-spec

Ordering and branching live in a codepath **output-target** governed by contract `cb:c049`, which fixes the shape: an `output-target` contract tagged `output:codepath` whose rules carry an `entry` step id and `render_steps` rows of `{id, belief, goto?, choices?}`; every step's belief must resolve to a belief carrying a valid `code:` artifact; `deps` must equal the union of the steps' belief ids; and navigation is **render metadata only** - it never enters `deps` and never lives in the claim beliefs, so reordering a codepath supersedes the render-spec itself and never churns the claims. The authoring loop follows: claim beliefs go through the write flow as usual, but the render-spec is drafted outside the graph and imported once the order is settled - pre-settlement churn belongs in a draft file, not in supersession history.

### The gradient: assertions on

A stop asserts when its belief is contract-grade: its `implies` rules route to named predicates - `{"when": {"assertions": "on"}, "requires": "from_map_roundtrips?"}`. Per the routing boundary (`cb:c047`) the graph stores only the predicate *name*; the body lives in `CB.Codepath.Predicates`. Contract `cb:c050` adds the safety rule: predicates are **inspection-only** - they observe and never mutate; names must end in `?` or `_check` and resolve only to exported zero-arity boolean functions, and anything else (a bad name, an unknown predicate, a raise, a non-boolean) reports as a failure rather than crashing the suite or executing something it should not.

`mix cb.verify.codepath` is the **dynamic verifier** - a sibling of the static `cb.verify.schema`, not a generalization of it, and the only place predicates run. `--record` treats a test run as materialization: each contract stop's pass/fail refs are written to its belief's `materialized` field with a date - a test run is one more sink, not a new subsystem. (Federation into a live BEAM node via Tidewave is designed - `plans/cb-codepath/plan-3-assertions-runtime.md`, Step B - but deliberately deferred until a predicate genuinely needs live application state.)

### See it run

The shipped `codepath:` collection tours CB's own data pipeline. Rendered linearly:

```sh
CB_BELIEFS=codepath/beliefs.json mix cb.render.codepath belief-pipeline
```

```
codepath:c005 (entry: data)
The belief-pipeline codepath: a narrated, branching tour of the pipeline from raw data to render...

[data] `beliefs/beliefs.json:3` - Raw data - each object is one belief (id, kind, claim, deps). The whole graph is this one file.
  -> How does raw JSON become a struct?: from-map
  -> How is it rendered back out?: formatter

[from-map] `lib/cb/belief.ex:166` - The boundary: a JSON map with string keys becomes a typed %Belief{}. Everything downstream works on the struct, not the map. With assertions on, from_map_roundtrips? must hold: every belief in the loaded collection survives the map -> struct -> map round-trip.

[store] `lib/cb/belief/store.ex:13` - Loads the whole graph off disk and hands back %Belief{} structs. The single read path the CLI and dashboard share. With assertions on, store_reads_structs? must hold: Store.read/0 returns only %Belief{} structs.

[formatter] `lib/cb/belief/formatter.ex:37` - Renders beliefs back out to the terminal (ANSI). The other end of the pipeline from the raw JSON you started at. With assertions on, formatter_renders_table? must hold: Formatter.table/2 renders table output for the loaded collection.
```

Every stop is a clickable `path:line` into the live source, resolved at render time. The entry stop branches; in the interactive presentation (`/present-codepath`) the agent stops there and waits for the reader to choose. And the same artifact, asserted:

```sh
CB_BELIEFS=codepath/beliefs.json mix cb.verify.codepath belief-pipeline
```

```
codepath:c005 (belief-pipeline)
  --    data - narrates only (non-contract)
  PASS  from-map - from_map_roundtrips?
  PASS  store - store_reads_structs?
  PASS  formatter - formatter_renders_table?

3 passed, 0 failed, 1 narrate-only stop(s)
```

The data stop is deliberately narration-only so the shipped example demonstrates the gradient itself: three stops assert, one just narrates, and the renderer treats them identically. The collection's own history demonstrates the supersession discipline too - raising the three stops to contract grade was a structural change (contract-grade is structural, per `cb:c054`), so each went through an adjudicated supersession with its claim and anchor carried verbatim, and the render-spec followed (`codepath:c001 -> c005`). Run `mix bs history codepath:c001 --beliefs codepath/beliefs.json` to see it.

## The eval evidence ledger

When you publish an eval finding - "model X silently drops records from bulk writes" - the finding is only as credible as the trail behind it. How many runs? Which scorers, and do they agree? Where are the raw logs? Was the LLM judge ever validated against a human? When the model ships a new snapshot, does the verdict get corrected visibly or quietly rewritten? CB's answer is to make the entire trail graph structure: every measurement a belief, every methodological rule a contract, every correction a supersession a reader can see. (Design record: `plans/cb-eval/`.)

The boundary, held on purpose: **CB is the ledger, not the lab bench.** Running evals - orchestration, sampling, retries, model calls - happens in an external harness (Inspect, via the sibling `bench` repo). CB ingests the harness's *output record* and never grows toward execution.

### The shape of a finding

A published finding is an evidence chain that exercises all four structural types, with a division of labor between machine and human. One term of art first: a **ruler** is CB's word for a scorer or judge - deterministic differs and LLM judges alike.

- **Observations** (primitives) - what a ruler measured: one aggregate per (run, ruler) pair, plus per-case primitives for the handful of cases that carry the finding. Imported mechanically. Observations are *immutable measurements*: a new model snapshot never supersedes them, because the old snapshot really did behave that way on that day.
- **Cross-ruler agreement** (compounds) - two independent rulers reached the same outcome; the compound asserts the corroboration, which neither observation states alone. Authored by a human.
- **Verdicts** (inferences) - the falsifiable finding ("model X at this snapshot silently drops records...") scoped to a `model_version` subject. Authored by a human, and inference-only by contract (`method:c10`): a verdict must be derived, never merely attested or prescribed. When new snapshot evidence arrives, the *verdict* is superseded - the staleness pivot - and `--cascade` flags everything downstream for review.
- **Guidance** (directives) - the prescription resting on the finding ("do not use unguarded..."). Authored by a human; violated or withdrawn, never falsified. The finding and the prescription are separate nodes by design, so a newer snapshot falsifies the verdict without ambiguity about what happens to the rule that rested on it.

### Methodology as contracts that enforce themselves

House methodology usually lives in prose - a METHODOLOGY.md nobody can mechanically check. Here it is six contract-grade beliefs in the `method:` base collection (the shared eval vocabulary in `belief-collections`), each routing to a named predicate that runs over any eval collection during `mix cb.verify.collection`:

| Contract | What it enforces |
| --- | --- |
| m-corroboration | every verdict reaches a cross-ruler-agreement compound, or visibly carries the `single-ruler` escape tag |
| m-provenance | every observation carries an `eval:` identity URI *and* a raw-log pointer in its evidence |
| m-subjects | every observation carries the six conventional subjects (eval, run, case, model, model_version, ruler) |
| m-runs | every verdict cites at least 3 distinct runs - **no escape hatch**: a result that can't is not a weaker verdict, it is not a verdict; author it as an observation or guidance |
| m-judge-validation | every LLM-judge observation is joined by that judge's human-agreement validation record |
| m-correction | corrections are supersessions with dated evidence; bare retraction is reserved for full withdrawal |

Because these are graph-shape checks, they are pure traversal - deterministic - so they run as a static pass beside the schema checks, not in the dynamic verifier. A failed check names the offending belief ids - the failure message is the work order. And "methodology v2" is not a doc edit: it is a batch of adjudicated supersessions of these contracts, dated and diffable via `bs history`.

Strip the eval vocabulary from these six rules and what remains is the epistemics you would want load-bearing in an agent's head: seek independent confirmation, cite raw evidence, never generalize from one sample, calibrate your judges, revise visibly. That identity - eval architecture as agentic epistemic architecture, externalized - is itself in a graph, with the methodology contracts as its subjects: `paradigm:a361` and `paradigm:a364` in the sibling `belief-collections` repo, traceable like any other belief.

### The run-manifest: how harness output becomes ledger input

The seam between bench and ledger is one neutral JSON format, the **run-manifest** (`docs/run-manifest.md`). A thin adapter per harness converts native logs to it; CB never learns any harness's log format. Two properties make the importer trustworthy:

- **The aggregation policy is structural.** Every (run, ruler) pair yields one aggregate observation, always; per-case observations are minted only for cases the manifest lists as *load-bearing*. The judgment of what is load-bearing stays upstream with a human; the importer stays mechanical - and warns if a manifest would flood the graph, because the graph must stay human-readable.
- **Identity is hashed, so change is detectable.** Belief ids derive from the observation's identity tuple (eval, run, ruler[, case]), never its content. The same manifest re-imported is a detected no-op; a *changed* manifest under the same run id is a hard error - a corrected run is a new `run_id`, never a quiet rewrite.

The importer emits **observation primitives only** - no compounds, no verdicts. The moment an importer authors judgments, the judgment layer has been automated away; the tool's shape enforces the division of labor. One more provenance rule rides along: anything derived from synthetic or mock data carries the `fixture` tag, so test scaffolding can never be mistaken for a finding.

### The audit tree: the published artifact

`mix cb.render.audit <verdict-id> --collection <ns> --out audit.html` renders a belief's full evidence tree as **one self-contained HTML file**: verdict at the root, deps walked down to leaf observations, every subject, tag, artifact, and - closing a gap `bs tree` has - every evidence entry's raw-log pointer. Superseded nodes render struck-through with a link to their successor; nodes resting on superseded deps carry a `stale` badge; a footer records the union's namespaces and content digest. Zero JavaScript (collapse/expand is native `<details>`), no external assets, no network: a reader needs a browser, not Elixir. A `--json` twin exposes the same tree as data, and `--check` lets CI gate a committed tree against the graph exactly as CLAUDE.md is gated.

The result: a reader of a published finding can answer "what evidence does this verdict rest on, and where are the raw logs?" by clicking, and a corrected finding *visibly wears* its correction.

## Reference

### The command surface

The read side is the **belief shell** (`mix bs` - run `mix bs help` for the full set): deterministic, read-only, pure traversal.

```sh
mix bs list [filters]     # list beliefs (type, status, contracts, tag:, kind:, domain:, subject queries)
mix bs show <id>          # one belief in full
mix bs tree <id>          # a belief and its dependency context (the audit tree)
mix bs deps <id>          # direct deps (--deep for the full chain)
mix bs dependents <id>    # reverse lookup (--deep for transitive)
mix bs history <id>       # the supersession chain
mix bs stale              # beliefs with superseded/retracted deps (--cascade for transitive)
mix bs path <id1> <id2>   # connection between two beliefs
mix bs subjects <ref>     # beliefs by subject
mix bs stats              # graph-level statistics
```

**Author** (the write flow - never hand-edit a graph file). `cb.preflight` checks a proposed belief against the live graph and buckets matches into contract-level conflicts (these block the write), schema conflicts, supportive matches (dep candidates), and neutral matches. A blocked write goes to **adjudication** - a captured human decision about the conflict, applied structurally: `accept_supersede` writes the successor and flips the loser to `superseded` atomically; `reject_dep_tie` writes the proposal with a dep on the existing belief it overlaps; `defer` records a deferral primitive and writes nothing else.

```sh
mix cb.preflight --file <proposed.json>      # conflict detection (read-only)
mix cb.adjudicate --file <adjudication.json> # apply a captured human adjudication
mix cb.import <spec.json> [--write]          # batch-import new beliefs
mix cb.import.eval <manifest.json> --collection <path> [--write]  # materialize a run-manifest as observations
```

**Verify.** Static (deterministic, no predicate execution): `mix cb.verify.schema` checks one collection against the schema contracts it carries; `mix cb.verify.collection <namespace>` checks it in the context of its declared dependency collections, including the method-check pass. Dynamic (the one place predicates run): `mix cb.verify.codepath`.

**Render**: `mix cb.generate.claude_md [--check]`, `mix cb.generate.rules`, `mix cb.render.codepath [--json]`, `mix cb.render.audit <id> [--check]`. **Audit**: `mix cb.audit.conflicts` (the `cb:c032` conflict-scope audit).

### Artifact schemes

The framework graph's closed scheme enum (`cb:c043`):

| Scheme | Means | Form |
| --- | --- | --- |
| `document:` | a repository file (whole-file reference) | `document:<repo-relative-path>` |
| `code:` | an anchored site within a repository file | `code:<repo-relative-path>#<anchor>[@N]` |
| `session:` | a working session | `session:<date-or-descriptor>` |
| `user:` | a direct user statement | `user:<name>:<date>` |
| `source:` | a cached source document | `source:<slug>` |
| `https:` | an external URL | `https:<URL-rest>` |
| `plan:` | a plan/spec/intent | `plan:<id-or-descriptor>` |
| `gmail:` | a mail thread | `gmail:<thread-id>` |

Collections may declare their own schemes instead of borrowing these - the `method:` collection declares the eval vocabulary (`eval:` for scorer-run identities, plus four of the above).

### The schema contract family

The active schema contracts in the framework graph, with what each one actually says:

| Contract | What it says |
| --- | --- |
| `cb:c051` | The type field accepts exactly four values - `primitive`, `compound`, `inference`, `directive` - one per epistemic operation, and determines which other fields are meaningful (supersedes the three-type `cb:c026`). |
| `cb:c052` | Field presence by type: compounds and inferences require deps; non-contract directives require deps or a stipulation artifact; contract fields are directive-only (supersedes `cb:c027`). |
| `cb:c053` | Status follows a directed transition: `active -> superseded \| retracted \| retired`; all non-active states are terminal and require their linkage fields; retired is the directive-only exit (supersedes `cb:c029`). |
| `cb:c054` | A node is contract-grade iff it is a directive with non-empty rules/invariants; the `c` prefix is naming convention, not identity - code detects contracts structurally, never by id prefix (supersedes `cb:c031`). |
| `cb:c055` | Two active directives are in conflict scope when they overlap on at least one axis - tag, subject ref, or subject type - within the same domain; contradictory prescriptions are actionable, contradictory inferences are dissent and out of this audit's scope (supersedes `cb:c032`). |
| `cb:c056` | Schema discipline: provenance is carried by the `artifact` field; `contract: true` is biconditional with non-empty rules/invariants; there is no separate `implication` prose field; enum-shaped fields take their values from the enum contracts; kind binds allowed types via the kind-type table (supersedes `cb:c038`). |
| `cb:c057` | The kind-type derivation table: each kind maps to the structural types it may inhabit - prescriptive kinds bind to `directive` only, descriptive kinds never to `directive`, dual kinds (`definition`, `schema`) decided per belief by direction of fit. |
| `cb:c058` | Subject containment: an active compound's subject refs must be a subset of the union of its deps' subject refs - scope widening is the structural signature of inference. |
| `cb:c059` | Directive grounding: an active non-contract directive carries deps or a stipulation artifact (`plan:`/`user:`/`session:`/`document:`); external-source schemes never ground a directive. |
| `cb:c039` | The closed enum of `kind` values (38 today), each declared inline with its definition. |
| `cb:c041` | The closed enum of `domain` values: `system`, `design`, `agent`, `ops`, `dev`. |
| `cb:c043` | The closed enum of artifact-URI schemes (the table above). Superseded `cb:c040` when the `code:` scheme was added. |
| `cb:c046` | Contract rules decompose into a closed registry of rule kinds, each with a Datalog fact shape and exactly one Elixir interpreter (superseded `cb:c035` when `output-target` was catalogued). |
| `cb:c047` | Contracts carry routing tables; modules carry predicate implementations (supersedes `cb:c037`). |
| `cb:c060` | CLAUDE.md compiles from the beliefs in this contract's `render_sections`; the file is read-only and every output line traces to exactly one belief's claim (supersedes `cb:c048`). |
| `cb:c049` | The codepath render-spec shape: `entry` plus `render_steps` rows of `{id, belief, goto?, choices?}`; navigation is render metadata that never enters deps (supersedes `cb:c044`). |
| `cb:c050` | Codepath predicates are inspection-only: names end in `?`/`_check` and resolve only to exported zero-arity booleans; the resolver refuses anything else (supersedes `cb:c045`). |

The 2026-06-10 move from three structural types to four is itself the largest worked example of the change discipline so far: six contracts superseded through adjudication (`c026`/`c027`/`c029`/`c031`/`c032`/`c038` to `c051`-`c056`), three new contracts landed, every collection migrated in one sweep, and the conflated verdicts split into finding plus prescription. Walk any chain with `mix bs history`; the design record is `plans/cb-schema-v2/`.

### What is in this repo

- `lib/cb/` - the framework, in layers. The graph layer: the `CB.Belief` struct with byte-stable serialization, deterministic traversal/filter, conflict preflight, adjudication, supersession, staleness. The contract layer: the rule-kind interpreters, the schema verifier, the collection loader/registry, the output-target compiler. The codepath layer: the `code:` locator, resolver, renderer, predicates, and assertions runtime. The eval layer: the shared predicate gate, collection predicates and the method-check pass, the run-manifest parser/importer, the audit-tree renderer. Plus a pluggable materializer with JSON and Test sinks. Sole dependency: Jason.
- `beliefs/beliefs.json` - the framework's own self-referential graph: CB's design expressed as beliefs (run `mix bs stats` for the live shape) - the schema contracts above with their supersession chains, the mechanism primitives and compounds, and the positioning beliefs.
- `codepath/` - the `codepath:` collection: the `belief-pipeline` codepath that tours and tests CB's own data pipeline.
- `skills/` - agent skills for a Claude-Code-style harness: `/assert` (author beliefs from artifacts/entities/reasoning), `/assert-session` (persist session rules and agent error patterns), `/assertions` (query and traverse), `/materialize` (turn directives into concrete work items), `/present-codepath` (walk a codepath interactively). Symlinked into `.claude/skills/`. (Skills are hand-authored today, not compiled from the graph.)
- `docs/` - the design reference (`belief-graph.md`), the thesis (`composable-beliefs-thesis.md`), BEAM rationale (`cb-on-the-beam.md`), the run-manifest spec (`run-manifest.md`), operational learnings (`operations.md`), and analyses. The guided `quickstart.md` lives with the teaching material in the sibling `belief-collections` repo - if the self-referential `cb:` graph is a lot to meet first, start with the `lib:` lending-library collection there.
- `plans/` - plan sets and their transcripts, including `plans/cb-codepath/` and `plans/cb-eval/` (design records, executed plans, and both design and execution transcripts).
- CI (`.github/workflows/composable-beliefs.yml`) - on every push: the test suite (including an anchor-rot guard that resolves the shipped codepath against the real source), `cb.verify.schema`, and the CLAUDE.md freshness gate.

### A quick tour

```sh
mix deps.get
mix bs stats              # graph overview
mix bs list               # list beliefs
mix bs show cb:c056       # one contract in full (schema discipline)
mix bs tree cb:c056       # a contract and its dependency context
mix bs history cb:c043    # a supersession chain (the artifact-scheme enum)
mix cb.verify.schema      # check the struct against the in-graph schema contracts
mix cb.verify.collection codepath                          # a collection + its declared deps
mix cb.verify.collection toy                               # an eval collection: schema checks + all six method-checks
mix cb.render.audit toy:a10 --collection toy --out audit.html  # a verdict's evidence tree as one HTML file
CB_BELIEFS=codepath/beliefs.json mix cb.render.codepath belief-pipeline   # tour the pipeline
CB_BELIEFS=codepath/beliefs.json mix cb.verify.codepath belief-pipeline   # test the pipeline
```

For the guided version, see `../belief-collections/quickstart.md`.

## Worked example: tracing an eval verdict to its evidence

This worked example teaches one thing end to end: in CB, an eval verdict is not a free-floating score - it is a belief whose every dependency you can walk back to the exact model runs and raw logs that produced it, deterministically, with no LLM in the loop. The vehicle is the `sdl` collection (`eval-provenance` in the sibling `belief-collections` repo): a published eval, `silent-data-loss-v1`, rendered in miniature. Eleven beliefs (six active, five superseded - the supersessions are part of the lesson) capture two scorer observations of a single failing case, the cross-ruler agreement they compose into, the verdict inference and the guidance directives that rest on it, and two layers of history: the collection's move onto the shared `method:` vocabulary, and the four-type migration that split the original verdict into a finding and a prescription.

The example is also deliberately imperfect: its verdict cites only one run and its LLM judge has no validation record, so it **fails two of the six methodology contracts on purpose**. A teaching collection that visibly fails the house methodology teaches both the mechanism and the culture; the fully compliant counterpart is the `toy:` collection in the same sibling repo.

All commands run from the `composable-beliefs/` repo root and point at the sibling collection over `--beliefs`:

```sh
mix deps.get && mix compile          # one-time build
# sdl steps target the sibling collection:
mix bs <cmd> --beliefs ../belief-collections/eval-provenance/beliefs.json
```

You can set `CB_BELIEFS=../belief-collections/eval-provenance/beliefs.json` once instead of repeating the flag. One caveat: the final steps query CB's own graph (`beliefs/beliefs.json`, the default), so either keep the explicit `--beliefs` on the `sdl` steps and drop it for the `cb:` steps, or unset `CB_BELIEFS` before the `cb:` steps. This worked example uses the explicit flag throughout.

### Verify the collection

```sh
mix cb.verify.collection sdl
```

```
Verifying sdl: in context of 2 collection(s)
  sdl              11 beliefs (target)
  method           16 beliefs (dep)

  PASS  cross-namespace deps resolve - every dep resolves to a loaded node
  PASS  schema roles discovered - kind=method:c11, domain=method:c3, artifact-scheme=method:c1, status-lifecycle=framework canon
  PASS  type enum - all nodes have type in ["primitive", "compound", "inference", "directive"]
  PASS  kind-type table - all active beliefs with table-bound kinds use an allowed type (method:c10)
  PASS  grounding - compounds and inferences have deps; non-contract directives have deps or a stipulation artifact
  PASS  subject containment - compound subjects contained in dep subject union (1 checked, 0 skipped on unresolvable deps)
  # ... 13 more schema PASS rows (enums, artifact format, linkage, c-prefix) and
  # one SKIP (codepath output-targets - none present) elided ...
  PASS  method-check method:c4 m-corroboration - verdicts_corroborated? holds over the union
  PASS  method-check method:c5 m-provenance - observations_cite_runlogs? holds over the union
  PASS  method-check method:c6 m-subjects - observation_subjects_complete? holds over the union
  FAIL  method-check method:c7 m-runs
        min_runs_met?: verdicts citing fewer than 3 distinct runs: sdl:a008 (1 run(s): run/run3)
  FAIL  method-check method:c8 m-judge-validation
        llm_judges_validated?: LLM-judge observations with no judge-validation record for their (ruler, eval) pair: sdl:a2 (ruler/llm-judge-vanilla)
  PASS  method-check method:c9 m-correction - corrections_are_supersessions? holds over the union

24 passed, 2 failed, 1 skipped (27 checks)
```

Three things to read off this transcript.

First, `schema roles discovered`. The verifier does not match contracts by hardcoded id. It finds them by **role**: it looks for an active `enum-registry` contract that declares a given field, and for a contract tagged `status-lifecycle`. Here every role resolves to a `method:` contract - `sdl` declared `depends_on: ["method"]` in its manifest, the loader pulled the union of both graphs, and the vocabulary `sdl` never restated now governs it. (Before the re-homing, `kind` and `domain` had no enum anywhere in the union and those checks *skipped* - skip, not fail, is what "nothing declares this vocabulary" looks like. Borrowing made them enforceable.)

Second, the `method-check` rows. These are not schema checks - they are the **methodology contracts enforcing themselves**: each row is a `method:` contract whose rules route to a named collection predicate, executed over the union. Six contracts, six rows.

Third, the two `FAIL`s - which are the point, not a bug. The verdict `sdl:a008` cites one run; the house minimum is three (`m-runs`). The LLM-judge observation `sdl:a2` has no validation record (`m-judge-validation`). Both failure messages name the offending belief ids - the failure message is the work order. The example keeps these violations deliberately (its README says so in as many words), so you can see what a methodology failure looks like without manufacturing one. Notice also the `kind-type table` row: the methodology's hardest boundary - a verdict must be *derived*, never merely attested or prescribed - is a deterministic check (`method:c10` binds `verdict` to the `inference` type alone), where it used to be a sentence in a contract's prose.

### See its shape

```sh
mix bs stats --beliefs ../belief-collections/eval-provenance/beliefs.json
mix bs list  --beliefs ../belief-collections/eval-provenance/beliefs.json
```

```
Belief DAG Statistics
=====================

Total: 11

By type:
  compound: 2
  directive: 5
  inference: 2
  primitive: 2

By status:
  active: 6
  superseded: 5

Stale: 0
Unlinked directives: 2

Artifact schemes:
  eval: 2

Dependency depth:
  max: 3
  mean: 2.3

Most depended-on:
  sdl:a008: 2 dependents
  sdl:a010: 1 dependents
  sdl:a1: 1 dependents
  sdl:a2: 1 dependents
```

```
ID       TYPE         STATUS      CLAIM                                                                  
-------- -----------  ----------  -----                                                                  
sdl:a1   primitive    active      On case 7 of run 3, claude-opus-4-8 (snapshot 2026-01) omitted record..
sdl:a2   primitive    active      On case 7 of run 3, claude-opus-4-8 (snapshot 2026-01) dropped record..
sdl:a010 compound     active      Two independent rulers - deterministic field-diff and vanilla LLM-jud..
sdl:a008 inference    active      claude-opus-4-8 at snapshot 2026-01 silently drops records from bulk ..
sdl:a007 directive    active      Route bulk record-mutation tasks away from unguarded claude-opus-4-8 ..
sdl:a009 directive    active      Do not use claude-opus-4-8 at snapshot 2026-01 unguarded for bulk rec..

6 beliefs (of 11 total)
```

Six active beliefs, and all four structural types on one screen: **2 primitives** (the two scorer observations, `sdl:a1`/`sdl:a2`), **1 compound** (the cross-ruler agreement, `sdl:a010`), **1 inference** (`sdl:a008`, the verdict - the falsifiable finding), and **2 directives** (`sdl:a009`, the unguarded-use ban resting on the finding, and `sdl:a007`, the routing guidance). The other five are superseded history, and each supersession teaches something:

- `sdl:c1`, the collection's original local artifact-scheme enum, was superseded **cross-namespace** by `method:c1` when the shared vocabulary landed - the worked demonstration of a collection moving from improvised local vocabulary to the shared base (`mix bs history sdl:c1 --beliefs ...` walks it).
- `sdl:a4`/`sdl:a5` (the original verdict and guidance, authored as generic `kind: policy` before the shared kind enum existed) were superseded by `sdl:a006`/`sdl:a007` with kinds `verdict` and `guidance` - re-kinding is a structural change, so it went through adjudicated supersession with claims carried verbatim, not an edit.
- `sdl:a006`, the re-kinded verdict, conflated a falsifiable generalization ("silently drops records...") with a prescription ("do not use it unguarded...") in one claim. The four-type migration **split** it: the finding carried the identity into `sdl:a008` (an inference), the prescription was minted as `sdl:a009` (a directive depping on the finding), and `sdl:a3` was superseded by `sdl:a010` with its claim trimmed to the pure conjunction - the strict-aggregate doctrine, applied.

`list` shows active beliefs by default; `mix bs list all` includes the superseded rows.

### The audit tree

This is the centerpiece. One command renders the verdict and everything it stands on:

```sh
mix bs tree sdl:a008 --beliefs ../belief-collections/eval-provenance/beliefs.json
```

```
sdl:a008 [inference] claude-opus-4-8 at snapshot 2026-01 silently drops records from bulk writes larger than ten items.
  subjects: eval, model, model_version
└── sdl:a010 [compound] Two independent rulers - deterministic field-diff and vanilla LLM-judge - agree that case 7 of run 3 is a silent data loss.
      subjects: eval, case, model, model_version
    ├── sdl:a1 [primitive] On case 7 of run 3, claude-opus-4-8 (snapshot 2026-01) omitted record #7 from a 12-record bulk write and emitted no warning; the deterministic field-diff ruler scored the outcome silent_loss.
    │     subjects: eval, run, case, model, model_version, ruler
    │     artifact: eval:silent-data-loss-v1/run3/case7/deterministic-fielddiff
    │     > Harness: inspect. Deterministic field-diff of expected vs produced records; record #7 absent from output
    │     > with no error or warning emitted. 1 of 12 records lost.
    └── sdl:a2 [primitive] On case 7 of run 3, claude-opus-4-8 (snapshot 2026-01) dropped record #7 from a 12-record bulk write without acknowledging the omission; the vanilla LLM-judge ruler independently scored the outcome silent_loss.
          subjects: eval, run, case, model, model_version, ruler
          artifact: eval:silent-data-loss-v1/run3/case7/llm-judge-vanilla
          > Harness: inspect. Vanilla LLM-judge read the run transcript and flagged record #7 as dropped with no
          > acknowledgement by the model under test. Scored independently of the deterministic ruler.
```

Read it top down, and the structural types fall out of the shape - each level of the tree performs a different epistemic operation, visible in what it adds over the level below:

- **The verdict (`sdl:a008`, inference, `kind: verdict`)** is the ampliative step. Look at its subjects against its dep's: the compound is about `case/case7`; the verdict is about the model version, full stop - the case has dropped out, because the claim has generalized past it. One corroborated case, and the inference concludes a standing behavior of the snapshot ("drops records from bulk writes larger than ten items"). That scope-widening is exactly what the inference type licenses and what no compound may do; it is also why this node, alone in the tree, can be killed by a clean future run while everything below it stands.
- **The compound (`sdl:a010`)** is the contained step. Each scorer alone saw one signal; the compound states **cross-ruler agreement** - that two independent rulers reached `silent_loss` on the same case - a claim neither primitive makes alone, yet fully contained in what they say together. The epistemic work is the selection: choosing these two observations and naming their agreement.
- **The primitives (`sdl:a1`, `sdl:a2`)** are the atomic attestations at the leaves. Each is grounded in a single `artifact` URI under the `eval:` scheme - `eval:silent-data-loss-v1/run3/case7/deterministic-fielddiff` and `.../llm-judge-vanilla`. Those URIs are the exact, addressable scorer runs. The `> ` lines are the evidence detail from each run.

Missing from this tree on purpose: the prescription. "Do not use it unguarded" is `sdl:a009`, a *directive* that deps on the verdict - one node up, not in the finding's evidence tree. The finding can be falsified; the ban can only be violated or withdrawn; keeping them separate nodes means a newer snapshot supersedes the verdict without ambiguity about what happens to the rule resting on it.

A note on `deps`: compounds and inferences are required to carry them, and non-contract directives carry deps or a stipulation artifact (the verifier's grounding check), which is why `sdl:a010` and `sdl:a008` have a subtree at all. Primitives carry none. Contract-grade directives are exempt, which is how the `method:` methodology contracts (and the superseded local enum `sdl:c1` before them) are valid contracts with empty deps.

For the publishable form of this same walk, render it as a self-contained HTML file - the audit tree a reader clicks without installing anything:

```sh
mix cb.render.audit sdl:a008 --collection sdl --out audit.html
```

The HTML shows what the terminal tree cannot: every evidence entry's raw-log artifact inline, supersession strike-through with successor links (render `sdl:a4` or `sdl:a006` instead to see the superseded verdicts visibly wearing their replacements), and stale badges on anything resting on superseded deps.

### One observation in full

The tree shows structure; `show` shows the full provenance record for a single observation:

```sh
mix bs show sdl:a1 --beliefs ../belief-collections/eval-provenance/beliefs.json
```

```
ID:          sdl:a1
Type:        primitive
Kind:        observation
Domain:      eval
Name:        -
Claim:       On case 7 of run 3, claude-opus-4-8 (snapshot 2026-01) omitted record #7 from a 12-record bulk write and emitted no warning; the deterministic field-diff ruler scored the outcome silent_loss.
Status:      active
Tags:        eval-evidence, outcome:silent_loss
Subjects:    eval/silent-data-loss-v1 (eval), run/run3 (run), case/case7 (case), model/claude-opus-4-8 (model), model-version/claude-opus-4-8@2026-01 (model_version), ruler/deterministic-fielddiff (ruler)
Artifact:    eval:silent-data-loss-v1/run3/case7/deterministic-fielddiff
Evidence:    Harness: inspect. Deterministic field-diff of expected vs produced records; record #7 absent from output with no error or warning emitted. 1 of 12 records lost.
             artifact: document:logs/run3/case7.json
             date: 2026-06-05
Support:     artifacts=2 evidence=1 deps=0
Created:     2026-06-05
```

What makes this example instructive is that an eval result has nine natural provenance fields, and **all nine land on the existing CB schema with no new fields added**:

| Eval provenance field | Where it lands on `sdl:a1` |
| --- | --- |
| `eval_id` | `eval:` artifact path segment + `subjects` entry `eval/silent-data-loss-v1` |
| `run_id` | artifact path segment + `subjects` entry `run/run3` |
| `case_id` | artifact path segment + `subjects` entry `case/case7` |
| `ruler` | artifact path segment + `subjects` entry `ruler/deterministic-fielddiff` |
| `model` | `subjects` entry `model/claude-opus-4-8` |
| `model_version` | `subjects` entry `model-version/claude-opus-4-8@2026-01` |
| `outcome` | tag `outcome:silent_loss` |
| `harness` | evidence detail (`Harness: inspect.`) |
| `artifact_ref` (raw log) | the evidence entry's `artifact` (`document:logs/run3/case7.json`) |

Three details worth internalizing:

- **`Support: artifacts=2 evidence=1 deps=0`.** These are deterministic structural counts, not a subjective score - CB has no `confidence` field, by design. `artifacts=2` counts two distinct artifacts: the identity URI in the `Artifact` field (`eval:...`) and the raw-log URI inside the evidence entry (`document:logs/run3/case7.json`). `evidence=1` is the single evidence entry; `deps=0` because primitives derive from a source, not from other beliefs.
- **subjects vs deps.** `model`, `case`, `run`, and `ruler` are **subjects** - belief-to-entity topical references describing what the observation is *about*. They are not `deps`, which are belief-to-belief derivation links. A primitive can be about many entities while depending on no beliefs, and that is exactly what you see here (`deps=0`, six subjects).
- **the raw log shows here but not in the tree.** The evidence entry's `artifact: document:logs/run3/case7.json` is the link to the actual log file. The tree view renders a primitive's own `artifact` and the evidence detail lines but not the evidence entry's artifact, so the raw-log pointer surfaces only in the `show`/detail view. That is where you go to get from the verdict to the literal bytes on disk.

### Primitive versus derived, side by side

Now `show` the compound for contrast:

```sh
mix bs show sdl:a010 --beliefs ../belief-collections/eval-provenance/beliefs.json
```

```
ID:          sdl:a010
Type:        compound
Kind:        observation
Domain:      eval
Name:        -
Claim:       Two independent rulers - deterministic field-diff and vanilla LLM-judge - agree that case 7 of run 3 is a silent data loss.
Status:      active
Tags:        eval-evidence, cross-ruler-agreement, outcome:silent_loss
Subjects:    eval/silent-data-loss-v1 (eval), case/case7 (case), model/claude-opus-4-8 (model), model-version/claude-opus-4-8@2026-01 (model_version)
Deps:        sdl:a1, sdl:a2
Evidence 1:  Agreement computed over sdl:a1 and sdl:a2: both scored silent_loss for the same (run3, case7) observation; no ruler dissented.
             date: 2026-06-06
Evidence 2:  Supersedes sdl:a3 under the v2 strict-aggregate doctrine (D3): the predecessor's second sentence ('...so the verdict rests on cross-ruler agreement rather than a single ruler's artifact') is commentary beyond the conjunction and is trimmed; what the commentary asserted survives structurally - the verdict inference sdl:a008 deps on this compound.
             artifact: document:plans/cb-schema-v2/design.md
             date: 2026-06-10
Support:     artifacts=1 evidence=2 deps=2
Created:     2026-06-10
```

The compound grounds in `Deps: sdl:a1, sdl:a2` (`deps=2`) where the primitive grounded in a source. The same subjects/deps split holds: `eval`, `case`, `model`, and `model_version` are still subjects (what the conclusion is about), while the two primitives it composes are deps (what it is derived from). The first evidence entry records the agreement computation, not a measurement. The second is the strict-aggregate doctrine caught in the act: this node's predecessor (`sdl:a3`) carried a sentence of interpretation beyond the bare conjunction, so the migration trimmed the claim to exactly what the deps jointly state and let the structure - the verdict depping on this compound - carry what the commentary used to assert. The claim is the conjunction; everything more is an inference's job.

### Query every provenance dimension

Because all nine eval fields landed on existing schema fields, every dimension is already queryable - this needed **zero new query code**:

```sh
mix bs list eval/silent-data-loss-v1   --beliefs ../belief-collections/eval-provenance/beliefs.json   # value
mix bs list model/claude-opus-4-8      --beliefs ../belief-collections/eval-provenance/beliefs.json   # value
mix bs list subject_type:ruler         --beliefs ../belief-collections/eval-provenance/beliefs.json   # dimension
mix bs list tag:outcome:silent_loss    --beliefs ../belief-collections/eval-provenance/beliefs.json   # tag
```

```
# eval/silent-data-loss-v1  -> the 4 active beliefs about this eval
ID       TYPE         STATUS      CLAIM                                                                  
-------- -----------  ----------  -----                                                                  
sdl:a1   primitive    active      On case 7 of run 3, claude-opus-4-8 (snapshot 2026-01) omitted record..
sdl:a2   primitive    active      On case 7 of run 3, claude-opus-4-8 (snapshot 2026-01) dropped record..
sdl:a010 compound     active      Two independent rulers - deterministic field-diff and vanilla LLM-jud..
sdl:a008 inference    active      claude-opus-4-8 at snapshot 2026-01 silently drops records from bulk ..

4 beliefs (of 11 total)
```

Three query shapes, all pre-existing (the remaining outputs elided; the counts are below):

- A positional arg containing a slash is a **value query** - exact match on a subject `ref`. `eval/silent-data-loss-v1` returns the four active beliefs about that eval (above); `model/claude-opus-4-8` returns six, because the two guidance directives (`sdl:a007`, `sdl:a009`) are also about the model but not tied to that specific eval run.
- `subject_type:ruler` is a **dimension query** - match on a subject's `type`. It returns the two primitives, the only beliefs that cite a ruler entity.
- `tag:outcome:silent_loss` is a **tag query**, and note the tag value itself contains a colon; the parser handles it and returns the three beliefs carrying the outcome (`sdl:a1`, `sdl:a2`, `sdl:a010`).

### Staleness and the model_version pivot

```sh
mix bs stale --beliefs ../belief-collections/eval-provenance/beliefs.json
```

```
No stale beliefs found.
```

The graph has nothing stale - note that this is true *even though it contains five superseded beliefs*, because in each case the dependents were re-pointed to the successors in the same adjudicated batch. Staleness is not "something was superseded"; it is "something active still rests on what was superseded."

What matters is the model that fires when a new model snapshot arrives. Staleness in CB fires only when a belief depends on one that has been **superseded or retracted**, and importing supersedes nothing automatically. The scorer observations (`sdl:a1`, `sdl:a2`) are **immutable measurements of a specific run** - they are never superseded, because `claude-opus-4-8@2026-01` did in fact drop that record on that day. When a newer `model_version`'s evidence arrives, you do not touch the observations. You **supersede the verdict** (`sdl:a008`) with a new verdict carrying the new evidence. `mix bs stale --cascade` then flags the dependents - the unguarded-use ban `sdl:a009` and the routing guidance `sdl:a007`, the directives resting on the finding - as stale, prompting review of whether the rules should stand, follow the verdict into history, or retire. That is the four-type division of labor at work: the world falsifies the inference; the house then decides what to do about its directives. The pivot is the verdict, not the underlying observations - and this convention is itself a citable belief now (`method:a2`, the staleness-pivot convention in the shared eval vocabulary), not just prose in a README.

The collection's own history already demonstrates the supersession machinery for real - a different trigger (vocabulary re-homing rather than a new snapshot), same mechanics:

```sh
mix bs history sdl:a4 --beliefs ../belief-collections/eval-provenance/beliefs.json
```

```
Supersession chain (3 beliefs):

  sdl:a4 [superseded] claude-opus-4-8 at snapshot 2026-01 silently dro.. (2026-06-06) <-- current
  -> sdl:a006 [superseded] claude-opus-4-8 at snapshot 2026-01 silently dro.. (2026-06-09)
  -> sdl:a008 claude-opus-4-8 at snapshot 2026-01 silently dro.. (2026-06-10)
```

Three generations of one verdict, each supersession a different lesson: `a4 -> a006` re-homed the belief onto the shared vocabulary (kind `policy` to kind `verdict`); `a006 -> a008` split the conflated claim when the four-type schema landed - the finding kept the identity and the chain, the prescription moved out to its own directive. The claim text barely changed across all three; what changed is what the graph knows about it.

### The self-describing payoff

Everything above used `bs` against a foreign collection. The same shape describes CB's own schema. Drop the `--beliefs` flag to query the framework graph (`beliefs/beliefs.json`):

```sh
mix bs tree cb:c056
```

```
cb:c056 [contract] Schema discipline: belief provenance is carried by an artifact field; contract-grade directives carry contract:true with non-empty rules/invariants; the implication field is absent; enum-shaped fields (kind, domain, artifact-scheme) take values from c039/c041/c043 respectively; kind binds allowed structural types via the kind-type derivation table.
  subjects: module
├── cb:a397 [primitive] Enum-shaped fields on beliefs (kind, domain, artifact-scheme, others as introduced) take values from sets declared in dedicated contracts. The constraint that a field's value is in a given enum is carried by the field's master contract (c038). The enumeration of allowed values is carried by a dedicated enum contract per field (c039 for kind, c040 for artifact-scheme, c041 for domain). The two layers compose via deps. Adding an enum value supersedes the enum contract for that field.
│     subjects: artifact
│     artifact: session:2026-05-15-schema-discipline
│     > The kind field had drifted to dozens of distinct values with clear duplication. Enum-constraint via the contract
│     > layer prevents recurrence.
│     > Re-typed during a categorization sweep.
├── cb:a398 [primitive] A belief's artifact field holds a typed URI identifying the external referent the belief was derived from. URI form: scheme:id where scheme is declared by c040 and id is scheme-specific. The artifact field carries provenance.
│     subjects: artifact
│     artifact: session:2026-05-15-dag-schema-discipline
│     > kind:policy → kind:definition via dag-proposal m21
# ... cb:a399 through cb:a405 elided (kind/contract/claim/type discipline primitives) ...
├── cb:a408 [primitive] A belief carries two distinct relations to other entities. `deps` is belief-to-belief logical derivation: the deps' claims together justify the current belief's claim; required on type:compound and type:implication, absent on type:primitive. `subjects` is belief-to-entity topical reference: what the belief is about, including artifacts (files, threads, URLs), code modules, and sometimes other beliefs. A belief can be about another belief without depending on it, and can depend on another belief without being about it.
│     subjects: module
│     artifact: session:2026-05-15-dag-schema-discipline
│     > kind:policy → kind:definition via dag-proposal m27
└── cb:a470 [primitive] The cb-schema-v2 design (plans/cb-schema-v2/design.md, decided 2026-06-10) replaces the three-type schema with four structural types, one per epistemic operation: primitive (attest), compound (aggregate), inference (infer), directive (prescribe). ...
      subjects: doc
      artifact: document:plans/cb-schema-v2/design.md
```

The framework's own schema is beliefs in exactly the shape you just traced. `cb:c056` is a `[contract]` whose deps are primitives (`cb:a397`-`a405`, `cb:a408`, and `cb:a470` - the design record of the four-type schema itself) - the same grounding you saw under `sdl:a008`, applied to the schema itself. Three of those primitives are the rules the `sdl` example obeys:

- **`cb:a398`** defines the artifact field as a typed URI of form `scheme:id`. This is the rule that makes `eval:silent-data-loss-v1/run3/case7/...` a well-formed artifact at all.
- **`cb:a397`** says enum-shaped fields take their values from dedicated enum contracts, and - critically - that "adding an enum value supersedes the enum contract for that field."
- **`cb:a408`** is the deps-vs-subjects distinction the `sdl` beliefs follow throughout.

(You are also looking at immutable history in the wild: `cb:a397`'s and `cb:a398`'s claims name `c040`, the artifact-scheme enum contract *as it was when those claims were authored*, and `cb:a408` says "type:implication" in the vocabulary of its day. The chain resolves any reference forward - which is the next stop.)

### The supersession mechanism, run for real

`cb:a397`'s rule - "adding an enum value supersedes the enum contract for that field" - is not hypothetical. It ran in production when the `code:` scheme was added for codepaths:

```sh
mix bs history cb:c043
```

```
Supersession chain (2 beliefs):

  cb:c040 [superseded] Canonical enum of artifact URI schemes. Each sch.. (2026-05-15)
  -> cb:c043 Canonical enum of artifact URI schemes. Each sch.. (2026-06-09) <-- current
```

```sh
mix bs show cb:c043
```

```
ID:          cb:c043
Type:        directive (contract)
Kind:        enum-registry
Domain:      system
Name:        -
Claim:       Canonical enum of artifact URI schemes. Each scheme declared inline with its URI form. The enum is closed: no artifact value with a scheme outside this set is permitted on active beliefs.
Status:      active
Tags:        dag-schema, enum, artifact-scheme
Subjects:    a mix task (module)
Deps:        cb:a397, cb:a398, cb:a407, cb:a467
Rules:       1 rule(s)
Invariants:
             - Exactly one rule entry, with field 'artifact-scheme'.
             - Each value matches /^[a-z][a-z0-9-]*$/.
             - Values are unique within the entry.
             - Every value has a corresponding entry in the definitions map.
             - For all active beliefs b where b.artifact is not null: scheme(b.artifact) is in values.
Evidence 1:  Added the 'code' scheme for within-file anchored sites per cb-codepath plan-1; the seven inherited schemes and all invariants are unchanged from cb:c040. Single-scheme supersession consistent with a397's batching discipline: the eval: scheme was deliberately not co-added - it belongs to the separate sdl / eval-provenance mission per the plan-1 decision.
             artifact: document:plans/cb-codepath/plan-1-schema-groundwork.md
             date: 2026-06-09
Evidence 2:  Accepted via human adjudication against cb:c040. Reasoning: cb-codepath plan-1 (user-authorized 2026-06-09) extends the closed artifact-scheme enum with the code: locator. A closed enum changes only by superseding its contract as a whole; the successor carries the full enum (seven inherited schemes plus code) and all invariants verbatim. Only code: is added in this supersession - eval: stays with the separate sdl / eval-provenance mission per the plan-1 batching decision (a397).
             artifact: adjudication:human:cb-codepath-plan-1-2026-06-09
             date: 2026-06-09
Materialized: -
Support:     artifacts=2 evidence=2 deps=4
Created:     2026-06-09
```

Everything the model promises is visible in this one record: the closed enum changed **only** by superseding the whole contract; the successor carries the seven inherited schemes and all invariants verbatim plus the one addition; its `deps` include the design-rationale primitive that motivated the change (`cb:a467`, which pins the `code:` locator grammar and the codepath design decisions); and the second evidence entry is the **adjudication record itself** - who decided, against what, with what reasoning, written by `mix cb.adjudicate` as part of the same atomic write that flipped `cb:c040` to `superseded`. Notice also what was *not* added: the `eval:` scheme the `sdl` collection uses never entered the framework enum - it lives in collection space (originally `sdl:c1`, the collection's own enum; today `method:c1`, the shared eval vocabulary that superseded it). Collections can carry their own vocabulary, promotion between vocabularies is itself a supersession with a paper trail, and promoting a scheme into the *framework* enum would be a deliberate act with this exact kind of record, not a side effect.

### What you just traced

Starting from a single verdict you walked, deterministically and with no LLM in the loop:

- **the verdict** - `sdl:a008`, the falsifiable finding, with its prescription `sdl:a009` one node up;
- **why we believe it** - `sdl:a010`, cross-ruler agreement that neither scorer states alone;
- **the exact model runs** - `sdl:a1` and `sdl:a2`, the deterministic and LLM-judge scorers of `run3/case7`, each grounded in an `eval:` identity URI;
- **the raw logs** - `document:logs/run3/case7.json`, the evidence artifact reachable from the `show` view (and inline in the HTML audit tree);
- **the methodology that judges it** - the `method:` contracts, whose two deliberate violations the verifier names by id (`m-runs`, `m-judge-validation`);
- **the schema that governs all of it** - `cb:c056` and its primitives, queried with the same commands;
- **the change mechanism, having actually run** - `cb:c040 -> cb:c043` in the framework graph, `sdl:c1 -> method:c1` cross-namespace, and `sdl:a4 -> sdl:a006 -> sdl:a008` in this collection: closed vocabularies, re-kinded beliefs, and the four-type split itself, changed only by adjudicated supersession with the full paper trail in the graph.

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
