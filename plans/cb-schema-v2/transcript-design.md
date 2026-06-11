# Transcript - cb-schema-v2: the design discussion

**Date:** 2026-06-10 (with follow-ups through 2026-06-11)
**Surfaces:** a single composable-beliefs TUI thread (Fable 5) that began as a
README-rewrite request and produced the four-type schema design as a side
effect of checking the user's conceptualization against the implementation.
**Companion to:** [`design.md`](design.md) (the design record this thread
wrote) and [`transcript-execution.md`](transcript-execution.md) (the next
session, which opens by "picking up the design record the previous session
wrote" - this is that previous session).

> User turns are condensed to their substance; the load-bearing phrasings are
> quoted. Assistant turns are condensed to what was read, argued, conceded,
> and written.

---

## Summary

A README-readability review escalated, turn by turn, into the four-type
schema. The user checked his mental model of CB against the repo; the
assistant corrected four points and validated five; the user's counter on the
compound/implication boundary survived the correction and sharpened into the
four-type proposal; the direction-of-fit test settled the last boundary
question; the user pulled the trigger and this thread wrote `design.md`,
grounded in a full data sweep of every collection and code touch point.

## 1. The README rewrite (the occasion)

The user asked for an onboarding study of the repo and a README critique:
mental-model building, use cases, "make sure to properly introduce each new
terminology... describe what each quoted belief actually says." The critique
landed reader-first restructuring (use cases, sixty-second demo, ordered
mental model, every cited belief glossed) and shipped as `4d54605`. Two
standing prose directives emerged on the way: every belief id cited in prose
gets a one-sentence statement of its claim at first citation, and (later,
explicitly) no negative framing - never the "X doesn't Y, it Z" sentence
shape.

## 2. The conceptualization check

The user laid out his model of CB to test against the implementation:
schema-first ("the most basic and essential concept... doesn't actually need
any sort of implementation"), beliefs-not-facts ("they are not a fact, they
are a belief... the concern, unlike facts, is not the truth, but the belief
itself"), axioms as the philosophy analogy, primitives as irreducible,
compounds as aggregates, implications as deduced, contracts as "a modified
version of Datalog," and CB as "a substrate... that is neither NL or code."

Validated and promoted into the README: schema-first (with the caveat that
the verifiers carry the guarantees), beliefs-not-facts, the formality
gradient (more formal than prose, less brittle than code), the dual-audience
spec layer (compiled documents face the agent; trees and tours face the
human - "an operator can understand and audit the system at the lowest common
denominator level of code while thinking on the level of CB"), and
code-is-never-a-compilation-target.

Corrected: axioms (primitives are justified and supersedable - the analogy is
foundationalist basic beliefs, or Quine's web once entrenchment came up);
"irreducible" (atomicity is by provenance, not logic); compounds-as-aggregates
(canon: a compound asserts what no dep states alone); **CB does not deduce**
(no inference engine anywhere, deliberately - it records derivation, it never
performs it); and the DSL (Datalog supplies the fact shape only; one Elixir
interpreter per rule kind; the graph routes, code implements - per c047,
contracts never carry algorithms).

## 3. The boundary fight (where the fourth type came from)

The user accepted the corrections except one, which he turned around:
compounds should be *pure* aggregates ("a literal bag of parts"), with all
interpretive content in implications - "if both can rest on implications, why
have both of them?" The assistant's first answer was the mood boundary
(descriptive vs prescriptive) enforced as authoring discipline, noting the
machinery asymmetry: materialization, contract-grading, and the conflict
audit attach to implications only.

The user pushed past the discipline answer: four types - primitive (atomic
verbatim attestations), compound/consensus (mechanically checkable
conjunction), implication as "a potential conclusion derived logically given
a set of givens" ("this is what the implication is meant to define... the
problem may be the attachment of contract to the implication itself"), and a
prescriptive fourth type, with the demand that adherence be "more formal than"
authoring discipline. One amendment held: the fourth type could not be
*contract* (rule-less prescriptions would be homeless; c031's
contract-is-structural doctrine survives as the grade of a directive).

## 4. The membership test

"Is it as simple as this?" - attest / aggregate / infer / prescribe. Answer:
yes as taxonomy, with **direction of fit** as the operational test: an
inference is *falsified* (mind fits world), a directive is *violated* or
*withdrawn* (world fits mind). The trichotomy - falsified -> inference;
violated -> directive; withdrawn -> directive - plus the trap rules
(evaluations name their standard or move up; conditionals decompose;
stipulative vs reportive definitions; deontic vs alethic "must"). The
smoking gun that the fourth type was latent, not invented: `retired` ("a
contract no longer in force") had been a directive-only state in the c029
lifecycle since v1.

## 5. "go ahead - start with the design doc"

This thread wrote `design.md` from a full data sweep: every collection's
type/kind inventory (cb:'s 27 implications all directive-shaped - the
inference type starts empty in the framework graph; agent-behavior's 26
compounds the big re-homing), all code touch points, the type function
(kind-type table, grounding rule, subject containment), the sdl migration
worked end to end with the a006 verdict split, and decisions D1-D6 left
open - chiefly D1, where this thread recommended `inference` over retaining
`implication` (the false-friend argument) against the user's stated lean.
Committed as `063093b`. The next session (transcript-execution.md) resolved
D1-D6 and executed plans 0-4.

## Coda - the same thread's other arcs

The thread that produced this design also produced, before and after the
execution session ran in parallel:

- the **eval-identity thesis** ("eval architecture IS agentic epistemic
  architecture") - archived at `belief-collections/sources/`, extracted as
  `paradigm:a358-a365` via the first **position**
  (`belief-collections/positions/`, the source -> position -> DAG convention);
- the **positions federation + live-join** plan in plan-app, shipped the day
  its trigger (first extraction) fired;
- the post-execution follow-ups recorded as deviation 8 in
  transcript-execution.md: the cb-dashboard compat pass, the fuller
  v1-assumption audit, and the retirement of the version vocabulary itself.
