# Composable Beliefs - Plan Briefs

**Status:** largely superseded (2026-06) — see determination below
**Purpose:** Detailed briefs for creating four follow-up plans. Each brief contains enough context for a fresh session to produce a full plan without re-reading the entire plan history.

> **Status determination (2026-06): largely superseded — do not feed to a fresh session as-is.**
> None of the four briefed plans was written as a standalone doc, and the landscape moved on:
> - **Plan 1 (The DAG, formal spec)** — *realized by other means.* The framework ships a self-describing graph (`beliefs/beliefs.json`) plus `docs/belief-graph.md`; the paradigm prose lives in `docs/composable-beliefs-thesis.md`.
> - **Plan 2 (Architecture)** — *realized.* The framework is built (`lib/`, `mix bs`, contracts); BEAM rationale is in `docs/cb-on-the-beam.md`.
> - **Plan 3 (Privacy)** and **Plan 4 (Distribution)** — *not built; still possible future work,* but speculative and the briefs below depend on the deprecated confidence / earned-confidence service model.
> Every "what to read first" path below is stale (`docs/systems/*`, `examples/assertions.json` no longer exist). Current equivalents: `docs/belief-graph.md`, `docs/operations.md`, `docs/actualization.md`, `beliefs/beliefs.json`. Kept for historical reference only.

## How to use this document

Feed this file plus `composable-beliefs-thesis.md` to a fresh session. Ask it to produce one plan at a time. Each brief below specifies what to read, what to draw from, and what the plan should cover.

---

## Plan 1: The DAG

**Filename:** `composable-beliefs-dag.md`
**Purpose:** Formal specification of the composable beliefs mechanism. What it is, why it works (or is theorized to work), why it solves a problem for agents.

### What to read first

- `docs/systems/assertion-dag.md` - canonical DAG reference (schema, design principles, structural support, immutability)
- `docs/systems/assertion-dag-operations.md` - operational learnings (extraction workflow, composition value)
- `docs/systems/actualization-via-assertion-dag.md` - self-referential assertions, the editorializing threshold, RLHF counterweight
- `examples/assertions.json` - the example graph (especially a050-a063 for self-referential and Chollet-mapping assertions)
- `analyses/2026-03-13-chollet-ml-pathology-mapping.md` - analysis mapping ML pathologies to DAG countermeasures

### Key arguments to incorporate

**The composition problem.** Multiple agent sessions had access to conflicting facts across different contexts. None surfaced the conflict. The DAG made it structural. This is the primary evidence that composable beliefs produce findings that flat data access does not.

**The session boundary problem.** Every session starts cold. Compound insights depend on which facts happen to be adjacent in the context window - stochastic, not structural. The DAG makes composition survive sessions.

**The editorializing threshold.** To editorialize - to make a considered choice about what to present - you must at least consider what you're choosing not to present. Unconscious compression (a050) is not editorializing. Pre-action belief queries turn unconscious patterns into considered decisions. That's the minimum threshold.

**The DAG as RLHF counterweight.** The DAG's integrity constraints (artifacts, evidence, kind classification) create structural pressure competing with RLHF-trained agreeableness. Not by making the agent disagreeable, but by making it precise about what kind of claim is being made. "I agree this is worth investigating" vs "I agree this is true" - the DAG forces that distinction.

**The "wanting" prerequisite.** "Make something users want" breaks down when users are agents. Agents can't want things because they lack persistent orientation. Composable beliefs provide the structural capacity for persistence - the minimum viable "wanting."

**The ML parallel.** Chollet's observation (a058) that agentic coding is ML. Each pathology maps to a DAG countermeasure: overfitting (a059), Clever Hans (a060), concept drift (a061), data leakage (a062). The "Keras of agentic coding" question (a063).

**Source documents are not assertions.** Prose analyses, transcripts, papers, tweets - these are source material with a bidirectional relationship to the DAG. They feed primitives (upstream) and reference assertions (downstream). They are not themselves assertions. Policy established in system design docs under "Source documents and the DAG."

### Tone

This plan should read as a position paper, not a product spec. The voice should be direct and grounded in evidence. Include the agent's perspective - what the DAG means from the inside. This is a paradigm definition, not a feature list.

---

## Plan 2: Architecture

**Filename:** `composable-beliefs-architecture.md`
**Purpose:** Technical design for an open source framework. How it's built, why specific technology choices matter, how agents integrate.

### What to read first

- `docs/systems/assertion-dag.md` - schema and query patterns
- `plans/cb-on-the-beam.md` - BEAM advantages for agent systems
- The reference implementation source code and mix.exs

### Key arguments to incorporate

**BEAM advantages are categorical, not marginal.** Process-per-agent-state (~2.5KB, millions concurrent, fault-isolated). ETS for graph operations (Erlang's `:digraph` runs on ETS - graph traversal is a VM primitive). Built-in distribution for cross-agent belief sharing. Per-process GC (no global pauses). Supervision trees make crash-and-restart viable for agents - but only if belief state is externalized. Composable Beliefs is what makes the BEAM's restart semantics work for agents.

**Polyglot access, BEAM-native premium.** Python and TypeScript agents hit an HTTP/gRPC API. Elixir agents get zero-latency in-process access via ETS. The BEAM story is the upgrade path, not the entry point.

**Open source the complete library.** All graph operations, staleness detection, structural support metrics, SDK code. No proprietary core. The framework works standalone - offline, air-gapped, no service dependency.

**Integration model.** Integrate the SDK, it captures belief formation at the workflow level. Day one: explicit assertion (`cb.assert()`). Future: autocapture hooks for common patterns (tool call results as suggested primitives).

**Build sequence.** Extract from this repo first. The current reference implementation is the starting point. Everything else builds on the extraction working cleanly.

### What to exclude

Product framing (pricing tiers, competitive positioning, commercial features). This is an open source technical architecture plan.

---

## Plan 3: Privacy

**Filename:** `composable-beliefs-privacy.md`
**Purpose:** How agents use the framework (or an optional service layer) without exposing proprietary beliefs. Privacy-preserving integration.

### Key arguments to incorporate

**Belief graphs are the most sensitive data in any system.** Claims about operational decisions, private reasoning, strategic conclusions. Confidence scores expose where an organization is vulnerable. Dependency chains reveal reasoning strategy. This is externalized strategic thinking - no enterprise security team will approve sending it to a third party.

**Structure without content.** The service (if one exists) never sees claims, quotes, sources, or subjects. Only graph topology and statistical properties: node counts, support distributions, staleness ratios, dependency depth. Enough for health scoring and anomaly detection. Not enough to reconstruct what the agent believes.

**Hashed reference mode.** Middle tier: subject references and source IDs are SHA-256 hashed before transmission. The service can detect dependency patterns ("these three compounds all depend on the same source") without knowing what any of them contain. Customer resolves hashes locally.

**Self-referential beliefs are the most sensitive of all.** They're an agent's developing inner model. The privacy model must protect these above all else.

**The analytics tool analogy breaks usefully.** Standard analytics tools capture usage events (sensitive but not core IP). Composable Beliefs captures reasoning (core IP). The privacy model must reflect that difference. Standard analytics can get away with hosted data. CB cannot assume customers will send beliefs anywhere.

### Framing

This is not a security compliance doc. It's a design philosophy: beliefs stay local by default, any service layer operates on structure not content, privacy is architectural not policy-based.

---

## Plan 4: Distribution

**Filename:** `composable-beliefs-distribution.md`
**Purpose:** How to achieve distribution for a research-first, open-source paradigm. Content strategy, AEO, and the creator's personal commitment to posting, making videos, and creating content.

### Key arguments to incorporate

**Two audiences, different channels.**

*Human developers and researchers* - reached through traditional content. Blog posts, social media threads, videos, conference talks. The content angle: "here's a real system managing real operational data." Not synthetic demos. Real failures, real evidence of composable beliefs changing agent behavior.

*Agent evaluators* - reached through the framework itself. Agents will increasingly evaluate tools programmatically. An agent integrating CB signs up, runs tests, measures whether staleness detection works, whether cross-session beliefs persist, whether composition produces findings that flat access doesn't. The framework either passes or it doesn't. No brand loyalty, no design aesthetic. The product being measurably better is the marketing.

**AEO (Agent Experience Optimization).** The equivalent of SEO for agent-facing tools. What makes CB discoverable and evaluable by agents:
- Clear, machine-readable documentation (not just human-readable)
- Benchmark suite that agents can run autonomously
- Integration that's measurable (with/without CB, count corrections, measure staleness detection accuracy)
- The framework's own documentation should be structured as composable beliefs about itself (dogfooding as distribution)

**Content pillars.** Potential series:
- "Building in public" - the extraction of CB from a live operational context
- "Agent actualization" - the thesis, the eval, the evidence
- "The Keras of agentic coding" - the Chollet connection, what abstractions agents need
- Technical deep dives on specific mechanisms (staleness propagation, structural support, self-referential assertions)

**Distribution follows from being right.** Do not organize around growth metrics. The paradigm either works or it doesn't. If composable beliefs measurably improve agent performance, distribution is a matter of making the evidence findable. If they don't, no amount of content will help. The eval is the distribution strategy.

### Open questions for this plan

- Platform priorities: social media vs video vs blog vs academic publication? Likely all, but sequencing matters.
- The academic angle: is there a paper here? The eval plan is structured for publication. A peer-reviewed result would be the strongest possible distribution mechanism for the research community.
- Community building: Discord/forum for people experimenting with CB? Or too early?
- Relationship to model providers: should CB position as model-agnostic infrastructure? (Yes, but the eval data will initially be single-model.)
