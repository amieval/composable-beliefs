# Interactive Code Walkthroughs over ACP

A persistent, refactor-tracking format for **agent-guided walkthroughs of the
codebase**: an author working with the agent to build the app records ordered,
branching "walk this code" paths to a data file; a later session loads that file
and *presents* it - emitting clickable `path:line` references that drive the
editor's viewport, narrating each stop, and offering branch points the reader
chooses. The static layer ships first; a deferred runtime layer (Tidewave) pairs
each stop with live values from the running app.

> Why ACP, not the TUI: the clickable `path:line` -> jump-to-editor behavior needs
> an **editor host** that linkifies the reference and drives its viewport. Zed-over-ACP
> provides exactly that. The capability is host-bound, not format-bound - a browser
> rendering Markdown is sandboxed from the editor and cannot navigate it. This is the
> intended **usage split**: *author/dev the walkthrough in the TUI* (subscription
> pricing, high-token edit/compile/run work); *present it in ACP* (metered, but
> low-token - mostly read-file + emit-refs).

**Status:** Proposed 2026-06-08; architecture revised 2026-06-09 (framework/instance split); all three phases in scope as of 2026-06-09. Nothing built. Phase 1 is pure data + one skill in a new repo, no new infra inside the consuming repos.
**Date:** 2026-06-09
**Depends on:** nothing for Phases 1-2. Phase 3 (runtime) depends on the open-source `tidewave` Phoenix hex package (no subscription) + a booted `cb-dashboard`.
**Touches:** a **new `code-walkthrough/` sibling repo** under `amieval/` (the framework: spec + skill + reasoning); a new `composable-beliefs/code-walkthrough/` instance directory; for Phase 3, `cb-dashboard/mix.exs` + `cb-dashboard/lib/cb_dashboard/endpoint.ex:63`.

## Architecture: framework vs. instances

The format (the spec for *what a walkthrough is*) is separated from the
instantiation of that format (a *particular* walkthrough, e.g. `belief-pipeline`).
This mirrors the codebase's own shape - `composable-beliefs` ships the framework
and tooling while `belief-collections` holds the namespaced instances - and is
the same format/instance discipline the belief graph already lives by (the
schema-as-contract beliefs `c029`/`c038`/`c039` define the shape; individual
beliefs conform to it).

Three parts:

1. **`code-walkthrough/` repo** - a new sibling under `amieval/`, peer to
   `composable-beliefs` and `cb-dashboard`. The **framework**: the format spec,
   the technical implementation (anchor resolution, branching, the
   "anchor not found" maintenance signal), the `present-walkthrough` skill, and
   the abstract reasoning for *why* the format is shaped this way. Domain-agnostic
   - it knows nothing about beliefs.
2. **`composable-beliefs/code-walkthrough/` directory** - the **application**:
   instance(s) conforming to the spec, e.g. `belief-pipeline`, whose anchors point
   at composable-beliefs source. This repo's own walkthroughs, living beside the
   code they walk.
3. **Any other consuming repo** (e.g. `cb-dashboard/code-walkthrough/`) gets the
   same pattern when it wants walkthroughs.

  composable-beliefs (framework + tooling) : belief-collections (instances)
       ::  code-walkthrough (framework + skill) : <repo>/code-walkthrough/ (instances)

The spec changes rarely and lives once, in the framework repo; instances are
plural and live with the code they walk.

## Context

The repo already ships a **prose** "guided tour" - `belief-collections/quickstart.md`
walks a newcomer through the belief graph with CLI commands. This plan does *not*
replace that; it adds a different artifact: an **interactive, editor-anchored**
walkthrough that leads the reader through the *actual source files* rather than code
blocks copied into a doc. Two properties make this worth a format of its own:

- **Refs can't silently fork.** A copied snippet in a wiki is stale the moment it's
  pasted. A `path:line` always opens current truth. (The line *number* drifts on
  refactor - addressed below by anchoring on symbols, not lines.)
- **The reader stays in the real file** - surrounding code, blame, jump-to-definition,
  the running app - instead of an amputated excerpt.

The "presentation is human-driven, not auto-advancing" property is a **feature, not a
limitation** for this use case: it is an audit/comprehension workflow for a person
co-authoring the app. The reader drives; the agent narrates and offers choices. That is
precisely what enables **branching** - a passive renderer could not offer a fork and
wait for a pick.

## Capability boundary (what ACP does and does not give)

| Capability | Available? | Mechanism |
|---|---|---|
| Clickable `path:line` that opens + scrolls the editor | **Yes** | Zed/ACP linkifies the pattern; *reader* clicks, *editor* navigates (pull, not push) |
| Agent narration + ordered steps + branch prompts | **Yes** | The agent emits text from the walkthrough file |
| Agent auto-advances / highlights a sub-range / tracks reader position | **No** | No control channel back to the editor; reframed here as the human-driven feature |
| Live runtime values paired with each step | **Deferred (Phase 3)** | Tidewave MCP eval into the running BEAM - a side channel, *not* driving the terminal pane |

The agent never drives the bottom terminal pane. In Phase 3 the pane simply runs
`mix phx.server`; the agent reaches the runtime through Tidewave's MCP eval tool.

## Design: the format spec (lives in `code-walkthrough/`)

A JSON file (per repo convention: JSON over YAML) holding one or more walkthroughs.
The spec - this shape and its resolution rules - is defined once in the framework
repo and governs every instance.

The critical decision: **anchors are symbols/snippets, not line numbers.** Line numbers
are a cached hint resolved at present-time; the durable key is a string the presenter
greps for. Refactors that move code don't break the walkthrough; only deleting/renaming
the anchored symbol does - and *that* surfaces as a clear "step N anchor not found"
signal that the walkthrough needs maintenance, rather than silent rot.

A walkthrough is a **DAG**, not a list (which mirrors this repo's own belief-graph
domain): steps carry optional `choices` that jump to other step ids. The DAG is
**full, with re-convergence** - multiple steps may `goto` the same node (Q5 resolved).
The presenter just follows `goto`; re-convergence costs nothing and is strictly more
general than linear-with-detours.

Anchor matching is **literal substring + optional `occurrence: N`; no regex** (Q2
resolved). Literal anchors stay trivially hand-editable in the TUI; `def from_map(`
(with the paren) is precise enough without regex machinery, and ambiguity is resolved
by `occurrence` rather than regex anchors. First match wins when `occurrence` is omitted.

```json
{
  "walkthroughs": [
    {
      "id": "belief-pipeline",
      "title": "The pipeline, data -> render",
      "entry": "data",
      "steps": [
        { "id": "data",      "file": "composable-beliefs/beliefs/beliefs.json",          "anchor": "\"id\":",          "occurrence": 1, "note": "Raw data - each object is one belief (id, kind, claim, deps).",
          "choices": [ { "label": "How does raw JSON become a struct?", "goto": "from-map" },
                       { "label": "How is it rendered back out?",       "goto": "formatter" } ] },
        { "id": "from-map",  "file": "composable-beliefs/lib/cb/belief.ex",               "anchor": "def from_map(",   "note": "Boundary: JSON map (string keys) -> %Belief{}.", "goto": "store" },
        { "id": "store",     "file": "composable-beliefs/lib/cb/belief/store.ex",         "anchor": "def read",        "note": "Loads the whole graph off disk." },
        { "id": "formatter", "file": "composable-beliefs/lib/cb/belief/formatter.ex",     "anchor": "def table",       "note": "Renders beliefs to the terminal (ANSI)." }
      ]
    }
  ]
}
```

- `anchor` - a literal substring the presenter resolves to a current line. First match wins; a step adds `occurrence: N` to select the Nth match.
- `note` - the narration for the stop.
- `choices` - optional branch prompts (`label` shown to reader, `goto` is a step id). A step with neither `choices` nor `goto` ends that path.
- `entry` - the starting step id.

## Design: instances (live in `<repo>/code-walkthrough/`)

Each consuming repo owns its walkthroughs in a `code-walkthrough/` directory beside
its code. `composable-beliefs/code-walkthrough/walkthroughs.json` holds the seed
`belief-pipeline` instance above. Instances are plural and may be split per-subsystem
(one file per walkthrough) precisely *because* the spec is defined elsewhere - the
framework repo is the single source of the format, so instance files carry no format
definition, only data.

## Design: the `present-walkthrough` skill (one home, point outward)

The skill is defined **once**, canonically, in the framework repo at
`code-walkthrough/.claude/skills/present-walkthrough/` (Q3 resolved). It is **not**
copied into consuming repos. Instead it is **parameterized by a path to an instance
file**, the same way `mix bs --beliefs <path>` ships in the framework and is pointed
at collections elsewhere (one tool home, point outward - the framework-ships-the-tool
pattern):

```
/present-walkthrough composable-beliefs/code-walkthrough/walkthroughs.json belief-pipeline
```

Launch the agent from the `code-walkthrough` repo (or the `amieval` umbrella) so the
skill is discoverable and the relative instance/anchor paths resolve from the launch
directory. The skill is thin; the instance JSON is the source of truth. Behavior:

1. Read the walkthrough file at the given path; select the walkthrough by `<id>` (list available ids if omitted).
2. Starting at `entry`, for each step: grep `file` for `anchor` (the `occurrence`-th match, default first) -> current line; emit `file:line - note`.
3. Follow `goto` automatically; at a step with `choices`, emit the choices and **stop**, waiting for the reader to pick. The reader's pick names the next step.
4. If an anchor doesn't resolve, emit `! step <id>: anchor "<anchor>" not found in <file>` and continue - a maintenance signal, not a crash.

The skill keeps **all** anchor-resolution logic; the JSON stays pure data, hand-editable
in the TUI.

## Runtime layer (Phase 3, in scope - wire fully, do not half-wire)

Phase 3 is committed (2026-06-09). "Do not half-wire" is now a build-discipline
constraint, not a deferral: wire it end to end (dep + mount + MCP registration +
`eval` returning live values under the inspection-only guard) in one pass - never
leave `eval` fields in instance JSON that don't resolve to a live value. No Tidewave
**subscription** is required: the `tidewave` Phoenix hex package is the open-source
MCP/"Runtime Intelligence" server, usable by any MCP client without a paid plan. The
paid Tidewave Pro/Web coding agent is a separate product and is not used here.

The architecture is already favorable: `cb-dashboard` is Phoenix 1.7 + LiveView on
Bandit and depends on `{:cb, path: "../composable-beliefs"}` (`cb-dashboard/mix.exs:35`),
so `CB.Belief.Store`, the structs, and the materializer are **loaded inside the running
dashboard's BEAM**. Wiring:

1. Add `{:tidewave, "~> 0.4", only: :dev}` (the open-source Phoenix package; pin the exact version at implementation time).
2. Mount it in the dev-only block at `cb-dashboard/lib/cb_dashboard/endpoint.ex:63` (`if code_reloading? do`).
3. Register the Tidewave MCP server (Claude only connects MCP at startup - restart after).
4. Run `mix phx.server` in the bottom pane.

Then a step can carry an optional `eval` (an inspection expression). At present-time the
skill calls Tidewave's eval and pairs the static ref with the live value:

> Step `store` - `CB.Belief.Store.read/0` at `store.ex:13`.
> Live: `CB.Belief.Store.read() |> length()` -> **103 beliefs**; first is `%CB.Belief{kind: ...}`.

This is REPL-augmented guided reading, **not** a breakpoint debugger (no execution halt).
That is the better primitive here - inspect any expression at the narrated moment, with
none of the breakpoint-coordination cost. **Constraint:** `eval` expressions are
**inspection only** (reads), never mutation; enforce by review convention and document it
in the skill's contract. A fourth visualization surface comes free: the dashboard itself
renders the belief graph, so a wired session triangulates editor (code) + agent
(narration/branching) + Tidewave (live values) + dashboard (rendered state).

## Phasing

- **Phase 1 (scaffold framework + first instance, usable alone):** create the
  `code-walkthrough/` repo with the format spec + abstract reasoning + the
  `present-walkthrough` skill (one home, point outward). Seed
  `composable-beliefs/code-walkthrough/walkthroughs.json` with `belief-pipeline`.
  Anchors are literal substrings + `occurrence` from the start.
- **Phase 2 (refactor-resilience proven):** harden anchor resolution and the
  "anchor not found" maintenance signal; add a second instance (e.g. the dashboard
  LiveView flow in `cb-dashboard/code-walkthrough/`) to prove the format generalizes
  across repos.
- **Phase 3 (runtime, in scope):** Tidewave wiring (open-source `tidewave` Phoenix
  package, no subscription); optional `eval` per step; inspection-only guard. Wire
  end to end in one pass - do not half-wire.

## Acceptance criteria

- `/present-walkthrough composable-beliefs/code-walkthrough/walkthroughs.json belief-pipeline` in an ACP session emits ordered `path:line - note` stops; clicking a ref navigates Zed's viewport.
- A branch step stops and waits; the reader's pick resumes at the chosen step.
- Renaming a non-anchored symbol and moving the anchored code does **not** break the walkthrough (line re-resolves); deleting the anchor yields a clear maintenance warning, not a silent wrong line.
- The JSON instance is authored/edited in the TUI and presented unchanged in ACP - the dev/present split holds end to end.
- The skill lives only in `code-walkthrough` and is pointed at an instance path in another repo - no skill copy in the consuming repo.
- (Phase 3) A step with `eval` shows a live value from the running dashboard alongside its static ref.

## Risks and non-goals

- **Line drift** -> mitigated by literal-substring anchors resolved at present-time; the whole reason not to ship raw line numbers as truth.
- **Terminology collision** with the existing prose "guided tour" (`quickstart.md`) -> call these **walkthroughs**, not tours; this artifact *operationalizes* the prose tour into an interactive, editor-anchored, refactor-tracking form, it does not replace it.
- **Tidewave evaluates arbitrary code in the running app** -> restrict `eval` to inspection; never mutation.
- **Non-goal:** a real breakpoint debugger. Explicitly out - REPL-style inspection is the chosen primitive.
- **Non-goal:** agent-driven auto-advance or sub-line highlighting. The human-driven model is the design, not a gap to close.

## Resolved decisions

- **Q1 - Home for the walkthrough data.** Split into two homes by the format/instance
  separation: the **spec** lives once in the new `code-walkthrough/` framework repo;
  **instances** live per-repo in `<repo>/code-walkthrough/` (composable-beliefs gets
  `composable-beliefs/code-walkthrough/walkthroughs.json`), one file per walkthrough
  where it helps.
- **Q2 - Anchor syntax.** Literal substring + optional `occurrence: N`; no regex.
- **Q3 - Skill home.** One canonical home in `code-walkthrough/.claude/skills/`,
  parameterized by an instance path; not copied into consuming repos. Launch from
  `code-walkthrough` (or the `amieval` umbrella) and point outward.
- **Q4 - Phase 3 appetite.** In scope (decided 2026-06-09). All three phases are
  committed; build Phase 3's Tidewave runtime layer end to end. The deciding factor:
  the `tidewave` Phoenix package is open source and needs no subscription, so the cost
  is wiring effort only. "Do not half-wire" carries forward as a build constraint -
  wire it fully in one pass or not at all.
- **Q5 - Branch model.** Full DAG with re-convergence (multiple steps may `goto` the
  same node).

All open questions are resolved; the plan is fully scoped and executable from Phase 1.
