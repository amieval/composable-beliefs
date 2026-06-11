# plan-1 - v2 code, tests, migration tool; in-repo collections migrated

Depends on: plan-0 (canon primitives landed; supersessions staged, not landed).
The verifier must accept v2 throughout this plan while the cb: graph still
carries v1 contracts; the staged contract supersessions land in plan-2. Where
the code's hardcoded checks and the graph's contracts would disagree
mid-migration, the code checks are the source of truth for this window.

## Code changes (from design.md Code touch points)

| Module | Change |
| --- | --- |
| `CB.Belief` | `@types ~w(primitive compound inference directive)`; moduledoc four types |
| `CB.Schema.Verifier` | contract requires directive; deps-required -> compounds + inferences + non-contract directives, with the grounding-rule alternative (stipulation artifact satisfies a directive); action-item shape -> non-contract directive; NEW subject-containment check on compounds (plain subset semantics, empty subjects pass vacuously); NEW kind-type table check (role-discovered derivation-table contract, skip when absent); retired-status check widens from contract-grade to any directive |
| `CB.Belief.Materializer` | accepts directives only |
| `CB.Audit.Conflicts` | scopes to active directives |
| `CB.Belief.Filter` | type filter values; unmaterialized filter -> directive; sort order primitive, compound, inference, directive |
| `CB.Belief.Formatter` | render paths + colors for four types (inference renders deps like compound; directive renders materialized) |
| `CB.Belief.Graph` | stats: per-type counts pick up enum; "unlinked directives" |
| `CB.Eval.Predicates` | `verdicts/1` -> `type == "inference" and kind == "verdict"` |
| `CB.Collection` (loader) | manifests gain `"schema_version": 2`; hard error on missing/v1 with pointer to mix cb.migrate.v2; the framework graph (beliefs/beliefs.json) is version-gated equivalently |
| `CB.OutputTarget` | docstring only |

## Migration tool

`mix cb.migrate.v2 --collection <path> [--write]`:

- M (mechanical): v1 implication + prescriptive kind -> directive; superseded
  history re-typed by best fit (never split); kind-type table drives it.
- Triage report (J/S): containment violations on compounds, dual kinds
  (definition/schema), verdict kinds on v1 implications (split candidates),
  convention/protocol primitives (grounding-rule re-homes).
- Unresolved J/S nodes block `--write`. The report is the work order.
- `--write` also stamps `schema_version: 2` in the manifest.

## In-repo migrations (same change, stays green)

- beliefs/beliefs.json (cb:): 27 implications -> directive (M); 5 compounds
  triaged per design (a131/a138/a173 -> inference; a387/a438 directive-lean,
  decide in triage); CLAUDE.md regen deferred to plan-2.
- codepath collection: 5 contract-grade -> directive (M); 3 superseded
  fact-compounds best-fit (M).

## Tests

Per-module updates + new fixtures for: four-type enum, containment pass/fail/
vacuous, kind-type table check, grounding rule (deps / stipulation artifact /
neither), migration tool M + triage + write-block, version gate. Golden audit
files regenerated. `mix test` green; `mix cb.verify.schema` green;
`mix cb.verify.codepath` green.


## Execution record (2026-06-10)

Landed in full. CB.Belief @types four values; verifier: contract-requires-directive,
grounding (deps or stipulation artifact; schemes plan/user/session/document per the
design amendment), subject containment (vacuous pass on empty subjects, skip on
unresolvable deps), kind-type table (role-discovered by derivation-table columns),
retired-is-directive; Materializer/Conflicts/Filter/Formatter/Graph/Predicates/bs
re-attached; loader gates on manifest schema_version 2. mix cb.migrate.v2 with
--resolutions overrides (full-override semantics). cb: migrated (76 re-typed; 5
judgment nodes: a131/a138/a173 -> inference by resolution, a387/a438 -> directive
mechanically via the prescriptive-kind-on-compound rule; a304 grounding backfilled
via cb.import, artifact plan:cb-schema-v2). codepath: 5 contract re-types. 261
tests green after fixture updates.
