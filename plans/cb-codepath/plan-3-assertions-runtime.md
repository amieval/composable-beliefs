# Plan 3 - Assertions on: named predicates, `Sink.Test`, and the dynamic verifier

Raise the gradient. A contract-grade claim belief routes to a repo-resident named
predicate; the predicate runs in the live app via Tidewave MCP; the result materializes
as test history bound to the immutable claim. The *same* `belief-pipeline` codepath that
plan-2 narrates now also runs. This is the heaviest plan - it needs the runtime channel -
and it is gated behind plans 1 and 2.

**Status:** Step A executed 2026-06-09 (CB.Codepath.Predicates/Assertions, Sink.Test, mix cb.verify.codepath, cb:c045, contract-grade belief-pipeline stops). Step B (Tidewave federation) deferred until a live-state predicate first demands it.
**Date:** 2026-06-09
**Depends on:** plan-1 (schema), plan-2 (renderer). Runtime depends on the open-source `tidewave` Phoenix package (no subscription) and a booted `cb-dashboard`.
**Touches:** repo-resident predicate functions (cb test support); contract routing on the `belief-pipeline` claim beliefs; `cb-dashboard/mix.exs` + `cb-dashboard/lib/cb_dashboard/endpoint.ex:63` (Tidewave mount); a new `CB.Materializer.Sink.Test`; a new dynamic verifier mix task.

## Context

c037 governs once tests live in cb: the DAG carries *which* predicate must hold *where*,
never the predicate body. That constraint produces the clean design - the "test DSL" is
pure routing over functions that already look like tests. The materializer already turns
an implication into artifacts through a pluggable `Sink` (`@callback persist/3`, only
`Sink.JSON` today); a test run is one more sink, not a new subsystem.

## Design

### Named predicates (c037-compliant)

Predicate bodies are ordinary functions in the cb codebase - reviewable, runnable,
version-controlled like any test (e.g. `belief_count_positive/0`,
`from_map_roundtrips?/0`). They are inspection/read predicates: they observe, they never
mutate.

### Contract routing

The relevant `belief-pipeline` claim beliefs become contract-grade, carrying rules that
route to predicate names - `implies(When, Requires: "predicate_name")` per the c035
registry and c037 boundary. The DAG names the predicate and the anchored site; the repo
implements it.

### `eval` = invoke the named predicate (two channels, cheap first)

`eval` is not "run this string"; it is "invoke the routed predicate." The DAG names the
predicate, the repo implements it, the verifier runs it - but *how* it runs depends on
what the predicate needs, and most need very little:

- **Step A - direct invocation (no new dependency).** The `belief-pipeline` predicates
  (`belief_count_positive/0`, `from_map_roundtrips?/0`, ...) are ordinary pure library
  functions over the belief graph. A plain mix task invokes them in-process - no booted
  Phoenix app, no MCP. This is the cheap path that makes the test gradient real, and it
  is where plan-3 starts.
- **Step B - Tidewave federation (deferred, pulled by need).** Only predicates that
  genuinely require **live application state** (e.g. inspecting the running dashboard's
  in-memory state) need federation into the running BEAM via Tidewave MCP. Reserve this
  channel for that case; do not route pure predicates through it.

This converts plan-3 from one heavy gated step into an incremental two-step and removes
the all-or-nothing "accept the runtime spine or nothing ships" risk. Step A ships the
test capability on its own; Step B extends it when a live-state predicate first demands
it.

### `Sink.Test` (test run as materialization)

A new `CB.Materializer.Sink` implementation: `contract -> invoke routed predicates ->
pass/fail -> link to belief.materialized` with a date. Test history is bound to the
immutable claim for free; re-running supersedes the prior materialized record. The
materializer you already have is the executor.

### Dynamic verifier (sibling task)

A new mix task (e.g. `cb.verify.codepath`) runs the live-assertional checks. It is a
**sibling** of `verify.schema`, not a generalization of it: `verify.schema` stays static,
deterministic, and runtime-free; the dynamic verifier requires a booted app + Tidewave
and is where non-determinism is confined. Keeping them separate preserves cb's
pure-traversal property.

### Inspection-only as a contract, not a convention

cb exists to turn conventions into contracts, so do not leave "predicates only read,
never mutate" as a review note. Encode it: a contract carrying a checkable naming
invariant (predicate names end in `?` or `_check`) plus the documented no-mutation rule.
The naming invariant is a verifiable proxy, not a guarantee of purity - but it makes the
rule a first-class, queryable part of the graph rather than tribal knowledge.

### Tidewave wiring (Step B only)

Needed only when Step B's live-state channel is first required. Per the original deferred
runtime layer: add `{:tidewave, "~> 0.x", only: :dev}` (pin at build time), mount it in
the dev-only block at `cb-dashboard/lib/cb_dashboard/endpoint.ex:63`, register the MCP
server (Claude connects MCP only at startup - restart after), and run `mix phx.server`.
Wire it end to end in one pass; never ship routing that does not resolve to a runnable
predicate.

## Acceptance criteria

- **Step A (no new dependency):** the `belief-pipeline` codepath with **assertions on**
  invokes its pure predicates directly via a mix task and records pass/fail to
  `belief.materialized` (dated; re-run supersedes). No Phoenix app, no MCP.
- `present-codepath` with assertions on pairs each contract-grade stop's static
  `path:line - claim` with its predicate result; non-contract stops still narrate only
  (the gradient).
- `cb.verify.codepath` runs the assertions as a batch suite and reports pass/fail.
- The inspection-only contract validates: predicate names satisfy the naming invariant.
- `mix cb.verify.schema` still runs independently, unchanged, with no runtime dependency.
- **Step B (only when first needed):** a predicate requiring live app state runs through
  Tidewave federation into the booted `cb-dashboard`, with the static verifier still
  independent.

## Risks and non-goals

- **Runtime dependency is Step B only.** Step A needs no booted app or MCP, so the test
  capability ships without the runtime spine. Tidewave (+ MCP restart) is required only
  once a live-state predicate exists - let that need pull it, do not build it
  speculatively.
- **Determinism boundary.** Live (Step B) predicate runs are non-deterministic; confine
  them to the dynamic verifier so `bs`/`verify.schema` stay pure. Step A predicates are
  pure and deterministic.
- **Inspection only.** Predicates read, never mutate - encoded as a contract with a
  checkable naming invariant (see Design), not left to review convention.
- **Non-goal:** multi-language predicate execution; a breakpoint debugger. Tidewave/BEAM
  is the one channel; REPL-style inspection is the chosen primitive.
