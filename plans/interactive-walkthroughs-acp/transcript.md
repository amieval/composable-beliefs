# Transcript — Interactive Walkthroughs over ACP

**Date:** 2026-06-08
**Surface:** Zed editor, talking to the agent over ACP (Agent Client Protocol)
**Companion to:** [`plan.md`](plan.md) (the plan this thread produced) and [`../dashboard-residue-scrub.md`](../dashboard-residue-scrub.md) (a side-quest scrub plan)

> Note: user turns are verbatim; assistant turns are condensed to their substance
> (decisions, file references, reasoning) for readability. Two large pasted
> `beliefs.json` symbol-outline context blocks (~1849 symbols each, injected by Zed's
> `@`-mention) are elided as `[outline elided]`.

---

## Summary

The thread starts as a capability probe — *what can the agent actually do inside Zed over
ACP that it can't in the terminal?* — and lands on a concrete, buildable idea: persistent,
branching, refactor-tracking **code walkthroughs** that lead a reader through the real
source files via clickable `path:line` refs, authored in the TUI and *presented* in ACP.
A runtime layer (Tidewave into the running Phoenix dashboard) is identified as a deferred
stretch. Along the way the agent finds — and the user flags — leftover "touring-data"
references in `cb-dashboard` that were meant to be scrubbed.

### Key conclusions

- The clickable-`path:line`-drives-the-editor behavior is **host-bound, not format-bound**. ACP-in-Zed is the smoothest host; a passive viewer (browser/Markdown) is sandboxed from the editor and can't navigate it. No magic format is locked behind ACP.
- The agent gains **no extra tools** over the TUI; ACP's value is client-side ergonomics (diff review, editor-native permissions, `@`-mention context push, clickable refs). The TUI is the *more capable* agent surface.
- Pricing differs (user confirmed: ACP bills API credits, TUI is subscription) → deliberate **usage split**: dev in TUI, present/walk in ACP.
- "Presentation is human-driven, not auto-advancing" is reframed from limitation to **feature** — it's what enables branch points the reader chooses.
- Persisted format: a **JSON DAG**, anchors stored as **symbols/snippets not line numbers** (refactor-resilience), presented by a thin `present-walkthrough` skill.

### Artifacts produced

- `planning-data/plans/interactive-walkthroughs-acp/plan.md`
- `planning-data/plans/dashboard-residue-scrub.md`
- this transcript

---

## Thread

**User:** are you able to see the file to the right?

**Assistant:** No — I can't see your editor or any panel. I only see files you point me to
or that I open with tools, plus the working directory. Give me a path and I'll open it.

---

**User:** i am talking to you in the zed editor using acp. what additional functionality do
you have related to integration that you would not have in the terminal ui?

**Assistant:** Honestly smaller than expected, and mostly on Zed's side. My tool set looks
like the standard Claude Code set — no Zed-specific tools (no "read selection", "list open
tabs", "cursor position"). What ACP changes is the *client experience*: edits render as
reviewable diffs in the editor, permission prompts surface as Zed dialogs, follow-along,
`@`-mention to push files/selections/symbols into context, possibly LSP diagnostics. No
extra **tools** vs the TUI; the win is interaction (diff review, editor-native permissions,
context push). The TUI has its own niceties (vim mode, keybindings) the bridge may not pass.

---

**User:** [@beliefs.json] examine this file. would you be able to highlight or move to
viewport to a line? or is this essentially just pointing you to the file on file system,
same as the tui  `[outline elided]`

**Assistant:** The `@`-mention sent a **symbol outline** (every key + line number, 1849
symbols), not the contents — already more than the TUI's bare path. But: **I cannot
highlight or scroll your viewport.** No tool drives your cursor/selection/scroll; ACP
doesn't expose "reveal line N" to the agent. The one nuance: when I write `file:line`, Zed
renders it as a *clickable link* — you click, Zed jumps. Pull, not push. So the `@`-mention
is *more* than a pointer (it injected structure) but is *not* a two-way handle on the editor.

---

**User:** i guess i'm trying to understand the use case for using agents in zed using acp
(which costs more via api credits with claude code) than the tui (which uses subscription
pricing)

**Assistant:** First verify the premise — billing depends on *auth*, not UI; if the Zed
integration runs on your subscription the cost question dissolves. If ACP genuinely bills
API credits: what ACP buys is client-side ergonomics only (diff review, `@`-mention,
one-window, editor-native permissions) — it does *not* make the agent more powerful. The
TUI is the more capable surface for less money. I'd only pay the delta if editor-native
diff review is central. Go confirm the auth/billing first — that single fact decides it.

---

**User:** show me a file:line ref in [@beliefs.json] as an example  `[outline elided]`

**Assistant:** Gave several real refs (the `kind` taxonomy enum at `beliefs.json:1845`, the
`render_sections` rules at `:2809`, the `rules`/`exemplars` block at `:858`, first belief at
`:3`), explaining the click → Zed-navigates (pull) behavior and that they're informational
on my side regardless.

---

**User:** could you create a file:line in different @mentioned files? cause that worked. I'm
wondering if this could be effective as a tutor of sorts - instead of say a wiki with code
blocks it could lead you through the repo and the actual files

**Assistant:** Explored the repo, then built a working **guided tour** of the belief
pipeline — real lines across different files: `beliefs.json:3` (raw data) → `belief.ex:81`
(`defstruct`) → `belief.ex:166` (`from_map/1`) → `store.ex:13` (`read/0`) → `store.ex:29`
(`find/1`) → `formatter.ex:37` (`table/2`) → `materializer.ex:44` (`materialize/2`).
Argued the tutor idea is strong: refs can't silently fork like pasted snippets (though line
*numbers* drift — anchor on symbols), reader stays in the real file, regenerable on demand.
Caveat: it's a lesson-on-rails the reader walks themselves — I narrate, I don't drive.

---

**User:** so in a way the render format you were just able to introduce is a new render
format requiring acp? … one usage split … code dev could be done in the tui, walkthroughs
and interactions could be done here via acp … lets say I wanted to persist the walkthrough
… what would be the file format … i would do the "dev" of this file in the tui, then circle
back here to "present" the "rendered" walkthrough document via acp … thoughts on feasibility?

**Assistant:** (1) Not ACP-only — the capability is *host-bound*: needs an editor that
linkifies + drives its viewport. Passive viewers can't; a TUI in an editor terminal also
can; portable fallback is `zed://`/`vscode://` URI links in Markdown (clunky). No format
locked behind ACP. (2) The usage split is sound now that pricing's confirmed. (3) Persist
as **JSON**, anchors as **symbols/snippets not line numbers** (resolve to current line at
present-time → refactor-resilient; missing anchor = clear maintenance signal). Present via
a small **skill** (`/present-tour`) so a new session loads + presents without re-explaining.
Feasibility high; only live step is a grep per anchor. Limitation: human-driven, no
auto-advance.

---

**User:** this is great. i think the presentation "limitation" is in many ways an advantage
… create branching points, where … the user "chooses" a path … tie in the bottom vertical
terminal pane as a visualization medium … iex … tidewave? … visualizing the state of the
model in real time as you step through the app … like a debugger approach but … educational

**Assistant:** Verified the stack: `cb-dashboard` is Phoenix 1.7 + LiveView on Bandit and
depends on `{:cb, path: "../composable-beliefs"}` (`cb-dashboard/mix.exs:35`) — so the belief
store/structs/materializer are loaded *inside the running dashboard's BEAM*. (1) Branching
is trivial — turns the walkthrough from a list into a DAG (mirrors the repo's own belief
graph). (2) Runtime: the agent does *not* drive the terminal pane; the pane runs
`mix phx.server`, and the agent reaches the runtime via **Tidewave's MCP eval** (side
channel). Mount point is the dev-only `if code_reloading?` block at `endpoint.ex:63`. Each
step can then pair a static ref with a live value. Free third surface: the dashboard renders
the graph — editor + narration + Tidewave + dashboard triangulate. (3) Calibration: this is
**REPL-augmented reading, not a breakpoint debugger** (no execution halt) — the better
primitive here. Constraint: keep evals inspection-only. Not currently wired (no Tidewave in
session); deferred stretch.

---

**User:** ok lets skip the literal debugger route. lets create a plan to do this … the
planning-data repo should be the home for the plan, examine that repo to gauge the format.
one question before you do - where are you seeing tour related data in this repo? that was
supposed to be scrubbed. maybe give me file links to all

**Assistant:** Clarified I never saw tour *data* — the example `tours.json` was invented, not
read. Grepped for ground truth and found three categories: (1) "guided tour" = the intended
`quickstart.md` walkthrough (legit); (2) **"touring-data" / "the host's `:org` source"** in
`cb-dashboard/README.md:27` and `watcher.ex:20` — the unscrubbed vestige of the host app;
(3) false positives (d3-con**tour**, `toURL`). Offered to scrub #2 on confirmation. Then
read two existing plans (`dashboard-extraction.md`, `toy-domain-onramp.md`) to match the
house format and wrote `interactive-walkthroughs-acp.md`.

---

**User:** create a plan for the scrub as well. also, the plan with plans is to commit the
thread alongside them … close out this thread with a transcript persisted alongside the
interactive-walkthrough plan you made. create a directory for both potentially

**Assistant:** Mapped full residue (excluding third-party `deps/`), split into Tier 1 (the
"touring-data" domain leak — scrub) and Tier 2 (broader `louder`/SOD host provenance —
keep/neutralize-at-re-cut decision). Wrote `dashboard-residue-scrub.md`. Created
`interactive-walkthroughs-acp/` holding `plan.md` + this `transcript.md`. (← you are here.)

---

## Open follow-ups at thread close

- **Scrub:** apply the two Tier-1 edits (`README.md:27`, `watcher.ex:20-22`); decide Tier-2 timing. See `dashboard-residue-scrub.md`.
- **Walkthroughs:** decide home for the JSON + skill (spans `composable-beliefs` and `cb-dashboard`); whether to scaffold Phase 1 now; Phase 3 (Tidewave) appetite. See `plan.md` Open Questions.
- **Billing:** confirm whether this ACP session bills API credits vs subscription — the fact that anchors the whole usage-split rationale.

---

## Post-thread resolution (2026-06-09)

The walkthrough follow-ups above were resolved in a later session; `plan.md` was
revised accordingly (see its "Resolved decisions" section). Summary:

- **Format/instance split.** The decisive reframe: the *spec* for the walkthrough
  format is separate from any *instantiation* of it (e.g. `belief-pipeline`). This
  produced a three-part structure - a new **`code-walkthrough/` framework repo**
  (spec + skill + abstract reasoning), **`<repo>/code-walkthrough/` instance dirs**
  (composable-beliefs owns `belief-pipeline`), and the same pattern for any other
  consuming repo. Mirrors `composable-beliefs : belief-collections`.
- **Skill (Q3).** One canonical home in `code-walkthrough/.claude/skills/`,
  parameterized by an instance path; launch from the framework repo / `amieval`
  umbrella and point outward. Not copied into consuming repos.
- **Anchor syntax (Q2).** Literal substring + optional `occurrence: N`; no regex.
- **Branch model (Q5).** Full DAG with re-convergence.
- **Phase 3 appetite (Q4).** In scope (decided 2026-06-09). The deciding factor: the
  `tidewave` Phoenix package is open source and needs no subscription, so the cost is
  wiring effort only. All three phases are committed; "do not half-wire" carries
  forward as a build constraint.
