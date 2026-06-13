# Chronicle: the boundary was only prose

**Span:** 2026-06-12 - one comparison that turned into a dogfooding fix.
Session ref: `session:2026-06-12-hindsight-comparison`.
**Register:** chronicle (cb:a520) - narrative for the operator; the audit
trail lives in the graph (a539, a407) and in this close's commits. The
competitive rationale is not here by design - it routed to cb-direction.

## Where things stood

The README has long carried a scope sentence: vector memory, model calls,
and eval execution stay outside CB - "CB is the ledger, not the lab bench."
A clean boundary, stated once, in prose. Nobody had asked whether it was
also a node in the graph, because nobody had been pushed against it.

## The arc

The session began as a flat request: compare composable-beliefs to a paper
(Hindsight, arXiv 2512.12818 - an agent-memory architecture with a four-
network memory bank and a mutable, confidence-scored opinion layer). The
read produced a comparison doc, and because the paper is a competitor read,
the whole doc routed to cb-direction (`comparisons/`), never a public
surface.

Two incidents inside that work are the reason this close has graph writes.

First, the operator caught a fabricated provenance. The comparison cited a
nine-system roster of memory competitors as coming from "your own eval-
vertical scan." It did not - it came from the paper's own Table 1 and
reference list; the eval-vertical scan had named only XMem and a bi-temporal
engine. "Where did you find this?" The agent had conflated two documents and
stated a confident wrong source. In a framework whose entire thesis is
provenance discipline, that is exactly the failure mode worth catching, and
it had no node. It became a407 in agent-behavior: a reasoning-error
primitive, the incident as evidence.

Second, the boundary surfaced as a live temptation. The comparison raised a
real question - should CB grow into an all-in-one memory system, or stay the
substrate that layers over one? The answer existed, but only as README
prose. It had not loaded when an agent (this one) drifted toward "CB could
do memory," and had to be re-derived by re-reading the README. That is the
flat-rule antipattern the thesis names: a load-bearing rule that does not
compose and does not load at decision time. So it became a539: a directive,
design-principle, grounded on a462 (the composition-not-retrieval
principle), stating the boundary as something the house stands behind.

The split was deliberate: the boundary (checkable, architectural) lands in
the public cb: graph; the reasoning about how that boundary serves CB's
position stays private in cb-direction.

A smaller thread closed clean: a question about whether direction docs
should gain YAML frontmatter listing cited beliefs. The answer was no - the
inline `cb:` ids are already greppable, a hand-maintained list is the a386
digest antipattern in miniature, and reverse lookup is just grep. Do
nothing. No node needed; the decision is recorded here.

## Where things stand

The scope boundary is now queryable: `mix bs show cb:a539`. The provenance
slip is catalogued where the actualization graph collects agent self-
knowledge. The comparison and its strategy live in cb-direction. Nothing
load-bearing remains only in the chat.

## What the next session inherits

Nothing blocking. If the content-axis idea (tagging beliefs by domain, the
one borrowable shape from the paper) ever gets picked up, the standing note
is: derive the axis from eval needs, not from the paper's memory-agent
domains. That guidance lives in the cb-direction comparison doc, not the
graph - it is a design-maybe, not a directive.
