# plan-2 - framework contract supersessions and CLAUDE.md regen

Depends on: plan-1 (code accepts v2; cb: and codepath: migrated).

## Supersessions (write flow; staged in plan-0)

- cb:c026 dag-structural-types: type enum opens to four values (primitive,
  compound, inference, directive); rules/invariants and materialization
  invariants re-attach to directives. (Found via plan-0 preflight - the
  design doc's original list missed it.)
- cb:c027 dag-field-presence: deps required of compounds, inferences, and
  non-contract directives (grounding rule alternative: stipulation artifact);
  contract fields are directive-only.
- cb:c029 dag-status-lifecycle: retired transition row + invariant widen from
  contract-grade implications to any directive.
- cb:c031 contract-identity: contract-grade iff type directive with non-empty
  rules/invariants; retired-status invariant reworded per c029 successor.
- cb:c032 conflict-scope-definition: two active directives share conflict scope.
- cb:c038 schema discipline: references four types and the new contracts.
- method:c2 lands in plan-3 with the collections (cross-repo).

## New contracts (write flow)

- kind-type derivation table: row(kind, allowed_types) per design's three
  groups (directive-only, never-directive, dual); Table interpreter; checked by
  the verifier by role.
- subject-containment rule for compounds.
- directive grounding rule (deps or stipulation artifact; contract-grade
  exemption).

## CLAUDE.md

Supersede the render-section beliefs stating "three structural types"; run
`mix cb.generate.claude_md`; `--check` passes; CI gates stay on.

## Acceptance

`mix cb.verify.schema` green with the new contracts active; `mix bs stats`
shows four types and "unlinked directives"; `bs history` walks every superseded
canon contract to its successor.


## Execution record (2026-06-10)

c026->c051, c027->c052, c029->c053, c031->c054, c032->c055, c038->c056 via
mix cb.adjudicate (accept_supersede; records in proposals/adjudications/).
New contracts imported: c057 kind-type table (38 rows), c058 subject containment,
c059 directive grounding. CLAUDE.md render beliefs a445/a446/a447/a452/a468/a469
superseded by a477-a482 (four types; the concludes-beyond-inputs sentence moved
to the inference type per D3); c048 -> c060 re-points render_sections. Dep
re-points (representational, per the design's a007 precedent): a387, c047, c049.
CLAUDE.md regenerated, --check green; bs stale clean; kind-type table check
passes live.
