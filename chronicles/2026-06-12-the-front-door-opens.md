# Chronicle: the front door opens

**Span:** 2026-06-12 - one focused thread: a bare id summons a desk item,
again.
**Register:** chronicle (cb:a520) - narrative for the operator; the audit
trail lives in the graph and in this close's commit.

## Where things stood

a522 was the most-reproved gap on the desk: eight specimens in two days of
evidence appends hand-rolled against `CB.Belief.Store` or raw python,
including the ensure_ascii incident where a whole-file re-dump
unicode-escaped every non-ascii character in beliefs.json and only diff
inspection caught it. Evidence is the one sanctioned in-place growth point
on an immutable node, and it was the only common write without tooling.
The session opened the same way the last discharge did - the operator
typed the id and nothing else, and the directive carried enough grounding
to resume cold.

## The build

Two pieces, exactly as the claim specified. An `append-evidence` clause in
`CB.Belief.Mutation`: explicit `artifact` and `date` with fallbacks to the
session-slug convention and today - which also hands the dag-proposal
pipeline the evidence-only mutation type the c049 specimen showed was
missing. And `mix cb.evidence`, the CLI front door: bare or namespaced id
resolution with ambiguity errors, dry-run default on the `cb.import`
pattern, `--beliefs` collection override, detail/artifact/date validation.

One deliberate scope call: the artifact flag validates `scheme:rest` shape
but not membership in the c043 enum. That enum closes the set of top-level
`artifact` schemes only; evidence artifacts legitimately carry provenance
schemes outside it - c043's own evidence cites an `adjudication:` URI. The
front door enforces the contract that exists, not a stricter one nobody
wrote.

The serialization failure mode closed by construction rather than by
vigilance: the entry rides `Belief.to_map`'s pinned evidence key order and
`Store.write`'s atomic Jason encoding. Verified end-to-end on a temp copy
of the live graph - an append containing `naïve` produced a diff of
exactly the five new entry lines, byte-identical everywhere else, no
unicode escapes anywhere in the file.

## The discharge

By the a515/a511 pattern: materialized to t0014 through
`CB.Belief.Materializer`, discharge evidence appended, todo flipped done,
directive stays active and the desk clears through the materialized link.
The satisfying part: the discharge evidence went through `mix cb.evidence`
itself - the front door's first production run is its own discharge
record, anchored by a `code:` URI to the task module that `mix cb.resolve`
verifies one-match.

The wrinkle, and the close's finding: the t0014 status flip still went
through an ad-hoc `mix run -e` script, in the very session that built the
evidence front door. a522's evidence 3 had recorded both halves of the gap
- the belief-evidence append and the todo flip - and a522's scope covered
only the first. The second half is now its own desk item (cb:a530). A
companion gap surfaced at the same time: the generated CLAUDE.md's
Operations line (cb:a449 via c063) still renders the write flow as
preflight/adjudicate/import, leaving the new sanctioned write invisible to
a cold session (cb:a531).

## The org move

Mid-session, infrastructure: the operator moved the CB repos out of
`amieval` into the `composablebeliefs` GitHub org (composable-beliefs,
cb-site, belief-collections, cb-dashboard, planning-data), and elixir-wiki
and plan-app to the personal account (ob6to8); evals, eval-tut, and bench
stayed. All seven moved repos' local remotes were reassigned and verified
reachable. GitHub's redirects would have held, but they die silently if an
old name is ever reused. The local parent directory is still
`~/dev/repos/mine/amieval/` - the operator is deferring the rename until
some work lands; the path/org mismatch is self-evident, so nothing else
records it. Historical `amieval/code-walkthrough` references in plans and
the graph stay as written: they record what was true then.

## Where things stand

The desk: a522 gone, a530 and a531 minted at close. Next by specimen count
is a519 (preflight conflict-level calibration), three evidence entries
ripe for a decision - two showing 1:51 bare tag-overlap noise, one
counter-specimen where the wall's tag-tracking had diagnostic value on a
mis-tagged proposal. The session that picks it up inherits the calibration
question: what, beyond a shared tag, should contract-level escalation
require?
