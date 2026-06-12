# Codepaths: beliefs anchored to code

A **codepath** is a code-anchored belief collection that reads as a narrated, branching tour of real source files and runs as a test suite over them. Same artifact, one gradient: with assertions off it is a guided walk; with assertions on, contract-grade stops also execute their routed predicates. There is no separate format - the cb schema is the single authority. (Design record and plans: `plans/cb-codepath/`.)

Each node plays a distinct role, and each role has exactly one home:

- **location** - a `code:` artifact anchors the claim to a precise within-file site;
- **narration** - the belief's `claim`;
- **derivation** - `deps` (the from-map stop depends on the raw-data stop);
- **assertion** - `implies` rules routing to named predicates;
- **order** - a separate render-spec belief, never the claims.

## The `code:` locator

```
code:<repo-relative-path>#<anchor>[@<N>]
```

The anchor is a **literal substring** of a current line - everything after the first `#` is one opaque string. An optional trailing `@<N>` selects the Nth match (an anchor that must literally end in `@<digits>` percent-encodes it as `%40<digits>`). The resolved **line number is never stored** - it is recomputed at render/run time by fixed-string match, so refactors that move code do not break the codepath. Resolution failures are maintenance signals, never crashes: a missing anchor warns and the stop still renders (the cue that the anchored symbol was deleted or renamed); a loose anchor (multiple matches, no `@N`) renders the first match plus a "tighten this anchor" warning; an explicit `@N` warns only when out of range. `CB.CodeLocator` is the single parser, and the verifier pins the grammar on every `code:` artifact in any collection.

## The render-spec

Ordering and branching live in a codepath **output-target** governed by contract `cb:c049`, which fixes the shape: an `output-target` contract tagged `output:codepath` whose rules carry an `entry` step id and `render_steps` rows of `{id, belief, goto?, choices?}`; every step's belief must resolve to a belief carrying a valid `code:` artifact; `deps` must equal the union of the steps' belief ids; and navigation is **render metadata only** - it never enters `deps` and never lives in the claim beliefs, so reordering a codepath supersedes the render-spec itself and never churns the claims. The authoring loop follows: claim beliefs go through the write flow as usual, but the render-spec is drafted outside the graph and imported once the order is settled - pre-settlement churn belongs in a draft file, not in supersession history.

## The gradient: assertions on

A stop asserts when its belief is contract-grade: its `implies` rules route to named predicates - `{"when": {"assertions": "on"}, "requires": "from_map_roundtrips?"}`. Per the routing boundary (`cb:c047`) the graph stores only the predicate *name*; the body lives in `CB.Codepath.Predicates`. Contract `cb:c050` adds the safety rule: predicates are **inspection-only** - they observe and never mutate; names must end in `?` or `_check` and resolve only to exported zero-arity boolean functions, and anything else (a bad name, an unknown predicate, a raise, a non-boolean) reports as a failure rather than crashing the suite or executing something it should not.

`mix cb.verify.codepath` is the **dynamic verifier** - a sibling of the static `cb.verify.schema`, not a generalization of it, and the only place predicates run. `--record` treats a test run as materialization: each contract stop's pass/fail refs are written to its belief's `materialized` field with a date - a test run is one more sink, not a new subsystem. (Federation into a live BEAM node via Tidewave is designed - `plans/cb-codepath/plan-3-assertions-runtime.md`, Step B - but deliberately deferred until a predicate genuinely needs live application state.)

## See it run

The shipped `codepath:` collection tours CB's own data pipeline. Rendered linearly:

```sh
CB_BELIEFS=codepath/beliefs.json mix cb.render.codepath belief-pipeline
```

```
codepath:c005 (entry: data)
The belief-pipeline codepath: a narrated, branching tour of the pipeline from raw data to render...

[data] `beliefs/beliefs.json:3` - Raw data - each object is one belief (id, kind, claim, deps). The whole graph is this one file.
  -> How does raw JSON become a struct?: from-map
  -> How is it rendered back out?: formatter

[from-map] `lib/cb/belief.ex:166` - The boundary: a JSON map with string keys becomes a typed %Belief{}. Everything downstream works on the struct, not the map. With assertions on, from_map_roundtrips? must hold: every belief in the loaded collection survives the map -> struct -> map round-trip.

[store] `lib/cb/belief/store.ex:13` - Loads the whole graph off disk and hands back %Belief{} structs. The single read path the CLI and dashboard share. With assertions on, store_reads_structs? must hold: Store.read/0 returns only %Belief{} structs.

[formatter] `lib/cb/belief/formatter.ex:37` - Renders beliefs back out to the terminal (ANSI). The other end of the pipeline from the raw JSON you started at. With assertions on, formatter_renders_table? must hold: Formatter.table/2 renders table output for the loaded collection.
```

Every stop is a clickable `path:line` into the live source, resolved at render time. The entry stop branches; in the interactive presentation (`/present-codepath`) the agent stops there and waits for the reader to choose. And the same artifact, asserted:

```sh
CB_BELIEFS=codepath/beliefs.json mix cb.verify.codepath belief-pipeline
```

```
codepath:c005 (belief-pipeline)
  --    data - narrates only (non-contract)
  PASS  from-map - from_map_roundtrips?
  PASS  store - store_reads_structs?
  PASS  formatter - formatter_renders_table?

3 passed, 0 failed, 1 narrate-only stop(s)
```

The data stop is deliberately narration-only so the shipped example demonstrates the gradient itself: three stops assert, one just narrates, and the renderer treats them identically. The collection's own history demonstrates the supersession discipline too - raising the three stops to contract grade was a structural change (contract-grade is structural, per `cb:c054`), so each went through an adjudicated supersession with its claim and anchor carried verbatim, and the render-spec followed (`codepath:c001 -> c005`). Run `mix bs history codepath:c001 --beliefs codepath/beliefs.json` to see it.
