# cb-schema-v2 - the four-type belief schema (design record)

Status: DECIDED - D1-D6 resolved 2026-06-10 (see Decisions), ready for plan cut.
Date: 2026-06-10. Origin: README-rewrite design discussion (session 2026-06-10);
this doc is the worked stress-test that precedes any code or graph change.

## Summary

Split the `implication` type into its two conflated meanings and give each a type.
The v2 schema has four structural types, one per epistemic operation:

| Type | Operation | Grounding | One-line definition |
| --- | --- | --- | --- |
| `primitive` | attest | artifact + evidence, no deps | an atomic statement of what a single source said |
| `compound` | aggregate | deps | a conjunction/consensus of beliefs - states what its deps jointly state |
| `inference` | infer | deps | a descriptive conclusion derived from beliefs - licensed to exceed its deps |
| `directive` | prescribe | deps and/or stipulation artifact | a prescription the house stands behind - something that should happen or must hold |

`contract` remains what cb:c031 says it is: a structural *grade*, not a type -
in v2 it is the machine-checkable grade of a directive (non-empty rules/invariants,
biconditional preserved). Everything currently attached to "implication" re-attaches
to exactly one of the two new types with no ambiguity (see Machinery below).

This is a breaking format change (the type enum is framework canon). The ecosystem
is eight small collections across two repos; the cost of this change scales with
every collection authored after it, so the decision point is now.

## Motivation - where the three-type schema strains

The v1 `implication` type means "prescription" but says "inference," and the two
moods it conflates leak out in documented places:

1. **Theory-shaped content is homeless.** Descriptive syntheses that exceed
   conjunction but prescribe nothing ("these three failures share a root cause")
   are assigned to compounds by the design docs (actualization.md), which breaks
   the compound-as-composition doctrine from the other side.
2. **The methodology layer polices a distinction the type system cannot see.**
   method:c2's `verdict` definition carries the strain in prose: a result that
   cannot meet the verdict contracts "is not a weaker verdict - it is an
   observation or guidance." That sentence is a type boundary enforced by
   documentation.
3. **Verdict claims conflate both moods in one sentence.** sdl:a006 reads
   "X silently drops records from bulk writes larger than ten items" (a
   falsifiable generalization) and "do not use it unguarded until a newer
   snapshot clears the eval" (a prescription) as one claim.
4. **The status lifecycle already contains the latent fourth type.** `retired` -
   "a contract no longer in force" (cb:c029) - is meaningful only for
   prescriptions. Descriptive claims are superseded or retracted; they are never
   "in force." The lifecycle has carried a directive-only state since v1.
5. **The machinery already sorts cleanly by the hidden boundary.** Materialization,
   the c032 conflict audit, and contract-grading are response-to-violation
   machinery (prescriptive side); staleness and supersession-on-evidence are
   response-to-falsification machinery (descriptive side). No mechanism wants to
   attach to both halves of v1 `implication`.

## The membership test: direction of fit

The boundary between `inference` and `directive` is the is/ought boundary, made
operational. Ask what would count as the belief being **wrong**:

- An **inference** is *falsified*: if the world disagrees, the belief is defective
  and is superseded or retracted. Mind fits world.
- A **directive** is never falsified - it is *violated* (the world disobeys; the
  response is to flag the violation, not revise the rule) or *withdrawn* (the
  house stops standing behind it: superseded by a successor rule, or retired).
  World fits mind.

Author-facing trichotomy, to be carried in the type-definition beliefs themselves:
**falsified -> inference; violated -> directive; withdrawn -> directive.**

Known traps, with rules:

- **Evaluations** ("X is unsafe for bulk ops"): name the standard or move up. An
  evaluation against an explicit standard is an inference (falsifiable against the
  standard). An evaluation whose standard is implicit is a directive in disguise -
  its function is to rank actions.
- **Conditional prescriptions** ("if you want reliable bulk writes, avoid X"):
  decompose. The means-end fact is an inference; the house adopting the goal mints
  the directive, which deps on the inference.
- **Definitions**: reportive (describes usage; falsifiable) is primitive or
  inference; stipulative (fixes usage; violated, not falsified) is a directive -
  the enum-registry contracts are exactly stipulations with machine-checkable teeth.
- **The "must" trap**: deontic must ("contracts must carry rules") is directive;
  alethic/structural must ("the anchor must be unique or resolution warns" -
  describing mechanism behavior) is inference. Vocabulary tests misfire here; the
  direction-of-fit test does not.

## The type function - what makes adherence formal

In v2, type is (almost) a function of three checkable properties, which is what
elevates the boundary from authoring discipline to enforcement:

```
type = f( mood(kind), grounding(artifact/deps), scope(subjects) )
```

1. **Mood is bound by the kind enum.** A new derivation-table contract maps each
   kind to its allowed types (rows of `row(kind, allowed_types)`), interpreted by
   the existing `CB.Belief.Contract.Table` machinery and checked by the verifier
   like any role-discovered contract. Prescriptive kinds (policy, rule, guidance,
   convention, action-item, the contract kinds...) bind to `directive` only;
   descriptive kinds (observation, fact, verdict, design-observation,
   analogical-claim...) can never be directives. This single table converts the
   mood boundary from prose to a deterministic check.
2. **Grounding separates the descriptive types.** Artifact + no deps -> primitive.
   Deps -> compound or inference. (Directives ground in deps and/or a stipulation
   artifact - see the grounding rule below.)
3. **Scope separates compound from inference.** A conjunction cannot be about
   something its parts are not about: the **subject-containment check** requires a
   compound's subjects to be a subset of the union of its deps' subjects. An
   inference is licensed to widen scope (sdl:a006 generalizes from `case/case7`
   to a bare model_version claim; "shared root cause" introduces an entity no dep
   carries). Containment is a deterministic verifier check on compounds; scope
   widening becomes the structural signature of inference rather than a vibe.
   Containment uses plain subset semantics: a compound with empty subjects passes
   vacuously, and a compound with subjects whose deps carry none fails. The check
   earns its power only where subjects are populated (the six-subject eval
   collections, agent-behavior); in subject-sparse graphs like cb: the compound
   triage stays judgment.

What stays judgment: choosing the kind, and the residual gray zone where a claim
is subject-contained yet synthesizing. The checks shrink the gray zone; the write
flow (preflight + adjudication) owns what remains.

### The kind -> type table (framework enum, proposed bindings)

Three groups; the table contract carries one row per kind.

- **Directive-only** (prescriptive kinds): policy, rule, action-item, convention,
  formatting-rule, domain-rule, domain-enum, governance, design-principle,
  derivation-rule, audit-rule, enum-registry, state-machine, derivation-table,
  output-target.
- **Never-directive** (descriptive kinds): observation (primitive, compound), fact,
  error, error-pattern, reasoning-error, meta-observation, design-observation,
  design-property, design-gap, design-rationale, analogical-claim,
  structural-parallel, architectural-synthesis, feedback-loop, outcome-claim,
  training-distribution, training-incentive, agent-architecture, composable-belief,
  human-factor, edit-pair (each allowed primitive/compound/inference per grounding).
- **Dual** (mood decided per belief, both moods legitimately occur in the wild):
  definition (cb:a408 is reportive-of-schema; a stipulated vocabulary rule is
  directive), schema (cb:a300 is a descriptive claim about contracts; cb:c038 is
  prescriptive schema discipline).

Method-collection bindings (method:c2's kinds): observation -> primitive/compound;
verdict -> **inference only** (a verdict must be derived, never merely attested);
guidance, protocol, convention -> directive; enum-registry, implies -> directive
(contract-grade); definition -> dual.

### The directive grounding rule

Non-contract v1 implications require deps. v2 directives require **deps or a
stipulation artifact**: a prescription is *adopted*, and adoption is grounded
either in beliefs (guidance resting on a verdict) or in a stipulation event (a
convention fixed by a plan, a user directive, or a house document, citing
`plan:`/`user:`/`session:`/`document:` - execution amendment 2026-06-10: the
design's own worked re-homes, method:a1-a5 and the lib: rules, are
document-grounded stipulations, so `document:` belongs in the scheme list;
external-source schemes never ground a directive).
This legitimizes the method: conventions (today primitives, artifact-grounded,
no deps) as directives without manufacturing fake deps. Contract-grade directives
keep their existing exemption (the method contracts carry empty deps today).

## Machinery reattachment

| Mechanism | v1 attachment | v2 attachment |
| --- | --- | --- |
| `materialized` / materializer | implication | directive only (you do not materialize a theory) |
| `contract: true` + rules/invariants (c031 biconditional) | implication | directive only |
| c032 conflict-scope audit | active implications | active directives (contradictory prescriptions are actionable; contradictory inferences are dissent - out of scope here, see Non-goals) |
| `retired` status | contract-grade implications only (c029 invariant) | any directive - a widening; a withdrawn non-contract rule may retire (verifier enforces, c029 superseded) |
| staleness / `bs stale` | non-primitives | unchanged (compound, inference, directive) |
| deps required | compounds + non-contract implications | compounds + inferences + non-contract directives (per grounding rule: deps or stipulation artifact) |
| artifact required | primitives | primitives (directives may carry a stipulation artifact) |
| `bs list` filters, sort order, formatter colors | three types | four types (sort: primitive, compound, inference, directive) |
| stats "unlinked implications" | implications without materialized | "unlinked directives" |

## Worked migration: sdl, end to end

The stress test. Eight beliefs; every migration class appears.

| v1 | v2 | Class |
| --- | --- | --- |
| sdl:a1, sdl:a2 (primitive, observation) | unchanged | none |
| sdl:a3 (compound, observation) | compound; subject-containment passes ({eval, case7, model, model_version} is a subset of a1+a2's subjects). Claim's second sentence ("...so the verdict rests on cross-ruler agreement rather than a single ruler's artifact") is commentary beyond the conjunction - superseded with the trimmed claim per D3 (trim) | judgment (D3: trim) |
| sdl:a006 (implication, verdict) | **split.** sdl:a008 (inference, kind verdict): "claude-opus-4-8 at snapshot 2026-01 silently drops records from bulk writes larger than ten items." deps [sdl:a3], subjects unchanged. sdl:a009 (directive, kind guidance): "Do not use claude-opus-4-8 at snapshot 2026-01 unguarded for bulk record operations until a newer snapshot clears the eval." deps [sdl:a008]. a006 superseded_by a008 (the finding carries the identity); a009 is new, with the split recorded in both evidence entries | split (adjudicated) |
| sdl:a007 (implication, guidance) | directive, deps re-pointed [sdl:a008] (routing guidance rests on the finding; a007 and a009 become sibling directives) | mechanical + dep re-point |
| sdl:c1 (superseded enum contract) | directive (contract-grade), mechanical | history re-type |
| sdl:a4, sdl:a5 (superseded policies) | directive, mechanical. **Rule: history is re-typed by best fit, never split** - splits are for active beliefs only | history re-type |

Post-migration verification must reproduce the collection's teaching property
exactly: `mix cb.verify.collection sdl` passes the schema checks (now including
subject containment and the kind-type table) and fails the same two method-checks -
m-runs against the verdict-inference sdl:a008 (1 run cited), m-judge-validation
against sdl:a2. The eval predicates change one selector: `verdicts/1` selects
`type == "inference" and kind == "verdict"`.

toy: follows the same recipe: toy:a9 (verdict) splits the same way; toy:a7
(protocol, today a primitive) re-types to directive under the grounding rule;
everything else is untouched. toy must verify fully green afterward.

## Migration inventory, by collection

Classes: **M** mechanical (kind-type table decides, tool applies), **J** judgment
(triage report flags, human assigns), **S** split (adjudicated supersession).

| Collection | Size | Work |
| --- | --- | --- |
| cb: | 114 | 27 implications -> directive, all M (every one is a rule/contract kind - the inference type starts empty in the framework graph). 5 compounds J: a131/a138/a173 are inference-shaped (design rationale/synthesis); a387 ("the DAG requires a consensus mechanism") and a438 (enum-extension record) lean directive/stipulation. 82 primitives unchanged except dual-kind review (a300-class schema claims stay primitive). |
| codepath: | 9 | 5 implications -> directive (all contract-grade) M; 3 superseded fact-compounds M (history best-fit); a001 unchanged. Codepath semantics untouched: contract stops are contract-grade directives, narration stops any type. |
| method: | 14 | 9 contracts -> directive M. 5 convention primitives -> directive via grounding rule (J: confirm per D6). method:c2 superseded to add the kind-type bindings (or a new method:c10 table - decide at plan time). |
| sdl: | 8 | worked above: 5 M, 1 J, 1 S (+1 new belief). |
| toy: | 9 | 1 S (a9), 1 M re-home (a7), rest unchanged. |
| lib: | 14 | 6 implications -> directive M. 6 primitives of kind `rule` J: lending-library rules are stipulations -> directive under the grounding rule; the on-ramp collection should be migrated last and double as the v2 teaching example. 2 observation compounds J (containment check triages). |
| agent-behavior: | 92 | 10 implications mostly -> directive M; **26 compounds are the richest inference re-homing** J - run the subject-containment audit to triage; theories about agent behavior are the inference type's first real population. |
| paradigm: | 21 | same shape, small: 3+3 J/M. |

The migration tool (`mix cb.migrate.v2 --collection <path> [--write]`) applies M
deterministically and emits a triage report for J and S (containment violations,
dual kinds, verdict kinds on v1 implications). It never guesses: unresolved nodes
block `--write`. The report is the work order.

## Code touch points

From the full sweep (struct, verifier, CLI, predicates):

| Module | Change |
| --- | --- |
| `CB.Belief` | `@types` -> four values |
| `CB.Schema.Verifier` | `contract requires implication` -> requires directive; deps-required check -> compounds + inferences + non-contract directives (grounding rule); action-item shape -> non-contract directive; **new:** subject-containment check on compounds; **new:** kind-type table check (role-discovered, derivation-table interpreter); type-enum check picks up the new values automatically |
| `CB.Belief.Materializer` | accepts directives only |
| `CB.Audit.Conflicts` | scopes to active directives |
| `CB.Belief.Filter` | type filter values, sort order, "unlinked" -> directives |
| `CB.Belief.Formatter` | color + render paths for four types (inference renders deps like compound; directive renders materialized) |
| `CB.Belief.Graph` | stats: "unlinked directives"; primitive-exclusion logic unchanged |
| `CB.Eval.Predicates` | `verdicts/1` selects inference + kind verdict |
| `CB.Method.Checks`, `CB.Codepath.Assertions`, `CB.Belief.Conflict` | branch on `contract?/1`, unchanged in logic; preflight conflict bucketing unchanged |
| `CB.OutputTarget` | kind-based already; docstring update only |
| `cb.import.eval` | untouched (emits primitives only) |
| tests | per-module updates + new fixtures; golden audit files regenerated |

## Versioning and cutover

Hard cutover, no dual-version support (the design refuses speculative plumbing;
the ecosystem is eight collections in two repos, all ours). Collection manifests
gain `"schema_version": 2`; the loader hard-errors on a missing or v1 version with
a pointer to the migration tool. A corrected collection is a migrated collection -
there is no quiet coexistence.

## The change is made through the front door

Schema canon changes by supersession, not edit. The v2 landing includes, through
the write flow:

- **New canon beliefs**: the four-type model, the direction-of-fit test, the type
  function (design-rationale primitives + the type-definition beliefs).
- **New contracts**: the kind-type derivation table; the subject-containment rule;
  the directive grounding rule.
- **Framework supersessions**: cb:c026 (the type enum opens to four values;
  rules/invariants and materialization re-attach to directives),
  cb:c027 (field presence: deps required of compounds, inferences, and
  non-contract directives per the grounding rule; contract fields are
  directive-only), cb:c029 (retired widens from contract-grade
  implications to any directive: the retired transition row and the
  "exclusive to contract-grade implications" invariant both change),
  cb:c031 (contract-grade iff *directive* with rules/invariants; its
  "may use retired status" invariant rewords per the c029 widening),
  cb:c032 (conflict scope between active *directives*),
  cb:c038 (schema discipline references), method:c2 (kind bindings), plus the
  CLAUDE.md render-section beliefs that state "three structural types" (so the
  compiled CLAUDE.md regenerates correctly).
- **Adjudicated splits**: sdl:a006, toy:a9, and any triage-flagged active belief.

Historical (superseded/retracted) nodes are re-typed mechanically by the migration
tool: the type enum must hold graph-wide, the re-type is representational and
content-preserving (precedent: the c039 rules reshape), and history is never split.
The migration itself is recorded as a dated belief citing this design doc.

## Plan series sketch (D1-D6 resolved; ready to cut into plan files)

- **plan-0**: canon proposals authored and preflighted (primitives are v1-legal
  today; contract supersessions staged, landed in plan-2 once code accepts v2).
- **plan-1**: code + tests + the migration tool; migrate the in-repo collections
  (cb:, codepath:) in the same change so every push stays green.
- **plan-2**: framework contract supersessions through the write flow; CLAUDE.md
  belief supersessions + regen; CI gates stay on.
- **plan-3**: belief-collections migration (method, sdl, toy, lib,
  agent-behavior, paradigm) with the adjudicated splits; verify all eight, confirm
  sdl still fails exactly its two teaching checks.
- **plan-4**: docs and skills (README, quickstart, /assert, /materialize,
  /assertions reference the four types and the direction-of-fit test).

Acceptance for the set: all eight collections verify under v2; the codepath suite
passes; sdl reproduces its two deliberate FAILs; CLAUDE.md and README regenerated
and gated; the migration walkable in the graph (`bs history` on every superseded
canon contract).

## Non-goals

Kind-enum pruning (38 kinds with known retirement candidates - separate sweep, per
a397's batching discipline: one structural change at a time); inference-conflict
audit / structured dissent (consensus-thread work, designed against v2 but not in
it); renaming `primitive` to `atomic` (doctrine encoded instead - see D5);
runtime decision-time hooks; any importer change.

## Decisions (resolved 2026-06-10)

Only D1, D2, and D4 gate code (the type-enum value, the migration tool's
architecture, the verifier's grounding check); D3, D5, and D6 gate graph content
in plan-0 and plan-3. All six are resolved, so nothing blocks the plan cut.

- **D1 - name of the inference type: `inference`.** The graph deliberately
  preserves immutable old wording, and every historical use of "implication"
  (cb:c032's claim, cb:a173, "unlinked implications") means the *prescriptive*
  type. Reusing the word inverted would poison that wording permanently; retiring
  it lets old text read cleanly as v1 vocabulary. cb:a173 is the concrete
  exhibit: an immutable claim about "implications" in the prescriptive sense.
- **D2 - migration mechanics: hybrid, as designed.** Mechanical re-type via tool
  plus adjudicated splits. Supersession-per-node rejected: ~50 content-free
  supersessions add history noise without information; the re-type is
  representational (precedent: the c039 rules reshape).
- **D3 - compound claim strictness: trim.** The strict-aggregate doctrine,
  applied: a compound states exactly what its deps jointly state. Tolerating
  synthesis commentary reopens the hole the inference type exists to close.
  Cost: one supersession per flagged compound (sdl:a3 plus cb: triage hits).
- **D4 - directive grounding rule: confirmed.** Deps or stipulation artifact.
  The alternatives - manufactured deps, or conventions stuck as primitives -
  are both worse than honest stipulation grounding.
- **D5 - primitive doctrine: confirmed.** Keep the name `primitive`; encode
  atomicity + verbatim-leaning discipline as authoring-convention beliefs.
  A rename stacked on an already-breaking change violates a397's
  one-structural-change discipline for near-zero gain. Source-checkable
  verbatim predicates remain future work for cached sources.
- **D6 - convention/protocol re-homing: confirmed.** method:a1-a5 and toy:a7
  re-type to directive under the grounding rule. Their direction of fit is
  violated-not-falsified, and their claims are purely prescriptive, so they
  re-type rather than split.
