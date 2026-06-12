# Chronicle: overlap is not contact

**Span:** 2026-06-12 - one focused thread: the preflight wall learns to
tell family resemblance from semantic contact.
**Register:** chronicle (cb:a520) - narrative for the operator; the audit
trail lives in the graph and in this close's commit.

## Where things stood

a519 sat on the desk with three specimens already in its evidence. Every
contract-level block in a week of authoring had been bare tag-overlap: a
proposal shares one tag (almost always from the dag-schema family) with a
contract-grade node and the wall goes up, exit code 2, write blocked
pending adjudication. The c062 preflight was the worst of it - 17 contract
and 35 schema hits, every one bare tag_overlap, against exactly one true
match, which was the one carrying claim_overlap. Signal-to-noise 1:51,
and every review ended in the same boilerplate: overlap is necessary but
not sufficient. c055 had said so as doctrine all along; preflight just
was not enforcing the insufficiency - it delegated that judgment to the
reviewer, every time, at a user interrupt each.

The third specimen cut the other way and shaped the fix: the a526/a527
preflight raised the wall on a proposal that was mis-tagged dag-schema,
and the wall prompted the correction before import. The escalation tracks
the tag, and exactly because it does, a block on a mis-tagged proposal had
diagnostic value once. Whatever the calibration did, it could not make
bare tag-overlap invisible.

## The calibration

The session opened the now-standard way: the operator typed the id and
nothing else. Materialized as t0015 (the code) and t0016 (the encoding
node), confirmed as one plan.

The decision: escalation into either conflict bucket now requires
semantic contact - subject_overlap or claim_overlap among the match
reasons - alongside the contract-grade or dag-schema trigger. Bare
tag-overlap re-buckets to neutral. But it does not vanish: the entry
keeps its contract_level priority marker wherever it lands, and the
renderer annotates `(contract-grade)`, so a mis-tagged proposal still
gets its diagnostic signal by visibility instead of by blocking. The
calibration re-buckets noise; it never suppresses it.

In code this is one predicate: `CB.Belief.Conflict.classify/2` gained
`semantic_contact?/1` as a conjunct on both conflict branches. The most
satisfying casualty was in the test suite - the multiple-overlap fixture
had asserted c029 lands in conflicting on a tag-only match across a
domain mismatch; under the calibration it moves to neutral with its grade
marker intact, which is not a regression but the directive's exact
intent, executable.

The doctrine question a519 left open resolved cleanly: no c055-family
supersession. The scope doctrine did not move - c055's
overlap-is-necessary-but-not-sufficient invariant is precisely what
preflight now enforces mechanically. The criteria landed as cb:c064
(preflight-escalation-criteria), a contract-grade audit-rule depping c055
and a519, three scenario rules, four invariants, tagged by concern
(preflight, conflicts, calibration) rather than dag-schema - the honest
classification a519's own evidence had flagged as a data point.

## The wall proves itself by standing down

c064's preflight was the calibrated bucketing's first live run, on its
own encoding node: 0 contract, 0 schema, 3 neutral. c055 itself surfaced
as neutral bare tag-overlap with `(contract-grade)` annotated - the exact
shape that the old code would have raised the wall on, reviewed at a
glance instead. Both substantive neutrals were already deps. The
machinery validated its own change on the way in.

## Where things stand

a519 discharged and off the desk (c064 links it). 311 tests green, schema
verify 20/20, CLAUDE.md current. The desk holds 11 discrete items.

Friction the close minted or fed back into the graph:

- The t0015/t0016 status flips were hand-rolled `.exs` scripts again -
  specimens nine and ten for a530 (the todo front door), appended to its
  evidence.
- `CB.Belief.Materializer.materialize/1` rejects a bare id with
  node_not_found while `mix bs` and `mix cb.evidence` resolve bare ids
  fine - and the /materialize skill's own example uses a bare id. Minted
  as a532.

A concurrent session was mid-flight in the same checkout repositioning
the README (the evidence-ledger framing) and drafting
docs/other-applications.md; those files were left untouched by this
close and belong to that thread's commit.

The next session inherits a desk where a530 is now the most-reproved gap
by count, and a preflight whose conflict buckets mean what they say.
