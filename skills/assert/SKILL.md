Add beliefs to the DAG after examining a source artifact, entity, or reasoning direction.

See `docs/belief-graph.md` for the canonical system reference.

**Confidence field removed.** The subjective `confidence` scalar was expunged as agentic theater. Do not add `confidence` fields to new beliefs. Structural support (artifact count, evidence count, dep count) is derived on demand via the support helper; if you need signal about a belief's grounding, cite specific evidence and artifacts rather than a score.

## Input

`$ARGUMENTS` describes what to assert on. Examples:
- Entity path: `items/a801-loan-policy` - read the entity and build beliefs
- Artifact: `gmail:<thread-id>` - read the thread and extract beliefs
- Reasoning direction: `hold-queue behavior under membership tier changes` - compose beliefs about a topic
- Conversation: `persist our discussion about overdue-policy logistics` - formalize prior reasoning

## Steps

1. **Read** the referenced artifact, entity, or conversation context.

2. **Load existing assertions** from `beliefs/beliefs.json`. Note the last ID to generate sequential new IDs.

3. **Identify primitives.** Extract non-reducible facts worth asserting. Each primitive:
   - Has `type: "primitive"`
   - Has an `artifact` URI whose scheme is one of the c040 enum values (`gmail:`, `document:`, `source:`, `user:`, `session:`, `https:`). Policy-grade beliefs (`kind: "policy"`) carry the `session:<id>` artifact of the session in which they were authored - same as any other primitive.
   - Has an `evidence` array with at least one entry. Each entry has `date`, `artifact`, and `detail`. The `detail` is a specific, detailed description of what happened - not a generalization (that's `claim`) but the full narrative of the event that constitutes evidence. More detail resists conflation.
   - Has `subjects` array linking to referenced entities (e.g. `[{"ref": "policy/loan-period", "type": "policy"}]`)
   - `kind` is enum-constrained by c039 (e.g. `"fact"`, `"observation"`, `"rule"`, `"policy"`, `"action-item"`, `"convention"`); `domain` is enum-constrained by c041 (`ops`, `design`, `agent`, `system`, `dev`); `tags` is free-form for cross-cutting concerns
   - Only include facts that participate in compound reasoning - skip self-evident data
   - **For self-referential assertions** (subject type "agent"): distinguish between user observations (encode as primitives, cite the session as artifact) and user theories (encode as compounds with explicit evidence showing the reasoning, not as ground-truth primitives). Do not treat user speculation as ground truth.

4. **Scan for composition.** Compare new primitives against existing assertions:
   - Do any new primitives interact with existing primitives from other entities?
   - Do date ranges overlap? Do policy numbers conflict? Do states collide?
   - This is where cross-entity findings emerge. Be thorough.

5. **Build compounds.** For each composition found:
   - List the dep IDs explicitly
   - The `claim` carries the combined meaning - state what the combination of deps means in the claim itself

6. **Build inferences and directives.** Decide the mood by direction of fit - ask what would count as the belief being wrong. Falsified by the world: `type: "inference"` (a conclusion licensed to exceed its deps - a generalization, a diagnosis, a verdict). Violated or withdrawn: `type: "directive"` (a prescription the house stands behind - a rule, guidance, a policy). Known traps: an evaluation names its standard or it is a directive in disguise; a conditional prescription decomposes into a means-end inference plus a goal-adopting directive; deontic must is directive, alethic/structural must is inference. For directives:
   - Set `materialized: null` (materialization is done separately via `/materialize`)
   - Set `subjects` to the relevant entity references
   - Set `kind` from c039 (e.g. `"policy"`, `"rule"`, `"action-item"`) and `tags` for cross-cutting concerns
   - The `claim` should describe the action needed - belief meaning is carried by `claim` + `deps`
   - For contract-grade directives, set `contract: true` and populate `rules` and/or `invariants` (the marking is biconditional with non-empty rules/invariants per c056; contract is the machine-checkable grade of a directive, never a type)
   - **Grounding.** An inference requires deps - a conclusion traces its grounding even when its claim exceeds it. A non-contract directive requires deps or a stipulation artifact (`plan:`/`user:`/`session:`/`document:` - the record of its adoption, per c059). The kind must agree with the type per the kind-type table (c057): a verdict is inference-only, a policy is directive-only.
   - **Classify lifecycle (per a379, directives only).** Every directive is either discrete (one specific completable action) or recurring (a rule that fires whenever its condition holds). Tag it: add `"lifecycle:discrete"` or `"lifecycle:recurring"` to `tags`. Discrete directives track execution via the `materialized` field (see Rules below); recurring directives stay active indefinitely and never get materialized.

7. **Present** the proposed assertions to the user before writing. Show each one with its deps, artifact, evidence, and reasoning.

8. **Preflight search.** For every proposed belief in the batch, run `mix cb.preflight --file <tmp.json>` (write the proposed belief to a temp JSON; the task is read-only). The task returns four explicitly grouped buckets - render them inline to the user in this order (do not collapse the order; dense subject-overlap lists can drown signal):

   1. **Contract-level conflicts** (entries with `priority: :contract_level`). Render prominently. These block the write outright until adjudicated per a380.
   2. **DAG-schema / non-contract conflicts** (remaining `conflicting` entries). Surface for adjudication; do not block automatically but require a user decision.
   3. **Supportive matches** (dep candidates). Offer to add to `deps`.
   4. **Neutral matches** (informational). Render last; collapsing acceptable when the list is long.

   Scope reminder: this preflight is wider than `c055`. `c055` governs runtime overlap between active directives only; preflight is authoring-time and covers all four types. Do not conflate the two.

   For every conflict surfaced (contract-level or otherwise), prompt the user with three options and capture the choice + reasoning before proceeding:
   - **`accept_supersede`** - new belief replaces existing; existing transitions to `superseded` with `superseded_by` linkage.
   - **`reject_dep_tie`** - new belief is reshaped to dep on the existing one as a constraint; no supersession.
   - **`defer`** - no write; conflict recorded as a deferred primitive for later adjudication.

   Capture each adjudication as a session-local record with: `proposed` (the proposed belief shape), `conflicting_id`, `outcome` (one of the three), `reasoning` (user text). Hold these in the conversation for the adjudication step. Run `mix cb.adjudicate --file <adjudication.json>` to process adjudications before Step 9.

9. **Write** to `beliefs/beliefs.json` after user approval. **Do not write any belief whose preflight surfaced an unresolved conflict** - every conflict must have a captured adjudication first. Contract-level conflicts additionally require explicit user adjudication per a380.

10. **No digest to regenerate.** Per cb:a386 and cb:a477, active directives are read live from the graph (`mix bs list directive`); the framework keeps no cached digest to update after authoring.

## Rules

- Never edit existing assertions. Only append new ones or change status (supersede/retract).
- Extraction-time only - assert what you're actively reading, not retroactive guesses.
- Primitives are ground truth as stated by the source. We take sources at their word.
- **No confidence scoring.** The confidence field was removed; do not synthesize scores. Cite evidence instead.
- If superseding an assertion, mark the old one `superseded` with `superseded_by` pointing to the new one. Flag any compounds that depend on the old one as potentially stale.
- **Status and materialization are orthogonal** (a379, supersedes a373). Status follows c053: `active | superseded | retracted | retired` (retired is directive-only: a withdrawn rule, never a falsified claim). The `materialized` field (on directives only) is a separate axis tracking action history: `null | {plan, date, last_verified}`. Shape per a382: `plan` is the path to the plan that executed the action, `date` is when it executed, `last_verified` is null on fresh materialization or an ISO date if a drift audit has confirmed effects still hold. When a discrete directive's plan completes, the directive's status stays `active` (the principle is still true) and the `materialized` field records the plan + date. Query `status=active AND materialized=null` for still-actionable work; query `status=active AND materialized IS NOT null` for discharged directives retained for provenance.
- **Preflight is mandatory** (a380, a386). No write proceeds without a completed preflight pass via `mix cb.preflight` (Step 8). Conflicts at priority `:contract_level` block the write pending adjudication per a380; non-contract conflicts also require a captured adjudication outcome (`accept_supersede` / `reject_dep_tie` / `defer`) before Step 9 may proceed. Tie supportive matches in as deps. If a conflict surfaces, do not silently rework, weaken, or abandon the proposal to fit the existing node - that performs sycophancy-toward-the-DAG. The proposal enters adjudication per the consensus mechanism. Retraction after evidence is valid; retraction under the perceived authority of the existing DAG state without adjudication is disallowed. Preflight is wider-scope than `c055`'s runtime-overlap contract: preflight is authoring-time and covers all four types; `c055` governs runtime overlap between active directives only.

## Data protection

Writing to `beliefs/beliefs.json` requires explicit user authorization. Always present proposed assertions and get confirmation before writing.
