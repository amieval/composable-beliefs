# plan-3 - belief-collections migration with adjudicated splits

Depends on: plan-2. Target repo: ../belief-collections (method, eval-provenance
[sdl], toy-eval, library [lib], agent-behavior, paradigm).

## Per-collection work (from design.md inventory)

- **method** (14): 9 contracts -> directive (M); a1-a5 conventions -> directive
  via grounding rule (D6 confirmed); method:c2 superseded to carry the
  kind-type bindings (observation -> primitive/compound; verdict -> inference
  only; guidance/protocol/convention -> directive; enum-registry/implies ->
  directive contract-grade; definition dual).
- **sdl** (8): worked migration from design.md. a006 splits: a008 (inference,
  verdict, deps [sdl:a3], a006 superseded_by a008) + a009 (directive, guidance,
  deps [a008], new). a007 -> directive, deps re-point [a008]. a3 superseded
  with trimmed claim (D3). c1/a4/a5 history re-type (M).
- **toy** (9): a9 splits per the sdl recipe; a7 protocol -> directive (D6);
  rest M or untouched. Verifies fully green.
- **lib** (14): 6 implications -> directive (M); 6 rule-primitives -> directive
  via grounding rule (J confirmed by design); 2 observation compounds triaged by
  containment. Migrate LAST; double as the v2 teaching example in quickstart.
- **agent-behavior** (92): 10 implications -> directive (mostly M); 26 compounds
  triaged by containment audit - the inference type's first real population.
- **paradigm** (21): 3 J + 3 M, same shape.

## Acceptance

- All eight collections verify under v2 (`mix cb.verify.collection <ns>`).
- sdl reproduces exactly its two teaching FAILs: m-runs against sdl:a008
  (1 run cited), m-judge-validation against sdl:a2.
- Splits recorded in evidence on both sides; supersession links walkable.
- Manifests all carry schema_version 2.


## Execution record (2026-06-10)

All six collections migrated and stamped schema_version 2. sdl: a3 -> a010 (D3
trim), a006 -> a008 (verdict inference) + a009 (guidance directive), a007 deps
re-pointed to a008 and re-typed directive; reproduces exactly m-runs +
m-judge-validation FAILs. toy: a9 -> a10+a11, a7 -> directive; fully green.
method: 14 mechanical re-types; method:c10 kind-type table added (verdict ->
inference only); method:c2 -> c11 enum supersession admitting derivation-table.
agent-behavior: a072 and a123 -> inference (a123 was the one genuine containment
escape, 'works because' abduction); a057/a070/a171/a172/a232/a359 superseded by
a396-a401 as rule/action-item directives (mood re-homes; a359's stipulation
untangled from its external source). paradigm: a063/a355/a357 -> inference.
All eight collections verify; 261 tests green; codepath suite 3 passed.
