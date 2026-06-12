# Chronicle: the README split

**Span:** 2026-06-11 into 06-12 - one short thread, docs-focused, run
alongside another live session.
**Register:** chronicle (cb:a520) - narrative for the operator; the audit
trail lives in the graph and in commits 0b8da60 and this close.

## Where things stood

The README had grown to 818 lines - a full manual fronting the repo: the
mental model, the codepath and eval-ledger expositions, the complete
reference tables, and a four-hundred-line worked example, all stacked
ahead of the license. The operator opened with a question rather than a
directive: is a very direct, succinct README with expansive documentation
elsewhere a standard?

## The split

It is - the dominant convention for mature projects (short README plus a
docs/ directory; Diataxis is the usual frame for what moves out; ExDoc
guides are the Elixir-idiomatic home). The repo already had the
destination: docs/ held the thesis, the design-reference index, the
run-manifest spec. The README just had never been emptied into it.

The operator approved the split and it went mechanically: four deep
sections moved verbatim into five docs/ files - mental-model.md (with
"What the graph compiles to"), codepaths.md, eval-ledger.md, reference.md,
and worked-example-eval-verdict.md - with headings promoted for standalone
reading and the handful of README-internal anchors retargeted. The README
came down to 95 lines: pitch, the two commitments, use cases, the
sixty-second demo, quick start, a documentation map, honest status,
origin, license. Nothing was rewritten; the only prose edits were the
retargeted cross-references. No CI gate or test depended on README
content, so the move was free. Commit 0b8da60.

One seam noted and closed at the close: belief-graph.md and
mental-model.md now overlap thematically - the index that refuses to
restate the design, and the narrative that deliberately does. The index
now names the narrative as its prose companion rather than leaving the
pair unintroduced.

## The close, around a live sibling

The working tree carried a concurrent session's uncommitted work
throughout (the /position skill: cb:a524, cb:c063, a CLAUDE.md
regeneration, a todos entry). This close touched none of it. The settled
convention was minted as **cb:a525** (directive/convention, preflight
clean - zero matches in all buckets): the README stays a succinct front
door near 100 lines; narrative, reference, and worked-example material
lives in docs/ files linked from the README's Documentation section; new
deep material goes into docs/, never appended to the README.

The one entanglement worth knowing about: a525 lives in
beliefs/beliefs.json, which also carries the sibling session's uncommitted
nodes. Committing the graph file here would have swept that session's
work into this close, so the graph file stays uncommitted and a525 rides
whichever close commits it. If the sibling session died rather than
paused, do not discard beliefs.json without re-importing a525 - this
paragraph and the graph file are its only homes.

## Where things stand

All gates green over the union: 294 tests, schema verify 20 passed,
CLAUDE.md fresh, nothing stale. The desk stands at thirteen - the twelve
standing items plus a525 (which is a standing convention, not discrete
work; it will sit as an unlinked directive until materialization or the
overlay gives conventions a quieter shelf). Session memory was already
the bare pointer; no blog draft - a docs reorganization is routine work,
not a learning. The next session inherits a front door a reader can
actually finish, and the same standing recommendation the desk has
carried: the operator-decision items wait on the operator.
