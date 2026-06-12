# Reference

## The command surface

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

## Artifact schemes

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

## The schema contract family

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

## What is in this repo

- `lib/cb/` - the framework, in layers. The graph layer: the `CB.Belief` struct with byte-stable serialization, deterministic traversal/filter, conflict preflight, adjudication, supersession, staleness. The contract layer: the rule-kind interpreters, the schema verifier, the collection loader/registry, the output-target compiler. The codepath layer: the `code:` locator, resolver, renderer, predicates, and assertions runtime. The eval layer: the shared predicate gate, collection predicates and the method-check pass, the run-manifest parser/importer, the audit-tree renderer. Plus a pluggable materializer with JSON and Test sinks. Sole dependency: Jason.
- `beliefs/beliefs.json` - the framework's own self-referential graph: CB's design expressed as beliefs (run `mix bs stats` for the live shape) - the schema contracts above with their supersession chains, the mechanism primitives and compounds, and the positioning beliefs.
- `codepath/` - the `codepath:` collection: the `belief-pipeline` codepath that tours and tests CB's own data pipeline.
- `skills/` - agent skills for a Claude-Code-style harness: `/assert` (author beliefs from artifacts/entities/reasoning), `/assert-session` (persist session rules and agent error patterns), `/assertions` (query and traverse), `/materialize` (turn directives into concrete work items), `/present-codepath` (walk a codepath interactively). Symlinked into `.claude/skills/`. (Skills are hand-authored today, not compiled from the graph.)
- `docs/` - the narrative documentation ([mental-model.md](mental-model.md), [codepaths.md](codepaths.md), [eval-ledger.md](eval-ledger.md), the [worked example](worked-example-eval-verdict.md), and this reference), the design reference index (`belief-graph.md`), the thesis (`composable-beliefs-thesis.md`), BEAM rationale (`cb-on-the-beam.md`), the run-manifest spec (`run-manifest.md`), operational learnings (`operations.md`), and analyses. The guided `quickstart.md` lives with the teaching material in the sibling `belief-collections` repo - if the self-referential `cb:` graph is a lot to meet first, start with the `lib:` lending-library collection there.
- `plans/` - plan sets and their transcripts, including `plans/cb-codepath/` and `plans/cb-eval/` (design records, executed plans, and both design and execution transcripts).
- CI (`.github/workflows/composable-beliefs.yml`) - on every push: the test suite (including an anchor-rot guard that resolves the shipped codepath against the real source), `cb.verify.schema`, and the CLAUDE.md freshness gate.

## A quick tour

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
