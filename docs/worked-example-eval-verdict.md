# Worked example: tracing an eval verdict to its evidence

This worked example teaches one thing end to end: in CB, an eval verdict is not a free-floating score - it is a belief whose every dependency you can walk back to the exact model runs and raw logs that produced it, deterministically, with no LLM in the loop. The vehicle is the `sdl` collection (`eval-provenance` in the sibling `belief-collections` repo): a published eval, `silent-data-loss-v1`, rendered in miniature. Eleven beliefs (six active, five superseded - the supersessions are part of the lesson) capture two scorer observations of a single failing case, the cross-ruler agreement they compose into, the verdict inference and the guidance directives that rest on it, and two layers of history: the collection's move onto the shared `method:` vocabulary, and the four-type migration that split the original verdict into a finding and a prescription.

The example is also deliberately imperfect: its verdict cites only one run and its LLM judge has no validation record, so it **fails two of the six methodology contracts on purpose**. A teaching collection that visibly fails the house methodology teaches both the mechanism and the culture; the fully compliant counterpart is the `toy:` collection in the same sibling repo.

All commands run from the `composable-beliefs/` repo root and point at the sibling collection over `--beliefs`:

```sh
mix deps.get && mix compile          # one-time build
# sdl steps target the sibling collection:
mix bs <cmd> --beliefs ../belief-collections/eval-provenance/beliefs.json
```

You can set `CB_BELIEFS=../belief-collections/eval-provenance/beliefs.json` once instead of repeating the flag. One caveat: the final steps query CB's own graph (`beliefs/beliefs.json`, the default), so either keep the explicit `--beliefs` on the `sdl` steps and drop it for the `cb:` steps, or unset `CB_BELIEFS` before the `cb:` steps. This worked example uses the explicit flag throughout.

## Verify the collection

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

## See its shape

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

## The audit tree

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

## One observation in full

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

## Primitive versus derived, side by side

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

## Query every provenance dimension

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

## Staleness and the model_version pivot

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

## The self-describing payoff

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

## The supersession mechanism, run for real

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

## What you just traced

Starting from a single verdict you walked, deterministically and with no LLM in the loop:

- **the verdict** - `sdl:a008`, the falsifiable finding, with its prescription `sdl:a009` one node up;
- **why we believe it** - `sdl:a010`, cross-ruler agreement that neither scorer states alone;
- **the exact model runs** - `sdl:a1` and `sdl:a2`, the deterministic and LLM-judge scorers of `run3/case7`, each grounded in an `eval:` identity URI;
- **the raw logs** - `document:logs/run3/case7.json`, the evidence artifact reachable from the `show` view (and inline in the HTML audit tree);
- **the methodology that judges it** - the `method:` contracts, whose two deliberate violations the verifier names by id (`m-runs`, `m-judge-validation`);
- **the schema that governs all of it** - `cb:c056` and its primitives, queried with the same commands;
- **the change mechanism, having actually run** - `cb:c040 -> cb:c043` in the framework graph, `sdl:c1 -> method:c1` cross-namespace, and `sdl:a4 -> sdl:a006 -> sdl:a008` in this collection: closed vocabularies, re-kinded beliefs, and the four-type split itself, changed only by adjudicated supersession with the full paper trail in the graph.
