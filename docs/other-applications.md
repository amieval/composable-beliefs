# Other applications

The eval evidence ledger is one instance of a general mechanism. The same schema, the same query surface, and the same change discipline - immutable beliefs, supersession, structural support, deterministic traversal - take other shapes when pointed at other problems. Two ship in this repo today.

## Durable, auditable reasoning for AI agents

Agents lose their reasoning at every session boundary, and the durable artifacts they leave behind - guidance files, system prompts, memory notes - are flat instructions: an agent can satisfy them superficially without internalizing the reasoning, and there is no structural record of *why* a rule exists or whether it is still true.

In CB, every rule is a belief with provenance. When a premise is superseded, everything resting on it is flagged for review; and the agent-facing digest (this repo's own `CLAUDE.md`) is compiled from the graph, never hand-maintained.

```sh
mix bs stale --cascade        # what is resting on replaced premises?
mix cb.generate.claude_md --check   # is the compiled digest current?
```

The mechanics are the same ones the ledger uses: a rule whose premise has been replaced is exactly a verdict whose evidence has been corrected, and the staleness cascade that flags one flags the other. The schema walk-through is in [the mental model](mental-model.md); the deeper actualization argument - self-referential beliefs as an agent's structural self-knowledge - is in [actualization.md](actualization.md).

## Codepaths: code tours that cannot rot

A codepath is a belief collection anchored to real source files. Rendered, it is a narrated, branching tour of a codebase; executed, it is a test suite over the same claims. Anchors resolve by content at render time, so refactors that move code do not break the tour.

```sh
CB_BELIEFS=codepath/beliefs.json mix cb.verify.codepath belief-pipeline
```

There is no separate format - the cb schema is the single authority, and the narrate/assert gradient is just which stops carry contract-grade rules. The full treatment (the `code:` locator, the render-spec, the shipped tour of CB's own pipeline) is in [codepaths.md](codepaths.md).

## The common thread

Strip the domain vocabulary from any of the three shapes and the same discipline remains: claims are typed and grounded, composition is explicit, change is supersession, and verification is pure traversal. That identity - one mechanism, multiple surfaces - is itself recorded in the graph rather than argued here; see the [design reference index](belief-graph.md) for where to start walking.
