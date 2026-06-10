# Transcript - cb-codepath execution (plans 0-3A + the housekeeping batch)

**Date:** 2026-06-09
**Surfaces:** a single composable-beliefs TUI thread (Fable 5), picking up the plan set
the design thread produced and executing it end to end.
**Companion to:** the [`cb-codepath`](README.md) plan set and the design-thread record
[`transcript.md`](transcript.md). Where that transcript records how the design was
reached, this one records how it was built.

> User turns are verbatim (they were short). Assistant turns are condensed to their
> substance: what was read, what was decided, what was written, what went wrong, and the
> commits. Tool output is summarized, not reproduced.

---

## Summary

One session executed the entire plan set: plan-0 (fold + rename + archive), plan-1 (the
`code:` locator and the codepath output-target schema), plan-2 (the resolver, the linear
renderer, the `belief-pipeline` collection, the skill rewrite), plan-3 Step A (named
predicates, `Sink.Test`, the dynamic verifier), and a closing graph-housekeeping batch
the session itself surfaced. Five commits in composable-beliefs
(`4bf56e7`, `b7ddea9`, `c911518`, `4a7ce24`, `53472fa`), one in belief-collections
(`a28ef38`), one in the archived code-walkthrough repo; all pushed. The `cb:` graph grew
103 -> 114 beliefs across 12 adjudicated supersessions and 3 imports, every write
through the flow, every graph diff verified semantically exact before committing.

### What execution surfaced that the plans had not

- **The artifact-format regex needed no widening.** Plan-1 expected `verify.schema`'s
  `scheme:id` check to reject the richer `code:` form; the regex (`^[a-z][a-z0-9_-]*:.+`)
  was already permissive. The real constraint went the other way: a new
  `code: locator format` check pins the grammar via the shared parser (`CB.CodeLocator`).
- **Adjudication assigned bare ids into a namespaced graph.** The successor of `cb:c040`
  would have been written as bare `c043` (the documented Stage-1 deferral of namespace
  assignment). Fixed in lib before the write: an adjudication outcome always has one
  belief whose namespace *is* known - the conflicting one - so successors now inherit it
  (`inherit_namespace/2`); bare conflicting ids still yield bare ids.
- **Preflight walls.** Any proposal tagged `dag-schema` matches every schema belief by
  single-shared-tag, and any match on a contract escalates to contract-level - 37
  "conflicts" per plan-1 proposal, all noise except c040 itself. Handled by substantive
  review (recorded in evidence), tag hygiene on the design primitive, and the one real
  adjudication. Flagged as a future matcher improvement: `dag-schema`-tagged proposals
  are effectively un-preflightable.
- **Contract-grade stops must be implications.** Plan-3's "the claim beliefs become
  contract-grade" collides with c031 (`contract: true` iff implication type), so raising
  a stop's gradient is a *supersession that changes structural type*, not an edit. The
  three downstream stops went primitive/compound -> contract-grade implication with the
  claim and anchor carried verbatim and the assertion sentence appended.
- **The catalogue gap.** `cb:c042` (kind `output-target`, non-empty rules) had sat
  outside c035's closed rule-kind catalogue since 2026-06-07, violating its own "new
  kinds require updating this contract" invariant - unenforced, so unnoticed. The
  housekeeping batch closed it (c046 adds the output-target row).
- **Supersession cascades are real but bounded.** `bs stale` flags active non-primitives
  depping superseded nodes, so superseding c035/c042 forced re-points of c037/c044 (and
  c045, which the session itself had just created depping c037). Mapping the dependency
  closure *before* the batch kept it to exactly seven supersessions, applied in an order
  that never left the graph stale at rest.
- **Prose ids vs. future ids.** A successor's claim must not name an id that the same
  batch is about to supersede (or worse, one that does not exist yet). The Schema-line
  successor (a468) therefore got the minimal `c040 -> c043` swap only; the codepath
  mechanism's CLAUDE.md visibility went through the Skills line instead.
- **`Store.write` churns map key order.** Any write re-serializes the whole graph and
  plain maps inside `rules` re-order. Countermeasure adopted throughout: semantic
  (sorted-keys) diff against HEAD before every commit, asserting the change set exactly.

### Where the gradient landed

`mix cb.render.codepath belief-pipeline` narrates four anchored stops with the entry
branch; `mix cb.verify.codepath belief-pipeline` reports the data stop as narrate-only
and PASSes the three routed predicates; `--record` binds dated pass/fail history to each
contract stop's `materialized` field (re-runs replace). The data stop was deliberately
left narration-only so the shipped example demonstrates the gradient rather than just
asserting everywhere. Step B (Tidewave federation) remains deferred until a predicate
genuinely needs live app state.

---

## Thread

**User (handoff):** "You're picking up implementation of cb-codepath in the
composable-beliefs repo... read [the plan set] - they are the source of truth, don't
re-derive the design... Start with plan-0... Begin by reading the plan set, then tell me
your plan-0 execution steps before running them." Mid-read: "ask questions as necessary,
and raise any issues you encounter."

**Assistant:** Read README + plans 0-3, surveyed the artifacts: the standalone repo
(clean, 2 commits), cb's `skills/` + `.claude/skills/` symlink pattern, and the full
`grep -ri walkthrough` footprint. Found no code references to the instance - plan-0 was
files and docs only. Proposed the six plan-0 steps and asked three questions
(AskUserQuestion): how to treat cb README's "Walkthrough: tracing an eval verdict"
tutorial section; whether to fully archive the standalone repo (commit + push +
`gh repo archive`); and commit policy.

**User (via answers):** Reword the README section to "Worked example" (recommended
option); yes, full archive now; commit when green.

**Assistant (plan-0, commit `4bf56e7`):** Enumerated the grep whitelist into plan-0
itself (its own acceptance criterion); folded the skill as `skills/present-codepath/`
(+ symlink), carrying `SPEC.md` forward verbatim as `spec-notes.md` with a
not-an-authority header; `git mv` rename to `codepath/codepaths.json` with the top-level
key renamed; superseded-by banner + status rewrite on `interactive-walkthroughs-acp/plan.md`
(noting honestly that phases 1-2 *had* been built, contra its stale "Nothing built"
line); README reword; pushed a pointer README to `amieval/code-walkthrough` and archived
it on GitHub (`isArchived: true`). Issues raised: the new SKILL.md initially failed its
own grep (reworded rather than whitelisted); `belief-collections/library/README.md`
generic hit left as out of scope.

---

**User:** "proceed"

**Assistant (plan-1, commit `b7ddea9`):** Studied the enforcement chain before touching
anything: c040's enum-registry shape, the verifier's role discovery, `CB.OutputTarget`,
and the full write flow (preflight/adjudicate/import). Three findings shaped the work:
the artifact regex needed no widening (see Summary); adjudication would assign a bare
successor id (fixed in lib first - namespace inheritance, with tests); and
`schema_contracts_test.exs` pins `cb:c040` as active, so the test had to move to the
successor within the same atomic change.

Code: `CB.CodeLocator` (first-`#` split, opaque anchor, trailing `@N`, `%40<digits>`
escape decoded only as a trailing suffix); verifier checks `code: locator format` and
`codepath output-targets`; `OutputTarget.validate_codepath/2` + `codepath_target?/1`
(decision taken: parallel `render_steps` field, not overloaded `render_sections`).

Graph (write flow): `cb:a467` (design-rationale primitive anchored to plan-1) imported;
`cb:c043` superseded `cb:c040` via adjudicated `accept_supersede` (the enum gains `code`;
`eval:` deliberately not co-added per the plan's default); `cb:c044` imported (the
codepath output-target contract - invariants only, `rules: []`, which also keeps it
exempt from c035's catalogue invariant). Preflight produced 37-match tag-overlap walls;
reviewed substantively (c035/c037/c038 in particular), one real conflict (c040),
review recorded in a467's evidence. Flagged two pre-existing gaps for later: CLAUDE.md's
a451 prose naming c040, and c042 sitting outside the c035 catalogue. Acceptance: all
four criteria green; 172 tests.

---

**User:** "commit and proceed"

**Assistant (plan-2, commits `c911518` + belief-collections `a28ef38`):** Confirmed
plan-1 was already committed; proceeded. Sized the deferred CLAUDE.md/catalogue batch
first (bounded one-hop cascades, ~6 supersessions) and explicitly deferred it as the
steward's call rather than folding it into plan-2.

Code: `CB.Codepath` - the one tested resolver (validate, depth-first traversal from
`entry` with re-convergence visited once, per-line literal anchor matching; loose
anchors render first match + tighten warning, explicit `@N` warns only out of range);
`mix cb.render.codepath` (list / render / `--json`); `OutputTarget.rules_map/1` made
public and shared. One syntax stumble: `~s(...)` terminated early on a `(es)` inside the
sigil.

Collection: `codepath/` manifest (`depends_on: ["cb"]`), registry entry in
belief-collections, then the write flow against the collection file via `CB_BELIEFS`:
claims `codepath:a001-a004` imported first, the settled render-spec `codepath:c001`
imported last (the draft -> import loop), `name: belief-pipeline` backfilled and
`find_target` taught belief names. `codepaths.json` retired. `verify.collection
codepath` 18/18 with the codepath check passing live; all four anchors resolved
(`beliefs/beliefs.json:3`, `belief.ex:166`, `store.ex:13`, `formatter.ex:37`); an
anchor-rot guard test resolves the shipped codepath against real source in CI. Skill
rewritten as the interactive face over `--json`.

**Assistant (plan-3 Step A, same turn, commit `4a7ce24`):** Read the materializer/Sink
seam and the `Implies` interpreter - the routing reuse was exact:
`{"when": {"assertions": "on"}, "requires": "<predicate>"}` interpreted by the existing
`CB.Belief.Contract.Implies`.

Code: `CB.Codepath.Predicates` (the four pipeline predicates + `resolve/2` enforcing the
inspection-only gate: names end in `?`/`_check`, exported zero-arity booleans only;
`invoke/2` normalizes false/raise/non-boolean/bad-name/unknown to failures and is shared
by both callers); `CB.Codepath.Assertions` (contract-grade stops assert, others
contribute nothing - the gradient); `CB.Materializer.Sink.Test` (persisting an action
item = invoking its predicate, refs carry pass/fail); `mix cb.verify.codepath` (sibling
of `verify.schema`, never a generalization; `--record` replaces dated materialized
history; `--json` feeds the skill).

Graph: c031 forces implication type, so `codepath:a002/a003/a004` were superseded by
contract-grade `codepath:c002/c003/c004` (claims + anchors verbatim, assertion sentence
appended, deps re-pointed to active successors), then the render-spec `c001 -> c005`.
The data stop stayed narration-only on purpose. `cb:c045` imported: inspection-only as a
contract, not a convention. End-to-end run: 3 PASS, 1 narrate-only; `--record` written
and re-run-replaces confirmed; 188 tests.

Report closed by putting the housekeeping batch (by then sized at ~6-7 supersessions
including the c045 -> c037 cascade the session itself had just created) on the user's
desk.

---

**User:** "commit and proceed"

**Assistant (housekeeping batch, commit `53472fa`):** Everything already committed;
"proceed" ran the batch. Re-mapped the full dependency fan-in first (confirming the
closure terminates at c044/c045), adjusted one design point to avoid prose naming
future ids (a468 = minimal `c040 -> c043` swap only), then built all seven adjudication
records programmatically from the live graph and applied them in dependency order:

- `a451 -> a468` (Schema line names c043), `a453 -> a469` (Skills line gains
  `/present-codepath`; "authoring, query, and presentation")
- `c035 -> c046` (catalogue gains the output-target row: singleton `field(Name, Spec)`
  maps, interpreter `OutputTarget`, per-shape fields enforced by the interpreter per tag)
- the cascade, content verbatim except one re-point each: `c037 -> c047`,
  `c042 -> c048` (render_sections to a468/a469), `c044 -> c049`, `c045 -> c050`

All seven landed with the predicted ids. CLAUDE.md regenerated from c048 - exactly the
two prose lines changed. Module docs and the skill re-pointed at c047/c049/c050 (files
are freely editable; graph prose left to resolve via supersession chains). Semantic
diff: exactly 7 flips + 7 successors. No stale beliefs at rest; all verifiers and 188
tests green; the assertions still pass.

---

**User:** "push"

**Assistant:** Pushed composable-beliefs (`b8039af..53472fa`, the five session commits)
and belief-collections (`373629f..a28ef38`). The archived repo had been pushed during
plan-0.

**User:** "persist this entire thread alongside the plans that were just done"

**Assistant:** This file (commit `ee52ade`), linked from the plan-set README alongside the
design transcript.

---

**User:** "commit. great. now refactor the readme, if not rewrite from scratch. do not
concern yourself with brevity, concern yourself with comprehensiveness and thoroughness"

**Assistant (commit `4a7d611`):** Rewrote the repo README from scratch (445 -> 695
lines), every embedded output captured from live runs. The old README predated the
codepath capability entirely and rendered superseded graph state (`cb:c040` shown
active; a 16-check sdl verify run). New coverage: the artifact-scheme table including
`code:`, the full rule-kind catalogue with interpreters, the current active
schema-contract family with supersession lineage, the complete command surface, and new
Collections / Codepaths / Output-targets sections with real render + verify output. The
sdl worked example kept as the centerpiece with stale outputs recaptured; its ending
upgraded from hypothetical to demonstrated - the a397 "adding an enum value supersedes
the enum contract" rule shown having actually run (`bs history cb:c043` plus the full
successor record with its adjudication evidence). Pushed.

---

## Where it stands at thread close

- **Done:** plans 0, 1, 2, 3-Step-A, and the housekeeping batch. The codepath capability
  is live end to end: authored as a cb collection, verified statically
  (`verify.collection codepath` 18/18), rendered linearly and interactively, asserted
  dynamically with recorded history.
- **Active contract id map after the batch:** artifact-scheme enum `c043`, codepath
  shape `c049`, inspection-only `c050`, routing boundary `c047`, rule-kind catalogue
  `c046`, CLAUDE.md target `c048`; the belief-pipeline render-spec is `codepath:c005`.
- **Open, by design:** plan-3 Step B (Tidewave federation) waits for the first predicate
  that genuinely needs live app state. Do not build it speculatively.
- **Noted for the future:** the preflight matcher's tag-overlap escalation makes
  `dag-schema`-tagged proposals effectively un-preflightable; `Store.write`'s map-key
  reordering inflates graph diffs (the semantic-diff-before-commit habit compensates).
