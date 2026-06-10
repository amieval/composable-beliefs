# Plan 2 - `present-codepath`: render a codepath (assertions off)

Turn the schema shapes from plan-1 into a working, narrated, branching render of a real
cb collection. This is the codepath at its lower gradient: read-only, no runtime, fully
usable on its own as a guided walk. It also reauthors the seed `belief-pipeline` from a
standalone JSON file into a proper cb collection.

**Status:** Executed 2026-06-09 (codepath: collection + CB.Codepath + mix cb.render.codepath + the present-codepath skill rewrite).
**Date:** 2026-06-09
**Depends on:** plan-1 (the `code:` locator and the codepath output-target).
**Touches:** a new cb collection for `belief-pipeline` (claim beliefs + the codepath output-target); the `present-codepath` skill in `.claude/skills/`; possibly a small loader/resolver helper in `lib/cb`.

## Context

Plan-0 renamed the standalone instance; this plan replaces its *format*. The
`belief-pipeline` codepath already knows its four stops (`beliefs.json` ->
`Belief.from_map/1` -> `Store.read/0` -> `Formatter.table/2`); reauthored as a cb
collection, each stop is a claim belief and the order/branching is an output-target.

## Design

### Reauthor `belief-pipeline` as a cb collection

- **Four claim beliefs**, each `artifact: code:<path>#<anchor>`, with the narration as
  the `claim` and `deps` reflecting the logical relationship (e.g. the `from_map` belief
  depends on the raw-data belief). Kind is `primitive`/`compound` as fits; none need to
  be contract-grade yet (assertions arrive in plan-3).
- **One codepath output-target** tagged `output:codepath`: `entry` plus ordered steps
  referencing the four belief ids, with the branch at the entry stop expressed as
  `choices`.

### Authoring loop (avoid supersession churn)

A codepath render-spec gets reordered constantly while authoring, and the output-target
is itself a belief - so each reorder would supersede it. Author the render-spec as a
**draft outside the graph** and `cb.import` it only once the order is settled. Document
this draft -> import loop in the skill notes; the claim beliefs (the durable nodes) are
imported normally, the ordering is imported last.

### The `present-codepath` skill

Read-only interactive renderer (the `cb.generate.claude_md` analog, but interactive
rather than batch, because it narrates and waits at branches):

1. Load the collection (`mix bs --beliefs <path>` or a loader helper); select the
   codepath output-target by id (list available ids if omitted).
2. From `entry`, for each step: resolve its belief's `code:` anchor by fixed-string grep
   (`grep -nF`) to a current line; emit `` `path:line` - claim `` (backticked so the
   editor host linkifies it).
3. Follow `goto` automatically; at a step with `choices`, emit them and **stop**, waiting
   for the reader to pick.
4. Anchor not found -> emit a maintenance warning naming the step and continue; never
   crash.
5. **Gradient off:** steps referencing non-contract beliefs narrate only. (Plan-3 adds
   the assertion branch for contract-grade beliefs.)

The skill lives in cb and is launched from the cb repo root, so step paths resolve from
cwd and the editor host linkifies against the same root.

### A deterministic renderer alongside the skill

Add a non-interactive `mix cb.render.codepath <id>` that emits the codepath linearly
(branches listed inline rather than waited on). The interactive skill is the product, but
the mix task makes the render **testable in CI and harness-independent**, and it is the
same code path the eventual HTML audit-tree export will reuse. Small addition,
disproportionate payoff: the skill orchestrates presentation, the task owns
load-resolve-emit so both share one tested resolver.

## Acceptance criteria

- `present-codepath` on the `belief-pipeline` collection emits ordered `path:line -
  claim` stops; clicking a ref navigates the editor; the entry branch stops and waits,
  and the reader's pick resumes at the chosen step.
- Reordering the render-spec draft and re-importing changes presentation order **without**
  superseding or churning the claim beliefs. (Honest scope: the draft-then-import loop
  covers *pre-settlement* churn only - once imported, a reorder supersedes the
  output-target belief itself. Only the claim beliefs are protected; the ordering carries
  honest supersession history. State this so the criterion is not read as a stronger
  guarantee.)
- Moving anchored code re-resolves the line; deleting an anchored symbol yields a clear
  maintenance warning, not a silent wrong line.
- An anchor matching **multiple** lines renders against the first match and emits a
  "tighten this anchor" warning with the match count (per plan-1's rule).
- `mix cb.render.codepath` produces the same stops deterministically and is covered by a
  test (the harness-independent proof of the resolver).
- The collection passes `mix cb.verify.collection`.

## Risks and non-goals

- **Skill discovery.** The skill now lives in cb's `.claude/skills/`; presenting a
  codepath means launching the agent from the cb repo root. Document this.
- **Anchor resolution is still literal grep** - by design (refactor-resilient, hand
  authorable). Precise anchors are the author's responsibility; the maintenance warning
  is the safety net.
- **Non-goal:** running assertions or touching a live app. That is plan-3.
