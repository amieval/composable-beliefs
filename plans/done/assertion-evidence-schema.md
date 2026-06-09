# Plan: Assertion Evidence Schema

**Status:** done (2026-06) — `quote` → `evidence[]` shipped; the identity-hashing specifics diverged to the typed `artifact` scheme
**Effort:** medium
**Domain:** assertion DAG

## Problem

The assertion schema has two limitations that block both operational use and service extraction:

1. **`quote` is a single string.** When a pattern is observed multiple times, the options are: create a redundant primitive (pollutes the DAG) or supersede the original (loses evidence). Neither allows evidence accumulation on a stable claim.

2. **`source` mixes provenance pointer with detailed evidence.** The `source` field identifies *who/where*, while `quote` was meant to carry *what specifically happened*. These are different concerns conflated into adjacent fields.

3. **User identity is embedded in cleartext.** The `source` field contains person identifiers. For a service model, user identity must be hashed so the service never sees who generated the evidence.

## Design

### Replace `quote` with `evidence` (array)

Each assertion gets an `evidence` array. Each entry is an occurrence - a specific observation grounding the claim.

```json
{
  "id": "a054",
  "kind": "primitive",
  "claim": "Agent adopts user statements as ground truth primitives without examining them objectively",
  "source": "user:a1b2c3:2026-03-12",
  "evidence": [
    {
      "date": "2026-03-12",
      "source": "user:a1b2c3:2026-03-12",
      "detail": "A collaborator theorized that a type of abstract instruction would not cause the agent to identify a specific problem. The agent encoded this theory as a primitive with confidence 0.9 - treating an untested projection as observed fact. The collaborator caught it: 'that is a theory by me. i would need to have evidence to back this up to make it a primitive.' The agent had not distinguished between the collaborator stating a fact and the collaborator speculating."
    }
  ],
  "confidence": 0.9,
  ...
}
```

**Fields per evidence entry:**
- `date` - when this occurrence was observed
- `source` - provenance pointer (same format as assertion-level `source`)
- `detail` - specific, detailed description of what happened. Not a generalization (that's `claim`), not a verbatim quote (too narrow) - the full narrative of the specific event that constitutes evidence for the claim.

**Append-only.** Evidence entries can be added, never removed or modified. This preserves immutability while allowing accumulation.

**Confidence re-evaluation.** When new evidence is added, confidence may be adjusted. The adjustment is a new value on the assertion, not an edit to existing evidence. The evidence trail shows why confidence changed.

### Hash user identity

For service readiness, the `source` field uses hashed identifiers:

- `user:<owner>:2026-03-12` becomes `user:<hash>:2026-03-12`
- The hash is deterministic (SHA-256 of person key) so the same person produces the same hash
- Local tooling can resolve hashes back to person keys via a local mapping
- The service never sees cleartext identity

**Hash format:** `user:<first-8-chars-of-sha256>:<date>`

**Local resolution:** A mapping file (e.g., `assertions/.identity-map.json`) maps hashes to person keys. This file is excluded from service sync or public repos.

### Assertion-level `source` field

The assertion-level `source` stays as the primary provenance pointer - who/where the assertion originated. For primitives with a single initial observation, it matches `evidence[0].source`. For assertions that accumulate evidence over time, it remains the original source.

Compound and implication assertions don't have `source` (they derive from deps). They can still have `evidence` - e.g., a compound might accumulate observations that reinforce the composed conclusion.

## Migration

### Existing assertions

- `quote` field migrates to `evidence[0].detail` on each assertion
- If `quote` is null, `evidence` is `[]`
- `source` field gets hashed user identity where applicable

### Code changes

1. **`lib/cb/belief.ex`** - replace `quote` field with `evidence` (list of maps). Update `from_map/1`, `to_map/1`, `@ordered_keys`.
2. **`lib/cb/belief/formatter.ex`** - update detail view and tree view to render evidence entries.
3. **`lib/cb/belief/filter.ex`** - if any filters reference `quote`, update them.
4. **Skills** - `/assert` skill needs to create evidence entries instead of setting quote. `/assertions` skill needs to handle evidence display.
5. **Identity map** - create hash utility and local resolution.
6. **Migration script** - one-time migration of existing assertions.

## Execution order

1. Update `CB.Belief` struct - add `evidence`, keep `quote` temporarily for backward compat
2. Write migration script to convert all existing assertions
3. Run migration
4. Remove `quote` field from struct
5. Update formatter for evidence display
6. Update `/assert` skill to create evidence entries
7. Add identity hashing utility
8. Hash existing source fields
9. Tests

## Verification

- `mix test` passes
- `mix bs list` view unchanged (evidence doesn't show in list)
- `mix bs show <id>` shows evidence entries
- `mix bs tree <id>` shows evidence inline
- `/assert` creates assertions with evidence array
- All existing assertions migrated cleanly
- Identity hashes resolve locally

## Open questions

1. **Evidence on compounds.** Should compounds accumulate evidence? A compound's "evidence" is its deps. But additional observations reinforcing the compound could be valuable. Lean: yes, allow it.

2. **Evidence vs new primitive.** When is a new observation evidence for an existing assertion vs a new primitive? Guideline: if the claim is the same pattern, add evidence. If the observation reveals a new pattern, create a new primitive.

3. **Hash scope.** Should we hash all identity references (person keys in subjects, etc.) or only in source/evidence fields? For now: only source fields. Subject refs are domain pointers, not identity.

4. **Detail length.** How detailed should evidence entries be? The narratives so far are ~3 sentences. No hard limit, but the detail should tell the complete story of what happened. It should resist the "lossy compression" failure mode by anchoring to specific events.
