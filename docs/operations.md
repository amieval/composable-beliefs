# Belief Graph - Operational Learnings

Companion to `belief-graph.md`. The durable *principles* now live in the graph as beliefs (`mix bs list domain:design tag:operations`); this doc keeps the **workflow** - how to run an extraction session in practice.

> The shared-prosthetic framing (`cb:a460`), composition-over-retrieval (`cb:a462`), scope-decisions-as-beliefs (`cb:a461`), and the centralized-graph rationale (`cb:a112`) are beliefs now, not prose here - read them with `mix bs show`.

## Extraction workflow

A productive extraction session processes source documents and produces concrete operational value:

1. **Archive source documents** to `sources/` as cleaned text (strip binary attachments, trim quoted text beyond two levels, keep message metadata and IDs). Name files `YYYY-MM-DD-slug.md`. The archive is a stable snapshot, not the live document - the originating system stays the source of truth.

2. **Read with decomposition intent.** Instead of reading linearly and coming away with "mostly handled," parse each section for irreducible claims and evaluate each for composition with existing beliefs.

3. **Layer beliefs.** Primitives first (grounded in source evidence), then compounds (composed beliefs), then inferences (conclusions) and directives (actions). The layering surfaces insights no single document contains - e.g. three scattered policy statements composing into one lifecycle rule that no file states on its own.

4. **User-relayed primitives.** Information relayed in conversation becomes a belief with `artifact: "user:<owner>:YYYY-MM-DD"` and `evidence` citing the session - honest provenance that says "the user told me this" rather than inventing a document.

5. **Dependency fan-in detection.** The highest-value output is often discovering that several separate threads converge on one rule. That fan-in is not visible in any single file; it emerges structurally from the graph.

## Evidence field discipline

Every primitive sourced from a document or artifact carries an `evidence` array. The `claim` is the agent's interpretation; each evidence `detail` is the specific narrative of what the source said. A future session can read the evidence and ask "does this claim actually follow from these words?" - without it, the claim is uncheckable hearsay.

**Schema note (historical):** an earlier schema used top-level `source`/`quote`; the current schema uses `artifact` + `evidence[]`. If you meet an old belief with `source`/`quote`, read `source` as `artifact` and `quote` as the first evidence entry's `detail`.
