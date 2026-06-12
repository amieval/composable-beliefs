# Position: Code is the operational substrate

**Type:** position
**Class:** design-policy
**Status:** active
**Authored:** 2026-06-10
**Origin:** agent discussion thread (amieval, 2026-06-10); stance passage preserved verbatim below, with emdashes transliterated to hyphens per repo formatting policy

The stance, verbatim:

> So I'd sharpen your phrasing: code isn't an abstraction layer that persists -
> it's the operational substrate, the only artifact in the system whose meaning
> is enforced by execution. NL discussion above it is fine, productive even,
> exactly when every claim terminates in an anchor into the substrate. What the
> IDE becomes is not the place humans write code - it's the adjudication
> surface, where claims meet the thing that actually runs. Reading code doesn't
> disappear; it gets re-scoped from "build a whole mental model" to "read the
> anchored stops that carry this argument." Which is what your Zed walkthrough
> already is: NL discussion terminating in code, rather than NL discussion
> instead of code.

This position states the design policy underlying the codepath machinery: it is
not self-documentation of what the graph contains but the philosophy that
licenses why the anchoring discipline exists at all. Claims below are staged
for extraction into the `cb:` collection; anchors point into this repo and
resolve against the repo root.

### Claim: Code is not an abstraction layer that persists; it is the operational substrate - the only artifact in the system whose meaning is enforced by execution.
**DAG status:** extracted
**Belief:** [[cb:a484]]

### Claim: NL discussion above the substrate is productive exactly when every claim terminates in an anchor into the substrate.
**DAG status:** extracted
**Belief:** [[cb:a485]]
**Anchor:** code:lib/cb/codepath.ex#defp resolve_anchor
**Anchor:** code:lib/cb/code_locator.ex#The resolved line number is never stored

### Claim: The editor's role shifts from authoring surface to adjudication surface - the place where claims meet the thing that actually runs.
**DAG status:** extracted
**Belief:** [[cb:a486]]
**Anchor:** code:skills/present-codepath/SKILL.md#the reader clicks, the editor navigates

### Claim: Reading code re-scopes from building a whole mental model to reading the anchored stops that carry an argument.
**DAG status:** extracted
**Belief:** [[cb:a487]]
**Anchor:** code:skills/present-codepath/SKILL.md#the reader reading the real file

### Claim: Agent claims about code must carry code: anchors that resolve at read time; an unresolvable anchor is an ungrounded claim.
**DAG status:** extracted
**Belief:** [[cb:a488]]
**Anchor:** code:lib/cb/codepath.ex#anchor "#{anchor}" not found in

## Design rationale (appended 2026-06-11, for cb:a511)

Appended at user direction after the a511 self-bootstrap audit found this
rationale reachable only through an unresolvable session: slug (the a518 gap).
This is the settle-time capture the /position skill (cb:a515) mechanizes;
claims below stage for extraction when a511 executes. Anchors verified at
append time, one match each.

### Claim: A position may carry a terms block: entries of shape {term, definition, anchor?}. A term naming a code construct anchors to its defining site, so a definition is a navigable stop; prose-only definitions remain valid for terms with no code referent.
**DAG status:** pending
**Intended:** schema rule, lands under cb:a511

### Claim: Position names the epistemic artifact - the stance and its claims. Codepath names the render face - the navigable tour resolved from the position's anchors. A position with anchors has a codepath; the term "walkthrough" is retired with its repo.
**DAG status:** pending
**Intended:** definition, lands under cb:a511
**Anchor:** code:lib/cb/codepath.ex#Resolve a codepath output-target into ordered, anchored stops

### Claim: Anchored claims verify on a three-tier gradient: provenance integrity (source anchors - the quoted evidence still exists), grounding currency (code anchors - the referent still exists in the substrate), and behavioral validity (predicates - the referent still behaves as claimed, contract grade). An anchor check is a necessary condition only: failure flags the claim for review, while success alone never re-validates the claim.
**DAG status:** pending
**Intended:** inference, kind design-rationale, lands under cb:a511
**Anchor:** code:lib/mix/tasks/cb.verify.codepath.ex#defmodule Mix.Tasks.Cb.Verify.Codepath
