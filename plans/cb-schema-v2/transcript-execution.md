# Transcript - cb-schema-v2: decision and execution (D1-D6, plans 0-4)

**Date:** 2026-06-10
**Surfaces:** a single composable-beliefs TUI thread (Fable 5), picking up the
design record the previous session wrote, carrying the D1 naming debate to a
decision, and executing the full plan series in the same thread.
**Companion to:** [`design.md`](design.md) (the decided design record, with its
execution amendments inline), the plan files `plan-0.md` through `plan-4.md`
(each carrying its execution record), and [`why-inference.md`](why-inference.md)
(the README source material the debate produced).

> User turns are condensed to their substance; the load-bearing phrasings are
> quoted. Assistant turns are condensed to what was read, decided, written, and
> committed. Tool output is summarized, not reproduced.

---

## Summary

One session took cb-schema-v2 from "design awaiting decisions" to shipped: D1-D6
resolved (D1 `inference`, decided through a full adversarial debate the user
requested after overriding the immutable-history consideration), plans 0-4 cut
and executed end to end - canon beliefs through the write flow, the four-type
code and migration tool, the framework contract supersessions, all eight
collections migrated with the adjudicated splits, and the README rewritten with
the naming debate's explanatory prose as its new centerpiece section.

Commits: composable-beliefs `364233f` (the whole landing, 79 files),
belief-collections `16e2fe8` (the six collection migrations); both pushed.
261 tests green at the end; every framework-graph write through the write flow;
all eight collections verify under v2 with sdl reproducing exactly its two
teaching method-check failures.

---

## 1. Review: "examine the repo and plans/cb-schema-v2/design.md"

The design doc's factual claims were verified against the live repo and graph:
the migration inventory matched `bs stats` exactly (114/27/5/82), the sdl worked
migration matched the collection node for node, the code touch points resolved
to real functions (the verdict selector turned out to be one line in
`CB.Eval.Predicates`). One real gap surfaced: **cb:c029 was missing from the
supersession list** - its invariant "retired status is exclusive to
contract-grade implications" changes on both words under v2, and the machinery
table had the direction backwards (the v2 change is a widening, contract-grade
to any directive). Also flagged: subject containment passes vacuously on the
subject-sparse cb: graph, so its compound triage is pure judgment - the doc
should say so. Both folded into design.md.

## 2. "ok decide as you see fit, do d1-d6 need to be decided before beginning dev?"

Decisions made and recorded in design.md: D1 `inference` (over retaining
`implication`), D2 hybrid migration, D3 trim, D4 grounding rule confirmed, D5
keep `primitive`, D6 conventions re-type. Gating answer: only D1/D2/D4 gate
code; D3/D5/D6 gate graph content, but plan-0 leads the series so the plan cut
wanted all six. One flag raised to the user: the session memory recorded an
earlier lean toward keeping `implication`, and the decision overrode it -
offered for veto.

## 3. "i am overriding the immutable history consideration... present the case for both sides"

Launch reframed the debate: not "what does the existing graph say" but "what
word do we live with." Both cases presented in full. For `implication`:
ordinary-English fit ("the implications of these findings" is colloquially
ampliative), the relational grammar (an implication is *of* something - the
name wears its grounding), the ML-serving collision avoided (`inference` is
saturated vocabulary in the agent ecosystem). For `inference`: technical
accuracy at the exact point the design cares about (the type's defining licence
is to exceed its deps; entailment is precisely the licence it lacks; CB performs
no deduction), the one-line glossary test (a definition of "implication" that
grants the scope-widening licence fights its own noun), the lifecycle argument
(the machinery supersedes a falsified conclusion while its deps stand - the
signature of inference, paradoxical under "implication"), and the
near-disqualifying in-framework collision (the contract kind `implies` is
directive-only in v2; naming the descriptive type `implication` puts one lexeme
on both sides of the very boundary v2 draws). Verdict held at roughly 60/40 for
`inference`, with `conclusion` named as the strongest third option if the
ML-collision worry dominated.

## 4. "51% sold on inference but curious about conclusion" / "inference belief or inferred belief?"

`conclusion` evaluated seriously: it wins on result-noun purity, zero ML
collision, and lay accessibility, and its verb pairs as cleanly
(attest/aggregate/conclude/prescribe). It loses on the finality connotation
pointing the wrong way twice (the graph's riskiest type sounding most settled;
mid-graph nodes sounding terminal), the prescriptive-mood leak ("the committee
concluded we should divest" is idiomatic), no theory lineage (defeasible
inference, nonmonotonic inference, belief revision - CB with
supersession-on-falsification IS defeasible-inference machinery), the glossary
direction (name the type with the technical word, define it with the lay one),
and the compound/conclusion visual collision. Net: between `implication` and
`inference`, closer to `inference`; 60/40 held.

Grammar ruling: the house pattern is the bare noun ("an inference", like "a
compound"); attributive form "inference belief" (type-as-classifier);
"inferred belief" describes provenance rather than naming the type slot and
starts a participle pattern the other types refuse.

## 5. The deduction questions

Three questions that became why-inference.md and then the README section:

- *Why isn't the inference node a result of deduction?* Because the move is
  ampliative: from "case 7 dropped a record" (twice) to "this snapshot drops
  records from bulk writes over ten items" - the conclusion is about all bulk
  writes, the premises about one case. The gap is the problem of induction,
  unbridgeable by deduction; and the falsification lifecycle requires the gap,
  since a clean future run kills the generalization while the observations
  stand.
- *Why CAN'T an implication exceed its premises?* By definition: "an entailment
  of the premises that is not an entailment of the premises" has the shape of
  "a bachelor's wife."
- *Doesn't "fails only with a premise" imply deduction?* Yes - that is the
  modus tollens: CB's machinery is built for these nodes to fail independently
  of their deps, therefore they are not implications of their deps.

Kicker that landed: **the compound is the one deduction CB stores**
(conjunction introduction; subject containment as its formal shadow; the
epistemic work is the selection). The user's follow-up - "so compound IS
implication by another name?" - confirmed it precisely: the compound is the
only node type whose claim genuinely is entailed by its deps; "implication" was
technically accurate for compound and nothing else in the schema.

## 6. "ready to go with inference and proceed" + the README directive

The user directed: include the why-inference writeup semi-verbatim in the
README - the positive case, no contest framing, "how the edges define the
territory" - and extend that explanatory register through the README generally.
Also (earlier in the same turn): philosophy's vocabulary for expressing and
navigating ambiguity may be an increasingly valuable engineering skill; this
design cycle consumed direction of fit, the deductive/ampliative boundary,
defeasibility, and speech-act mood, and turned each into a check or a type.

Execution followed in the same thread:

- **Persisted the debate** as why-inference.md; cut plan-0 through plan-4.
- **Plan-0.** Seven canon primitives (a470-a476) through preflight + import;
  the preflight surfaced the dag-schema overlap family (reviewed per c032,
  recorded in evidence, a467/c040 precedent) and **exposed two supersession
  targets the design list had missed: c026 and c027** - added to design.md and
  plan-2. Contract drafting deferred to plan-2 (successors are v2-typed).
- **Plan-1.** Four-type enum; verifier checks (kind-type table by role
  discovery, subject containment with vacuous pass and unresolvable-dep skip,
  grounding, retired-is-directive); machinery re-attached; loader gate;
  `mix cb.migrate.v2` with full-override `--resolutions`. First dry run on cb:
  forced the **`document:` stipulation amendment**: D6's own confirmed
  re-homes (method:a1-a5, the lib: rules) are document-grounded, so the
  design's plan/user/session list was incomplete against its own intent.
  cb: migrated (76 re-typed; a131/a138/a173 to inference by resolution;
  a387/a438 mechanically via the prescriptive-kind-on-compound rule; **a304
  grounding backfilled** via cb.import - artifact and evidence were both
  empty, the one legitimate backfill shape). codepath: 5 contract re-types.
  Test fixtures updated; 261 green except the sdl integration test, which
  pulled plan-3 forward.
- **Plan-2.** c026-c038 superseded to c051-c056 via cb.adjudicate; c057
  (kind-type table, 38 rows), c058 (containment), c059 (grounding) imported;
  CLAUDE.md render beliefs a445/a446/a447/a452/a468/a469 superseded by
  a477-a482 - including moving "concludes what none of its inputs states
  alone" from the compound to the inference per D3 - and **c048 superseded by
  c060** because render_sections cite belief ids (the regenerated CLAUDE.md
  was silently rendering the old text until the render contract followed).
  Representational dep re-points (a387, c047, c049) cleared `bs stale`.
- **Plan-3.** sdl split per the design's worked table (a006 to a008+a009, a3
  trimmed to a010, a007 re-pointed); toy:a9 to a10+a11; method's 14 mechanical
  re-types plus **method:c10** (verdict binds to inference only - c2's prose
  strain became a check) and the consequent **c2 to c11 enum supersession**
  (c10's own kind needed admitting); agent-behavior's seven triage nodes
  adjudicated (a072 and a123 to inference - a123 the one genuine containment
  escape, a "works because" abduction; six mood re-homes a396-a401, with
  a359's stipulation untangled from its external source); paradigm's three
  syntheses to inference; lib mechanical. All eight collections verified; sdl's
  two teaching FAILs reproduced against a008.
- **Plan-4.** README: the new "Why 'inference' - the edges define the
  territory" section under a rewritten four-types section; every transcript
  regenerated from the live graphs; the sdl worked example now walks all four
  types and reads the split as history; the reference table carries c051-c060.
  Quickstart re-targeted (its compound exemplar a138 is now the inference
  exemplar - "notice the word doing the work: because"); the five skills and
  the design-reference docs updated. Migration recorded as cb:a483.

## 7. "commit" / "push"

`364233f` (composable-beliefs) and `16e2fe8` (belief-collections), both pushed
to main. All gates green on exactly the committed trees.

## Deviations from the design, complete list

1. c026 and c027 added to the supersession list (found by plan-0 preflight).
2. c029 added to the supersession list (found in the pre-decision review).
3. `document:` admitted as a stipulation scheme (forced by D6's own examples).
4. c048 superseded by c060 (render_sections are id-bearing; the design's
   "CLAUDE.md render-section beliefs" list implied but did not name it).
5. method:c2 kept as the kind enum with a new c10 carrying the type bindings,
   then c2 superseded by c11 anyway to admit `derivation-table` - the design
   left "supersede c2 vs new c10" to plan time; the answer was both, for
   different reasons.
6. The grounding rule re-homed ~30 cb: primitives (prescriptive kinds with
   stipulation artifacts), more than the design's "82 primitives unchanged"
   anticipated - the kind-type table forces it.
7. a304 grounding backfill (empty artifact and evidence; plan:cb-schema-v2 as
   the reaffirmation stipulation, reasoning in the evidence entry).
8. cb-dashboard was outside the migration inventory (the design's code
   touch points scoped composable-beliefs only) and broke against the
   migrated library - `stats.unlinked_implications` crashed every dag render.
   Found 2026-06-11 while wiring position deep links; minimal v2 compat pass
   landed as cb-dashboard `5d988ec` (filter buttons, stats rows, kind colors,
   type clauses). The fuller v1-assumption audit followed the same day and
   closed the remainder: the `retired` status surfaced in the status filter
   and color map (the directive-only state existed in the lifecycle but not
   the UI); the materialized panel matched to the real sink shape
   (`{date, todos: [{id, action, result}]}` plus a382's `plan`/`last_verified`
   - it had been reading a nonexistent `object` key); standalone "graphs"
   sources version-gated (they bypass the manifest schema_version check, so a
   graph carrying v1 `implication` nodes now refuses to load with a
   migrate-with-cb.migrate.v2 pointer - migrate, never shim, matching the
   library's hard cutover); stale "contract-grade implication" comments,
   the orphaned `--kind-implication` CSS var, and the policy placeholder's
   v1-era bullet cleaned up.

   Same day, Mark closed the chapter entirely: with every collection migrated
   and no v1 graph left anywhere, the version vocabulary itself was retired
   from the system. The loader's schema_version gate, the manifests'
   schema_version field, mix cb.migrate.v2, and the viewer's standalone-graph
   v1 gate (hours old) were all removed - as far as the system is concerned,
   this is just the schema; an invalid shape fails verification, never a
   version check. "v2" survives only in plan records and immutable graph
   history. (If a pre-migration graph ever resurfaces, the migration tool is
   one git checkout away.)

## Postscript 2 (2026-06-11): the stasis pipeline - obligation moves into the graph

The thread continued past the push into wrap-up. An accounting of the open
threads found three classes: persisted in the repos (kind-enum pruning,
structured dissent, Tidewave, the mission gate, the staged paradigm
extraction), persisted only in session memory (consensual primitives, the
multi-agent consensus direction), and persisted nowhere (the bench stale-id
check). Asked whether to do the residual work now or plan it for later, the
recommendation was: persist now, work later - and persist as graph directives
rather than plan files, since work-to-do is what the directive type and
/materialize exist for.

The user then asked the question that became policy: does this mean plans as
the primary reference for work have migrated to graph nodes? Answer: yes, as
an inversion of roles - the graph is the index of obligation; plans demote to
the artifacts directives materialize into and cite, retained permanently as
sources. The user directed the full pipeline: transcript postscript, the
stance as a position document homed in this repo (his sharpening: the design
intention and policy of the system should live within the system - backed by
the distro-resolvability argument that cb: beliefs must ground in
repo-relative document: URIs), and extraction into cb:.

Executed: positions/2026-06-11-obligation-lives-in-the-graph.md, extracted as
cb:a489-a493 (the obligation index, the plan-as-materialization-artifact rule
with retention, the lifecycle-tag backlog discipline, the position-homing
rule, and the authored-versus-working-time gap as the inference the testing
phase falsifies one way or the other). The deferred work landed as backlog
directives: cb:a494 (consensual primitives), cb:a495 (multi-agent consensus
direction), paradigm:a367 (the now-unblocked eval-architecture extraction) -
all tagged lifecycle:discrete, so `bs list unlinked tag:lifecycle:discrete`
returns exactly the live backlog. The bench and evals repos were grepped for
the split verdicts' old ids (sdl:a006, toy:a9): clean, nothing recorded.

Notable deps surfaced during grounding: a382 (plans encode intent; intent
lives in the DAG) and a380 (active-and-unmaterialized is still-actionable
work) already carried both halves of the policy from the pre-four-type era -
the position extends standing canon rather than minting it.

With this postscript the thread reaches the stasis it was wrapping toward:
plans/ and positions/ hold records and rationale; the graph holds what
remains to be done.

## Postscript 3 (2026-06-11): observability, proportionate ceremony, and the significance exchange

The thread continued toward the first full lap (paradigm:a367). Before it ran,
three things got settled and persisted:

- **The lap log** (cb:a497): live agent-process observability as a scratch
  markdown pane the operator watches in the editor - IDE as UI, the a484-a488
  stance applied. Anchor discipline per codepath canon: the content anchor is
  the truth, the line number a write-time snapshot never copied forward;
  stations that rewrite files re-emit fresh locators. Empirical Zed findings
  (cmd-click follows buffer links; :line suffixes and zed:// URLs open at the
  line; targets resolve relative to the containing file) recorded as evidence
  and in docs/operations.md - tool facts, never claims.
- **Proportionate ceremony** (cb:a496): a position document earns its keep
  when the reasoning is the artifact; observations with an obvious
  prescription go straight in as directives. Minted when the user asked
  whether two tooling-gap findings deserved the position pipeline, then
  caught unpersisted by the user's next question and landed by its own light
  path - the first decision the rule governed was its own persistence, and
  the second was a497's.
- **The significance exchange.** The user asked whether the session
  constituted anecdotal evidence for the system. The calibrated answer - four
  observations (the checks did load-bearing work against their own authors;
  the foundations changed through the system's own front door with no
  maintenance hatch; three concurrent sessions coordinated through the graph
  with no shared conversation memory; the meta-regress terminated in
  practice), the deflators (n=1, no counterfactual, authoring-time only per
  a493), the distinction that anecdote-with-inspectable-trail differs from
  vibes, and the Temporal parallel (event-sourced execution vs event-sourced
  epistemology) - is persisted as paradigm: nodes under the new `anecdote`
  evidence-grade tag (the fixture-tag precedent applied to field use), with
  the self-hosting property landing in cb: as shippable self-documentation.
  The user's own formulation - granular SSOT ensuring DRY, so cognitive cruft
  cannot layer silently - is captured as his observation. The dag-vs-prose
  eval remains the place the felt significance gets adjudicated; these nodes
  are the hypothesis, tagged as such.

## Postscript 4 (2026-06-11): the first lap, and what it caught

The paradigm:a367 lap ran with the live log pane (cb:a497's first use) and
diverted at its first station: the extraction the directive prescribed had
already been performed by another session before the directive was authored -
a367 was minted from stale session memory against a graph that had moved.
Resolution: verified the existing extraction complete (a358-a365 cover all
eight claims), materialized a367 with refs to the pre-existing nodes plus an
evidence entry recording the discovery (discharged, never retracted - the
prescription was sound and the world had already complied), and appended the
incident to cb:a501 as the live specimen for the recency view. The lap that
existed to teach the lifecycle instead demonstrated the failure mode its own
backlog predicts: session memory is not the SSOT of what remains - the graph
is, and the desk query now returns empty for paradigm: with the cb: desk
holding exactly the designed backlog (a494, a495, a499, a500, a501).

## Postscript 5 (2026-06-11): the glue-UI exploration opens

The thread's closing movement opened the next one: an exploration of
observability surfaces, anchored by the operator's stated vision (preserved
here verbatim as source material for its eventual position document):

> my theory is that embracing "IDE as UI" keeps me close enough to the code
> to be able to drop in and audit when necessary, during authoring and
> comprehending, but through the use of higher level documents such as we are
> working towards create a persistent middle ground level of abstraction, UI
> wise, that sits between code and ephemeral chat. [...] my vision is that i
> am able to flow from NL agent discussions to created code, with cb
> underlying everything as the epistemic substrate, and this new sort of
> "glue ui" approach allowing for observability beyond what you get in an
> ephemeral terminal chat

First artifacts, same session: tmp/transcript.md (a live conversation surface
beside the lap log), the three-tier belief-reference convention demonstrated
in it (italic gloss, rendered markdown card, JSON at a write-time-resolved
line - tmp/cards/ prototyped by scratch script), and two backlog directives:
cb:a502 (productize the belief-card renderer) and cb:a503 (settle the
reference convention through use before it hardens to canon). The position
document for the glue-UI stance waits for the exploration to earn it, per
a496's proportionality - the vision is quoted here so the source survives
the session boundary.

## Postscript 6 (2026-06-11): the bootstrap failure - resumption was not in the graph

A fresh thread launched from a prose handoff note failed to bootstrap: it ran
outside the framework repo (so neither CLAUDE.md nor the project-scoped agent
memory loaded), conflated the graph with the operator's older global
assertion system, and could not resolve `bs`, the id scheme, or the glue-UI
context. Its reconstruction from the fragment alone was impressively close,
which sharpened the diagnosis: the system's content was legible, but the
*process to resume work was not self-evident from the graph* - the resume
ritual lived in one agent's session memory and in handoff prose, and the
backlog directives' `session:` stipulation artifacts are dead ends a fresh
agent cannot read (the vision they stipulate from lives in postscript 5, two
hops of tribal knowledge away).

Architectural fixes, landed in response: cb:a507 (directives must be
self-bootstrapping - context reachable through deps and resolvable
document:/plan: artifacts; session: stipulations pair with a document:
pointer), cb:a508 (the session-start ritual as a rendered CLAUDE.md belief:
pull, desk query, stale check, follow each directive's artifacts; graph over
memory), c060 -> c061 (render_sections gains the Session start section),
evidence appends on a502/a503 adding the resolvable pointer to postscript 5,
and the operational rule that sessions launch in the framework repo - the
operating console where the compiled bootstrap actually loads.

## Postscript 7 (2026-06-11): stasis, and the chronicle convention

The thread's final movement: their-thread reconciliation (a516 stamped as
discharged-by-deletion with operator confirmation; the a511 rationale
appended to its position by the thread that held it), the emergence analysis
persisted as the first analysis-class position (paradigm:a376-a378), nine
blog drafts in cb-site wearing the ledger-box receipts format, and three
threads closing through the substrate in interleaved commits. At the very
end the operator asked where threads themselves persist - the answer was
scattered - and observed that prose narrative is his steering bandwidth.
Both became canon: cb:a520 (the chronicle convention - transcript for the
audit, graph for the work, chronicle for the steering) and paradigm:a379
(the observation, his). The epoch's first chronicle was written in the same
change: chronicles/2026-06-10-the-schema-epoch.md. Stasis verified from
three sides; the next session needs nothing from this one.

## Postscript 8 (2026-06-11): the desk starts working - recency, rot, and a fold

The first desk-driven session: bootstrapped cold from the graph per a508
(pull, desk query, stale check - no handoff, no memory), it picked cb:a501
off the backlog and closed the loop the directive predicted. While this
session deliberated, concurrent threads committed a509 out from under its
staged copy and grew the desk from 7 to 16; `mix bs recent` (Graph.recent/2,
pure window scan over dates the records already carry) rendered the burst -
78 events in two days - the moment it compiled.

The discharge surfaced a serialization bug with a lesson attached:
Belief.to_map serialized only keys present in the source JSON (_keys), so a
field assigned after from_map was silently dropped on write. The
materializer reported "Materialized cb:a501 (2 items)" while its link-back
never persisted - caught only because the read-back happened to be run.
Fixed at the root (a non-nil value now always serializes), regression
test added, round-trip verified byte-identical. The error pattern (a tool's
success report taken as proof of persistence) is now
agent-behavior:a405.

The operator then asked for an audit of /assert-session, an origin-system
extract. Verdict: every broken part had cached canon as prose (the a386
digest antipattern in a skill file - dangling a050-a054 ids, policy-kind
primitives violating c057, a write step predating the write flow); every
surviving part was judgment content with no graph counterpart. The
operator removed the case for separation (no mid-session use; no
framework-wide scope wanted) and the skill folded: its extraction
heuristics moved into the operator /end sweep (Step 2 gains the
agent-reasoning-error category), a480 -> a521 (the four-skill list),
c061 -> c062 (CLAUDE.md render re-pointed), c049's dep re-pointed by
mutation batch. Wire records for both adjudications graduate to
proposals/ (15-a480, 16-c061) per the convention settled at close.

Close findings, persisted where they point: the c062 preflight returned
51 bare tag-overlap hits against 1 true match (evidence appended to
cb:a519); the audit's "taxonomy never ported" conclusion was wrong -
agent-behavior: holds a050-a054 and 101 beliefs, invisible to a
one-namespace query (evidence appended to cb:a500, whose case this makes
better than its author did); evidence appends themselves have no front
door and were scripted three times today (minted as cb:a522). The /end
skill gained the retro-pair rule (a507: bare session: slugs minted
mid-session get document: pointers once the chronicle exists) and the
wire-record graduation rule. Chronicle:
chronicles/2026-06-11-recency-and-rot.md.
