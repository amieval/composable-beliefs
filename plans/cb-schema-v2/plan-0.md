# plan-0 - v2 canon authored through the front door

Depends on: design.md (D1-D6 resolved; D1 = `inference`, confirmed by Mark
2026-06-10). Companion prose: why-inference.md.

## Objective

Author the v2 design rationale as beliefs in the cb: graph via the write flow
(preflight -> import). These are primitives and are v1-legal today, so they land
before any code changes. Contract supersessions are STAGED here as proposal
files and land in plan-2, once code accepts v2 types.

## Beliefs to author (primitives, design domain)

1. Four-type model rationale: the v1 implication type conflated descriptive
   inference with prescription; v2 gives each epistemic operation a type
   (attest/aggregate/infer/prescribe). Cites this plan dir as artifact.
2. Direction-of-fit membership test: falsified -> inference; violated ->
   directive; withdrawn -> directive. Mind-fits-world vs world-fits-mind.
3. The type function: type = f(mood(kind), grounding, scope(subjects)); mood
   bound by the kind-type derivation table; grounding separates primitive from
   compound/inference; subject containment separates compound from inference.
4. Naming rationale (why-inference.md distilled): inference is the ampliative
   type - licensed to exceed its deps, falsifiable independently of them;
   compound is the one entailment the schema stores (conjunction introduction,
   subject containment as its formal shadow).
5. Strict-aggregate doctrine (D3): a compound's claim states exactly what its
   deps jointly state; commentary beyond the conjunction is inference content
   and is trimmed by supersession when found on a compound.
6. Primitive atomicity doctrine (D5): a primitive whose claim conjoins separable
   assertions is a mis-authored compound; atomicity + verbatim-leaning
   discipline; enforced in the write flow as judgment, not as a verifier check.
7. Directive grounding rationale (D4): a prescription is adopted; adoption
   grounds in beliefs (deps) or in a stipulation event (plan:/user:/session:
   artifact). Conventions are stipulations, so they are directives.

## Staged for plan-2 (proposal files only, no import)

- Supersessions: cb:c029 (retired widens to any directive), cb:c031
  (contract-grade iff directive + rules/invariants), cb:c032 (conflict scope =
  active directives), cb:c038 (schema discipline references four types).
- New contracts: kind-type derivation table (rows of row(kind, allowed_types),
  Table interpreter); subject-containment rule for compounds; directive
  grounding rule (deps or stipulation artifact; contract-grade exemption).
- CLAUDE.md render-section supersessions for "three structural types" wording.

## Acceptance

- All seven primitives imported through preflight with no unadjudicated
  conflicts; `mix cb.verify.schema` stays green under v1.
- Staged proposal files exist under plans/cb-schema-v2/proposals/ and are
  internally consistent with the design doc.

## Execution record (2026-06-10)

- cb:a470-a476 landed via proposals/plan-0-canon.json; preflight surfaced the
  dag-schema overlap family only (reviewed per c032, recorded in each
  evidence detail, a467/c040 precedent); `mix cb.verify.schema` green (16
  passed) at 121 beliefs.
- Preflight exposed two supersession targets the design list had missed:
  cb:c026 (three-value type enum) and cb:c027 (field presence). Added to
  design.md and plan-2.
- Supersession DRAFTING moved into plan-2 execution: successor contracts are
  v2-typed (directive) and their rules depend on plan-1's interpreter
  specifics, so drafting them before the code exists would stage guesses.
