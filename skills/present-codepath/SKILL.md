---
name: present-codepath
description: Present a codepath interactively - a code-anchored cb collection rendered as a narrated, branching tour of real source. Resolves each stop to a clickable path:line, narrates the claim, and waits at branch points for the reader to choose. Read-only.
---

Present a codepath: lead a reader through real source files via clickable
`path:line` references, narrating each stop and pausing at branch points for the
reader to choose. A codepath is a cb collection (claim beliefs anchored by `code:`
artifacts) plus a codepath output-target (the render-spec governed by `cb:c044`:
`entry` + `render_steps` rows carrying `goto`/`choices` navigation). Read-only -
this skill never edits source or the collection.

**One resolver, two faces.** All load-resolve-emit logic lives in `CB.Codepath`,
surfaced by `mix cb.render.codepath`. This skill is the interactive presenter over
it; never re-implement anchor resolution by hand.

## Input

`$ARGUMENTS` is `[<id>] [--beliefs <path>]`:

- `<id>` - the codepath output-target's belief id (`codepath:c001`, bare `c001`) or
  its belief `name` (`belief-pipeline`). If omitted, list what's available and stop.
- `--beliefs <path>` - the collection's `beliefs.json`. The framework's own
  codepaths live at `codepath/beliefs.json`; default to that when the argument is
  omitted and the file exists.

Launch from the repo root the codepath anchors (for the framework's own codepaths,
the cb repo root): step paths resolve against cwd, and the editor host linkifies
the emitted `path:line` refs against the same root.

## Steps

1. List or load via the resolver:
   - List: `mix cb.render.codepath --beliefs <path>`
   - Load: `mix cb.render.codepath <id> --json --beliefs <path>`
   The JSON carries `entry` and `stops`; each stop has `step`, `path`, `line`,
   `claim`, `warnings`, `goto`, and `choices`. The task exits non-zero with
   validation errors if the render-spec is invalid - surface those and stop.
2. Build a step index from the JSON and walk it **interactively from `entry`**
   (the linear stop order in the JSON is the deterministic batch order; you follow
   navigation instead):
   a. Emit the current stop as one line: `` `path:line` - claim `` (backtick the
      ref so the host linkifies it; the reader clicks, the editor navigates).
   b. If the stop carries `warnings`, emit each as `! <warning>` and continue - a
      missing or loose anchor is a maintenance signal that the codepath needs an
      edit, never a reason to stop. A stop with `line: null` emits the bare path.
   c. If the stop has `choices`, emit each label as a numbered option and
      **stop**, waiting for the reader to pick; resume at the chosen step.
   d. Else if the stop has `goto`, follow it automatically.
   e. Else the path ends; say so briefly.
3. Keep narration tight - the claim plus at most one line of your own framing per
   stop. The value is the reader reading the real file, not a wall of agent prose.

## Rules

- Read-only - never modify the collection or any source it points at.
- Emit `path:line` exactly as the resolver returned it this run; never reuse a
  cached line number, and never invent a line for a missing anchor.
- Follow `goto` automatically; **always stop and wait at `choices`** - the human
  drives the branch. Do not auto-pick.
- Re-convergence is normal (two branches may reach the same step). If the reader
  steers into an already-visited step, present it again from the live JSON rather
  than recapping from memory.
- **Gradient off:** stops referencing non-contract beliefs narrate only. Plan-3
  (`plans/cb-codepath/plan-3-assertions-runtime.md`) adds the assertion branch for
  contract-grade stops; until it lands, do not pretend to verify anything.

## Authoring loop (draft -> import)

When helping author or reorder a codepath, remember the c044 discipline: claim
beliefs (the durable nodes) are imported through the write flow as usual, but the
render-spec is **drafted outside the graph** and imported only once the order is
settled - the output-target is itself a belief, so every post-import reorder
supersedes it. Pre-settlement churn belongs in a draft file, not in supersession
history. Verify with `mix cb.verify.collection <namespace>` after importing.
