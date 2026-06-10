# Plan 1 - Schema groundwork: the `code:` locator and the codepath output-target

Extend the cb schema so a belief can anchor to a precise *within-file* site, and so an
ordered, branching render over claim ids is a first-class output-target. This is the
prerequisite the collapse created: even a read-only codepath (plan-2) needs claims that
point at code and a render-spec that orders them.

**Status:** Executed 2026-06-09 (cb commit b7ddea9; cb:c043 supersedes cb:c040, cb:c044 is the codepath output-target contract).
**Date:** 2026-06-09
**Depends on:** plan-0 (fold + rename).
**Touches:** `beliefs/beliefs.json` (c040, the codepath output-target contract, supporting beliefs); `lib/cb/belief.ex` (artifact parsing); `lib/mix/tasks/cb.verify.schema.ex` (artifact-format + enum checks); possibly `lib/cb/output_target.ex`.

## Context

cb already anchors a belief to a repo file: c040's closed artifact-scheme enum has
`document: "A repository file reference. Form: document:<repo-relative-path>."` A
codepath needs one increment on top of that - a *within-file* locator - plus a render
contract, which c042 already demonstrates for CLAUDE.md. Nothing here is a new concept;
it is two small extensions to mechanisms cb already runs.

## Design

### The `code:` locator (c040)

Add a new scheme to the closed c040 enum:

    code:<repo-relative-path>#<anchor>

- `<anchor>` is a **precise literal substring** of a current line (the same fixed-string
  match the renderer greps for). Precision replaces an occurrence index; if an Nth match
  is ever genuinely needed, encode it in the URI as `#<anchor>@<N>` rather than a sidecar
  field. `occurrence` is not introduced.
- `document:` is unchanged and keeps meaning a whole-file reference. `code:` means an
  anchored site within a file.
- The line number is never stored; it is resolved at render/run time. A missing anchor
  is a maintenance signal, not corruption (surfaced by the renderer in plan-2).

### Anchor encoding and match resolution (specify, do not hand-wave)

A literal substring anchor will contain spaces, colons, quotes, and possibly `#`/`@` -
all of which collide with the URI's own delimiters and the `verify.schema`
artifact-format regex. Pin the grammar:

- Everything after the **first** `#` is the anchor segment, treated as one opaque
  literal string to end-of-value (no further delimiter parsing inside it). The path
  segment before `#` is repo-relative and carries no scheme colon.
- `@<N>` is recognized **only** as an optional trailing `@<digits>` selecting the Nth
  match. If an anchor must literally end in `@<digits>`, percent-encode that suffix
  (`%40<digits>`). This preserves hand-authorability for the common case and gives a
  defined escape hatch for the rare literal `@2`.
- The `verify.schema` artifact-format check must be widened for `code:` to accept this
  richer form (it currently assumes a simple `scheme:id`).

**Multiple matches are the common failure, not the rare one.** `grep -nF <anchor>`
returning three lines is what happens when an anchor is too loose. Defined behavior:
render against the **first** match (so the codepath still presents) **and** emit a
maintenance warning naming the step and the match count, recommending a more precise
anchor. Same philosophy as a missing anchor - a signal, not a crash. This rule is
asserted here and tested in plan-2's acceptance.

Because c040 is a *closed* enum enforced by a contract, this is a real schema edit: the
enum contract, `belief.ex` artifact parsing, and the `verify.schema` artifact-format and
artifact-scheme checks must all learn `code:` in the same change, atomically.

> **Batch known scheme additions (cb:a397).** Each enum value added to c040 supersedes
> the c040 contract. If more than one scheme is genuinely needed, add them in a single
> atomic supersession to halve churn on the closed enum. cb-codepath itself needs only
> `code:` - an `eval:` scheme belongs to the separate sdl / eval-provenance mission
> (its own enum), not here, unless that mission is deliberately merged (see the README's
> open question). Do not co-add it speculatively.

### The codepath output-target (reuse `output-target`)

Reuse the existing `output-target` kind (the c042 mechanism, compiled by
`CB.OutputTarget`) rather than minting a new c035 kind. Define a codepath output-target
as an `output-target` contract tagged `output:codepath` whose render-spec rows carry
navigation:

    entry: <step-id>
    steps:
      - { id: <step-id>, belief: <belief-ref>, goto?: <step-id>, choices?: [ {label, goto} ] }

Carry c042's invariants across:

- `deps` equals the union of the `belief` ids referenced by the steps.
- Every narrated stop traces to exactly one belief's `claim` field (the narration *is*
  the claim, exactly as CLAUDE.md lines are claims).
- Navigation (`goto`/`choices`/`entry`) is render metadata only; it does not enter
  `deps` and does not live in the claim beliefs.

Decide during build whether the step rows reuse `render_sections` or a parallel
`render_steps` field on the contract; either way the compiler/loader is the
`CB.OutputTarget` family, extended to understand navigation rows.

## Steps

1. Add `code:` to the c040 enum contract (claim + the scheme's URI form), via the write
   flow (`cb.preflight` / `cb.adjudicate` / `cb.import`).
2. Teach `belief.ex` (`from_map` / artifact validation) and `verify.schema`
   (artifact-format regex + artifact-scheme enum check) to accept `code:<path>#<anchor>`.
3. Define the codepath output-target contract (tagged `output:codepath`) describing the
   step-row shape and its invariants; extend `CB.OutputTarget` to parse/validate the
   navigation rows (compile/render itself is plan-2).
4. Add schema checks: a codepath output-target's `deps` equals its referenced belief
   ids; every referenced belief exists and carries a `code:` artifact.

## Acceptance criteria

- A claim belief with `artifact: code:lib/cb/belief.ex#def from_map(` validates.
- A codepath `output-target` referencing ordered steps (with `goto`/`choices`) validates,
  with deps-match-sections enforced.
- `mix cb.verify.schema` and `mix cb.verify.collection cb` pass with the new scheme and
  contract in place.
- The closed-enum guarantees still hold: no artifact with an undeclared scheme passes.

## Risks and non-goals

- **Editing a closed enum.** c040 is biconditional and load-bearing; the enum contract
  and every dependent check must change together or verification breaks. Treat as one
  atomic change with `verify.schema` green before and after.
- **Non-goal:** rendering or running anything. This plan only makes the shapes
  expressible and verifiable; plan-2 renders, plan-3 runs.
