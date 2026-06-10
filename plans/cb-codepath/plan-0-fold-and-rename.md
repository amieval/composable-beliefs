# Plan 0 - Fold into cb, rename walkthrough -> codepath

Mechanical groundwork: collapse the standalone `code-walkthrough` repo into
composable-beliefs, rename the artifact from "walkthrough" to "codepath" across the
current codebase, and reconcile the superseded prior plan. No schema changes, no
runtime. This clears the ground so plans 1-3 build on a single, consistently-named home.

**Status:** Executed 2026-06-09 (cb commit 4bf56e7; standalone repo archived).
**Date:** 2026-06-09
**Depends on:** nothing.
**Touches:** the `code-walkthrough` repo (archived); `composable-beliefs/code-walkthrough/` (renamed); the `present-walkthrough` skill; `plans/interactive-walkthroughs-acp/` (marked superseded).

## Context

`code-walkthrough` was built this cycle as a domain-neutral Claude Code plugin with its
own format spec. The design discussion then collapsed it into cb (see
[README](README.md) decision record), so the standalone repo's reason for existing - a
self-contained, cb-independent format - is gone. Its durable assets are the
`present-walkthrough` skill (becomes the cb renderer) and the reasoning in its
`SPEC.md`/`README.md` (becomes input to plan-1's schema work). Everything else is
retired.

## The rename rule

Substitute **codepath** for **walkthrough** wherever "walkthrough" names *this
artifact*. Preserve generic English ("walk through the graph") and the existing prose
"guided tour" in `README.md`/`quickstart.md` where it does not refer to the artifact.
Concretely:

- `present-walkthrough` skill -> `present-codepath`
- `walkthroughs.json` -> `codepaths.json`
- `code-walkthrough/` directory -> `codepath/`
- "the walkthrough" / "a walkthrough" (the artifact) -> "the codepath" / "a codepath"
- Historical transcripts (`interactive-walkthroughs-acp/transcript.md`) are left
  verbatim as a record; a one-line note marks the terminology change rather than
  rewriting history.

## Steps

1. **Fold the engine into cb.** Move the `present-walkthrough` skill into cb's
   `.claude/skills/` as `present-codepath` (plan-2 fleshes out its behavior against the
   new schema). Carry the `SPEC.md` reasoning forward as notes feeding plan-1; the spec
   itself is *not* re-homed as a format authority - cb's schema becomes the authority.
2. **Rename the current cb instance.** `composable-beliefs/code-walkthrough/` ->
   `composable-beliefs/codepath/`; `walkthroughs.json` -> `codepaths.json`. This is an
   interim terminology rename; plan-2 reauthors the file's *format* as a cb collection.
3. **Sweep terminology** across active cb artifacts per the rule above (the
   `interactive-walkthroughs-acp/plan.md` references, any `README.md` artifact-name
   uses). Leave generic prose and historical transcripts intact.
4. **Archive the standalone repo.** Mark `amieval/code-walkthrough` (GitHub
   `amieval/code-walkthrough`) deprecated: a short README pointer to cb's codepath home,
   and archive the GitHub repo. Do not delete - it holds the plugin-era history.
5. **Reconcile the prior plan.** Add a superseded-by banner to
   `interactive-walkthroughs-acp/plan.md` pointing at `plans/cb-codepath/`, preserving
   it as the origin record (the way `plans/superseded/` already works).

## Acceptance criteria

- **Mechanical rename check (falsifiable exit):** `grep -ri walkthrough` across active
  artifacts, excluding `transcript.md` files and the whitelist below, returns empty.

  Whitelist (enumerated 2026-06-09, before execution):
  - `plans/interactive-walkthroughs-acp/plan.md` - the superseded origin record; kept
    verbatim under its banner, all hits whitelisted.
  - `plans/cb-codepath/README.md` and `plans/cb-codepath/plan-0-fold-and-rename.md` -
    self-referential mentions of the old name (they define the rename).
  - `plans/done/toy-domain-onramp.md:93` - "the guided walkthrough", generic prose in a
    completed plan.
  - `plans/cb-codepath/spec-notes.md` - the archived repo's SPEC.md carried forward
    verbatim as plan-1 input (pre-rename terminology, marked as such in its header).
  - The `_build/`, `deps/`, and `.git/` directories are excluded as non-artifacts.

  The top-level `README.md` tutorial section formerly titled "Walkthrough: tracing an
  eval verdict to its evidence" is reworded to "Worked example" rather than whitelisted
  (decided 2026-06-09) - it never named this artifact, and rewording removes the
  ambiguity. `belief-collections/library/README.md:19` ("this walkthrough", generic
  tutorial prose in the sibling repo) is out of this repo's grep scope and left as is.
- No active cb artifact uses "walkthrough" to name the artifact; `present-codepath` and
  `codepaths.json` exist in cb.
- The standalone `code-walkthrough` repo is archived with a forward pointer; nothing in
  cb depends on it.
- `interactive-walkthroughs-acp/plan.md` is clearly marked superseded by this set.
- `mix compile` and the existing test suite are unaffected (no code paths touched yet).

## Risks and non-goals

- **Over-eager substitution.** Blindly replacing the word "walkthrough" would corrupt
  generic prose. The rule above scopes it to artifact-name uses; review the `README.md`
  and `quickstart.md` hits by hand.
- **Non-goal:** any schema or format change. The instance keeps its current standalone
  JSON shape until plan-2 reauthors it; plan-0 only renames.
