# Chronicle: the other half of the door

**Span:** 2026-06-12 - one spike: the todo flip gets its front door, and
the materializer learns to read the ids its own skill writes.
**Register:** chronicle (cb:a520) - narrative for the operator; the audit
trail lives in the graph and in this close's commit.

## Where things stood

a530 was the most-reproved gap on the desk by count: ten specimens of
hand-rolled status flips across the closes, including the a522 discharge
flipping its own todo with an ad-hoc `mix run -e` in the very session
that built the evidence front door. Every discharge had the same
asymmetric shape - sanctioned append on the belief node, hand-rolled
script on the todo. a532 sat beside it, kin to the bare-id class: the
materializer rejected the bare id its own skill example documents.

## The build

One spike, both items, because they share plumbing. `CB.Todos` now owns
the todo collection's serialization end to end: tolerant read, atomic
pretty write, and a strict open -> done close that keeps
materialization-time notes and appends discharge notes as a new
paragraph. `mix cb.todo.close` fronts it, mirroring `mix cb.evidence` -
dry-run default, `--notes` required, refusals on unknown ids and
non-open records. The materializer's JSON sink was rerouted through the
same store, so the append path and the flip path cannot drift apart;
the `ensure_ascii` encoder-drift class is closed by construction on
this collection the same way a522 closed it on the graph.

For a532, `find_node` now routes through `Graph.resolve_id` - the same
resolution `mix bs` and `mix cb.evidence` carry. A bare id resolves
when exactly one belief matches, ambiguity surfaces as
`{:ambiguous_id, ids}` instead of `node_not_found`, and the canonical
id is what gets linked and returned. The skill doc states the contract
and points discharges at the new flip task.

Verification before any live write: 326 tests (a byte-level case
asserting a close changes exactly the flipped record's lines), and a
smoke run on a temp copy of the live collection - refusal on the
already-done t0016, two flips with non-ascii notes landing unescaped,
every untouched record byte-identical.

## The doors validate each other

The ceremony was the demonstration. The materialization passed bare ids
(`a530`, `a532`) per the skill's example shape - the a532 fix's first
production run, first-try success on the documented path. The flips of
t0017 and t0018 went through `mix cb.todo.close` - the a530 front
door's first production runs; the eleventh hand-rolled specimen never
happened.

And the first run caught a real bug in the *other* door: the evidence
appends landed dated 2026-06-13. `CB.Belief.Mutation.resolve_date/1`
defaulted to `Date.utc_today()` while every other writer stamps
`CB.today()` (local) - invisible until a ceremony ran past midnight
UTC. Fixed inline (one line plus its moduledoc), and the two misstamped
dates repaired surgically in the graph - the only hand edit of this
close, correcting the tool's own misfire, recorded here.

## Where things stand

a530 and a532 discharged and off the desk, which drops to 10 discrete
items. 326 tests green, schema verify 20/20. The discharge loop is now
sanctioned end to end: materialize, evidence-append, flip - no step
needs a hand-rolled script.

a531 (surface `mix cb.evidence` in the generated CLAUDE.md via the a449
supersession) is the natural next ceremony, and arguably its successor
should name the whole write surface - preflight/adjudicate/import,
`mix cb.evidence`, and now `mix cb.todo.close` - in one pass.

The concurrent README/other-applications thread remains untouched by
this close; those files belong to that session's commit.
