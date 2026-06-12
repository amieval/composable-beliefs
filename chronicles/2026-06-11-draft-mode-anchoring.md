# 2026-06-11: Draft-mode anchoring - the resolver gets a front door

Where things stood: the anchored-answer thread had just discharged into the
desk as a511-a518, and the desk held fifteen discrete directives. The session
opened with the standard sweep - repos clean, nothing stale - and the question
of where to start. The answer was a512, draft-mode anchor resolution, picked
deliberately: it is the declared verification gate for the /position skill
(a515) and a488's stated escalation condition, it should precede a511 because
the format contract will want to cite actual resolver behavior rather than
legislate it in advance, and it is the one desk item that is pure engineering -
no schema change, no trip through the dag-schema preflight wall a519 documents.

The implementation confirmed the thesis the directive was written on. Anchor
resolution inside CB.Codepath was already belief-free - the per-line literal
matching, the first-match-plus-tighten-warning rule, the out-of-range-nth
handling never touched a belief; only resolve/resolve_stop coupled to the
graph. So the work was an extraction, not new logic: CB.Anchor now holds the
core, CB.Codepath delegates, and `mix cb.resolve --file` validates and
resolves bare anchor rows against a root with no collection loaded. Rows may
be `{path, anchor, nth}` objects or `code:` URI strings through the c043
grammar, which means a position's `**Anchor:**` lines pass through verbatim.
Gate semantics were the one real design decision: loose-anchor warnings report
without failing, but any invalid or unresolved row exits 1 - an authoring-time
gate that passes a dangling anchor would not be a gate. Full suite green at
293 tests; the new task verified its own discharge evidence's anchor as the
first real use.

The discharge followed the a513/a514 precedent: t0007-t0009 materialized and
marked done, the link-back on a512, the rationale appended as evidence citing
`code:lib/mix/tasks/cb.resolve.ex#def run(` rather than a commit hash - the
discharge of an anchoring directive, anchored. a488 gained the companion
append: its stated escalation condition (a draft-mode verifier exists) is now
met, with the note that contract grade remains a deliberate act requiring
rules per c056, not an automatic consequence.

One incident, and it is a repeat: the materialization carried notes on all
three action items per the /materialize skill's traceability mandate, and the
JSON sink dropped them by documented design - the second live specimen of
exactly what a523 describes, reproduced at the directive's very next use.
The evidence append on a523 records it.

What the next session inherits: the desk at fourteen. a515 (the /position
skill) is now unblocked with `mix cb.resolve` as its verification gate, and
a511 (pinning the anchored-position format) can cite real resolver behavior.
a488's escalation to contract grade is available whenever the rules are worth
writing. a523 has two specimens and is getting cheaper to fix than to keep
documenting.
