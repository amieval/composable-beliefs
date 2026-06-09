# Transcript - cb-codepath (the collapse into composable-beliefs)

**Date:** 2026-06-09
**Surfaces:** the composable-beliefs TUI thread (build + decisions), and a parallel
**code-walkthrough agent thread** (Zed/ACP) whose contributions the author pasted in for
adjudication.
**Companion to:** the [`cb-codepath`](README.md) plan set, and its origin record
[`../interactive-walkthroughs-acp/`](../interactive-walkthroughs-acp/plan.md) (now
superseded).

> User turns are kept close to verbatim; assistant and pasted-agent turns are condensed
> to their substance (decisions, file refs, reasoning). The `*-pathfinder` name
> brainstorm is compressed to its outcome per the author's standing "don't persist the
> name discussion" note.

---

## Summary

The thread began as a repo health check, surfaced the dormant `interactive-walkthroughs-acp`
plan, built it (a domain-neutral Claude Code plugin for editor-anchored code
walkthroughs), and then - through a multi-agent design dialogue - **collapsed the whole
idea into composable-beliefs**. The endpoint: a *codepath* is a code-anchored cb
collection that reads as a narrated, branching tour and runs as a test suite, with cb as
the single schema authority. The arc is a worked example of a design getting *simpler and
stronger* by taking cb's own constraints (immutability, c037's routing/execution
boundary, the format/instance discipline) seriously rather than working around them.

### Key conclusions (how we got to the plans)

- **Format vs. instance, then engine vs. data.** Resolving the old plan's open questions
  forced the split between the walkthrough *format* and any *instance* of it - first as a
  separate framework repo, then (as a "service") as a Claude Code plugin: engine
  installed once, data per target repo, no hardcoded paths.
- **The cb examination changed the target.** Asked to look at the plugin "with cb in
  mind," the code-walkthrough agent showed the plugin was reinventing things cb already
  had: contracts as a node type, a closed DSL registry (c035), a pluggable materializer
  `Sink`, and an output-target renderer (c042 renders CLAUDE.md from belief ids). A
  code-anchored claim with a contract assertion *is* a belief.
- **Full collapse beats adjacency.** Inventing a second format would create a second
  schema SSOT - the staleness antipattern cb exists to kill (cb:a386). So: single-source
  the schema in cb; a codepath is a cb collection; the plugin becomes two new
  materialization targets inside cb (a renderer + a dynamic verifier).
- **c037 forces named predicates (the keystone).** Tests inside cb cannot store
  executable strings in the DAG. The fix is sharper than inline `eval`: predicate bodies
  are ordinary repo-resident functions, the contract stores only routing, and `eval`
  *invokes the named predicate* via MCP. The constraint produced the better design.
- **Three readings, three homes.** Navigation (`goto`/`choices`) lives in the mutable
  output-target render-spec; derivation in `deps`; assertion in the routed predicate.
  One node set, no collapsed edge-sets.
- **Scope chosen deliberately.** Drop multi-language utility (target BEAM/Tidewave + the
  cb codebase); fold the tooling into cb and archive the standalone repo; rename
  walkthrough -> codepath everywhere.

### Artifacts produced

- The `code-walkthrough` repo (built, then folded/archived by plan-0) and its
  `belief-pipeline` seed instance in cb.
- This plan set: `README.md` + `plan-0..3` + this transcript.
- A superseded-by relationship onto `interactive-walkthroughs-acp/`.

---

## Thread

**User:** evaluate this repo - anything outstanding to fix or is it functional? confirm
the `interactive-walkthroughs-acp` plan + transcript are present and ready.

**Assistant:** Healthy: clean `--warnings-as-errors` compile, 142 tests passing,
`verify.schema`/`verify.collection`/`generate.claude_md --check` all green, tree clean.
Both plan files present. Minor signal only: 19 unlinked implications, shallow graph. The
plan is ready to execute pending its 5 author-facing open questions.

---

**User:** resolve open questions.

**Assistant:** Resolved three with clear defaults - Q2 literal-substring + `occurrence`
anchors (no regex), Q3 skill in `.claude/skills/` one-home-point-outward, Q5 full DAG
with re-convergence - and put the two genuinely-author calls (Q1 data home, Q4 Phase 3
appetite) as a question.

**User:** *(declines the question)* I want to clarify. Isn't there a spec for the format
that should live separately from the instantiation of it (belief-pipeline)?

**Assistant:** Yes - the plan blurs format vs. instance. The spec is one stable
definition; instances are plural data. Q1 was really two questions.

**User:** there should be a `code-walkthrough` repo for the spec + implementation +
abstract reasoning, then an application of it to composable-beliefs in a
`code-walkthrough/` directory within the repo.

**Assistant:** Confirmed the three-part structure (framework repo : per-repo instance
dir), mirroring `composable-beliefs : belief-collections`. One mechanic left: the skill.
By the `mix bs --beliefs <path>` analogy, the skill is defined once and pointed at an
instance path. Settled "one home, point outward"; rewrote `plan.md` to record Q1/Q2/Q3/Q5
resolved, leaving Q4 open. Committed + pushed.

---

**User:** what is q4 / what does "do not half-wire" mean / would I need to subscribe to
Tidewave?

**Assistant:** Q4 = Phase 3 (Tidewave runtime) appetite. "Do not half-wire" = build the
runtime end to end or leave it a clean stub; never a dead-config middle. Verified: the
`tidewave` Phoenix hex package is open-source, no subscription (the paid Tidewave
Pro/Web is a separate product). 

**User:** put phase 3 in scope and update the plan.

**Assistant:** Marked all three phases in scope, recorded the no-subscription fact, moved
Q4 to resolved. Committed + pushed.

---

**User:** scaffold phase 1 - create the code-walkthrough repo.

**Assistant:** Built the framework repo (`README.md`, `SPEC.md`, `present-walkthrough`
skill) + a `belief-pipeline` seed instance in cb. Verified all four anchors resolve
(beliefs.json:3 -> belief.ex:166 -> store.ex:13 -> formatter.ex:37). git-init,
remote `amieval/code-walkthrough` (public), pushed both.

**User:** shouldn't the skill prompt for the target rather than hardcoding repo paths -
imagine 3rd parties.

**Assistant:** Right - the skill is the consumed artifact. Made it domain-neutral:
resolve paths from cwd, *ask* for a base dir only when they do not resolve; no hardcoded
project layout. Genericized Phase 3 wording too.

**User:** code-walkthrough is a service - it must operate on any codebase. Better to be a
dir dropped into a target and launched from there?

**Assistant:** The path instinct is right (launch from target root, cwd-relative
resolution), but a nested `code-walkthrough/.claude/skills/` would not be discovered.
Separated engine (install once) from data (per-target). Three distribution models:
global install, vendored, **plugin** (recommended for a service).

**User:** either way, no hardcoded paths for a service.

**Assistant:** Repackaged `code-walkthrough` as a Claude Code plugin
(`.claude-plugin/plugin.json` + `marketplace.json`, skill under `skills/`), validated
with `claude plugin validate`, scrubbed all family paths from the engine (only the
plugin's own distribution identity remains), and made the seed instance root-relative.
Committed + pushed both repos.

---

**User:** *(naming)* rename to something with "pathfinder"? ... does this plugin even use
composable beliefs? could be `cb-pathfinder`.

**Assistant:** *(condensed)* Flagged `ast-pathfinder` as inaccurate (no AST) and
`code-pathfinder` as taken (shivasurya/code-pathfinder, an AST/SAST MCP tool). At that
point the plugin did **not** use cb, so `cb-pathfinder` would mislabel it. *(The name
later resolved to `cb-codepath` once the collapse made the cb coupling real and
intended.)*

---

**User:** *(pastes the code-walkthrough agent's "examine with cb in mind" analysis)* what
do you think?

**code-walkthrough agent (separate thread):** contracts are already a cb node type with a
closed DSL registry (c035) and interpreters; the materializer has a pluggable `Sink`;
`verify.schema` is a contract-driven runner. Frame: "one source, several projections" -
a walkthrough and a test suite are two **sinks** of the same materialized contract; the
missing field is `eval` promoted from inspect to `read + expect`.

**Assistant:** *(verified the cb claims, then critiqued)* `eval`+`expect` is the keeper
and is separable from the grand frame. But "two sinks of one contract" overstates:
walkthroughs are mostly authored narrative, not contract projections; generation
direction is backwards; the shared substrate is thin. The cautions (edges differ;
anchor=bookmark vs eval=teeth; don't vendor cb) are the best part. Static vs dynamic
verifier must stay distinct. Prior art: doctests / Gherkin executable specs.

**User:** 1 - isn't this just a scenario? 2 - agreed. 3 - unsure, discuss more. Re the
internal contradiction: the contract DSL is non-optional, so this puts us in claims-engine
territory. *(pastes the agent's c042/output-target update)*

**code-walkthrough agent:** recants the "schema authority" half of "don't vendor" -
single-source the schema in cb (a386). c040 already has `document:<path>`; a codepath is
that + a within-file locator. Maximalist "it IS cb": claim = belief; test run =
generalized `verify.schema`; the walkthrough = an `output-target` like c042, rendered by
the skill. Navigation lives in the output-target (mutable), claims stay immutable - three
readings, three homes.

**Assistant:** *(verified c042 + `CB.OutputTarget` are real and general)* This resolves
#3 - I was wrong that it's adjacent to cb; "it's a cb output-target + a dynamic verifier"
is the honest description. Named the consequences of going claims-engine: this session's
plugin gets reframed (SPEC demoted to renderer contract); "domain-neutral" narrows to
"any codebase that adopts cb's claim schema"; "generalize verify.schema" understates that
the live-assertional runner is a *new dynamic mode*, not a target swap.

**User:** *(pastes the agent's final contribution)* render a verdict, absorb what's
convincing, propose a series of plans.

**code-walkthrough agent (final):** full collapse + c037 forces tests to be **named
predicates**, not inline assertions - predicate bodies are repo-resident code, the
contract stores routing, `eval` invokes the named predicate via MCP. A step is a
gradient (narrate-only vs narrate+run). A test run is a materialization (`Sink.Test` ->
`belief.materialized`). Drop `occurrence`; mind output-target supersession churn
(draft-then-import).

**Assistant:** Verdict: strongest contribution of the thread; the c037 -> named-predicate
move is the keystone (a constraint producing a *better* design). Absorbed the gradient
step, `Sink.Test`, the `occurrence`/churn cleanups. Two things it underweights: the
collapse **inverts the cost curve** (no cheap inline-`eval` PoC; schema is now a
prerequisite, runtime test layer is last and heaviest), and the dynamic verifier is a new
runner, not a generalization. Multi-language federation is hypothetical and moot for the
BEAM target. Proposed a 4-plan series; asked the one decision that placed every file:
repo fate.

**User:** drop the multi-language obligation - the goal is the best, most progressive,
most functional thing, not general utility (that can come later). Substitute "codepath"
for "walkthrough" everywhere, in the plan and the current codebase. Fold into cb. Author
plans.

**Assistant:** Authored `plans/cb-codepath/` - index + plan-0 (fold + rename) + plan-1
(`code:` locator and codepath output-target) + plan-2 (`present-codepath` renderer,
assertions off) + plan-3 (named predicates + `Sink.Test` + dynamic verifier, assertions
on). Committed + pushed. Captured the walkthrough->codepath rename as plan-0's task rather
than running it mid-flight (entangled with the fold).

---

## Where it stands at thread close

- **Decided:** full collapse into cb; codepath terminology; fold + archive the standalone
  repo; single-language (BEAM/Tidewave) target; the locked defaults in the
  [README](README.md) (code: scheme, reuse output-target, sibling verifier,
  draft-then-import).
- **Built:** the plan set (committed, pushed). Nothing under `beliefs/` touched yet.
- **Open / next:** execute plan-0 (mechanical, depends on nothing) - including whether to
  run the walkthrough->codepath rename as an immediate standalone pass or with the fold.
  plan-1 is the first `beliefs/` change. The final fork from the dialogue still to settle
  in build: does the dynamic verifier reuse `verify.schema`'s role-discovery wholesale or
  ship as a fully separate task (the plans default to sibling).
