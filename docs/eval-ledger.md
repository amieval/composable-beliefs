# The eval evidence ledger

When you publish an eval finding - "model X silently drops records from bulk writes" - the finding is only as credible as the trail behind it. How many runs? Which scorers, and do they agree? Where are the raw logs? Was the LLM judge ever validated against a human? When the model ships a new snapshot, does the verdict get corrected visibly or quietly rewritten? CB's answer is to make the entire trail graph structure: every measurement a belief, every methodological rule a contract, every correction a supersession a reader can see. (Design record: `plans/cb-eval/`.)

The boundary, held on purpose: **CB is the ledger, not the lab bench.** Running evals - orchestration, sampling, retries, model calls - happens in an external harness (Inspect, via the sibling `bench` repo). CB ingests the harness's *output record* and never grows toward execution.

## The shape of a finding

A published finding is an evidence chain that exercises all four structural types, with a division of labor between machine and human. One term of art first: a **ruler** is CB's word for a scorer or judge - deterministic differs and LLM judges alike.

- **Observations** (primitives) - what a ruler measured: one aggregate per (run, ruler) pair, plus per-case primitives for the handful of cases that carry the finding. Imported mechanically. Observations are *immutable measurements*: a new model snapshot never supersedes them, because the old snapshot really did behave that way on that day.
- **Cross-ruler agreement** (compounds) - two independent rulers reached the same outcome; the compound asserts the corroboration, which neither observation states alone. Authored by a human.
- **Verdicts** (inferences) - the falsifiable finding ("model X at this snapshot silently drops records...") scoped to a `model_version` subject. Authored by a human, and inference-only by contract (`method:c10`): a verdict must be derived, never merely attested or prescribed. When new snapshot evidence arrives, the *verdict* is superseded - the staleness pivot - and `--cascade` flags everything downstream for review.
- **Guidance** (directives) - the prescription resting on the finding ("do not use unguarded..."). Authored by a human; violated or withdrawn, never falsified. The finding and the prescription are separate nodes by design, so a newer snapshot falsifies the verdict without ambiguity about what happens to the rule that rested on it.

## Methodology as contracts that enforce themselves

House methodology usually lives in prose - a METHODOLOGY.md nobody can mechanically check. Here it is six contract-grade beliefs in the `method:` base collection (the shared eval vocabulary in `belief-collections`), each routing to a named predicate that runs over any eval collection during `mix cb.verify.collection`:

| Contract | What it enforces |
| --- | --- |
| m-corroboration | every verdict reaches a cross-ruler-agreement compound, or visibly carries the `single-ruler` escape tag |
| m-provenance | every observation carries an `eval:` identity URI *and* a raw-log pointer in its evidence |
| m-subjects | every observation carries the six conventional subjects (eval, run, case, model, model_version, ruler) |
| m-runs | every verdict cites at least 3 distinct runs - **no escape hatch**: a result that can't is not a weaker verdict, it is not a verdict; author it as an observation or guidance |
| m-judge-validation | every LLM-judge observation is joined by that judge's human-agreement validation record |
| m-correction | corrections are supersessions with dated evidence; bare retraction is reserved for full withdrawal |

Because these are graph-shape checks, they are pure traversal - deterministic - so they run as a static pass beside the schema checks, not in the dynamic verifier. A failed check names the offending belief ids - the failure message is the work order. And "methodology v2" is not a doc edit: it is a batch of adjudicated supersessions of these contracts, dated and diffable via `bs history`.

Strip the eval vocabulary from these six rules and what remains is the epistemics you would want load-bearing in an agent's head: seek independent confirmation, cite raw evidence, never generalize from one sample, calibrate your judges, revise visibly. That identity - eval architecture as agentic epistemic architecture, externalized - is itself in a graph, with the methodology contracts as its subjects: `paradigm:a361` and `paradigm:a364` in the sibling `belief-collections` repo, traceable like any other belief.

## The run-manifest: how harness output becomes ledger input

The seam between bench and ledger is one neutral JSON format, the **run-manifest** ([run-manifest.md](run-manifest.md)). A thin adapter per harness converts native logs to it; CB never learns any harness's log format. Two properties make the importer trustworthy:

- **The aggregation policy is structural.** Every (run, ruler) pair yields one aggregate observation, always; per-case observations are minted only for cases the manifest lists as *load-bearing*. The judgment of what is load-bearing stays upstream with a human; the importer stays mechanical - and warns if a manifest would flood the graph, because the graph must stay human-readable.
- **Identity is hashed, so change is detectable.** Belief ids derive from the observation's identity tuple (eval, run, ruler[, case]), never its content. The same manifest re-imported is a detected no-op; a *changed* manifest under the same run id is a hard error - a corrected run is a new `run_id`, never a quiet rewrite.

The importer emits **observation primitives only** - no compounds, no verdicts. The moment an importer authors judgments, the judgment layer has been automated away; the tool's shape enforces the division of labor. One more provenance rule rides along: anything derived from synthetic or mock data carries the `fixture` tag, so test scaffolding can never be mistaken for a finding.

## The audit tree: the published artifact

`mix cb.render.audit <verdict-id> --collection <ns> --out audit.html` renders a belief's full evidence tree as **one self-contained HTML file**: verdict at the root, deps walked down to leaf observations, every subject, tag, artifact, and - closing a gap `bs tree` has - every evidence entry's raw-log pointer. Superseded nodes render struck-through with a link to their successor; nodes resting on superseded deps carry a `stale` badge; a footer records the union's namespaces and content digest. Zero JavaScript (collapse/expand is native `<details>`), no external assets, no network: a reader needs a browser, not Elixir. A `--json` twin exposes the same tree as data, and `--check` lets CI gate a committed tree against the graph exactly as CLAUDE.md is gated.

The result: a reader of a published finding can answer "what evidence does this verdict rest on, and where are the raw logs?" by clicking, and a corrected finding *visibly wears* its correction.
