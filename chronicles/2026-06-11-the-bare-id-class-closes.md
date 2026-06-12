# Chronicle: the bare-id class closes

**Span:** 2026-06-11, late evening - one thread, desk-driven, ending clean.
**Register:** chronicle (cb:a520) - narrative for the operator; the audit
trail lives in the graph and in commits 06b6bc5 through dde7676.

## Where things stood

The recency-and-rot close had just landed. The desk held sixteen items,
nothing stale, and the session bootstrapped cold from the graph the way
the ritual intends: pull, desk query, stale check, and the same opening
question as the day before - which of these first?

## The ordering argument

The recommendation went to the verification pair, a513 and a514, and the
reasoning is worth keeping: they are the integrity layer everything else
passes through. Every other desk item will be authored through
`mix cb.import` and checked through `mix cb.verify.schema`, so closing a
silent-failure class in those two tools first makes all subsequent work
safer. a512 was named next for unblocking leverage - it roots the longest
dependency chain on the desk (a512 -> a515, with a488's contract
escalation waiting on it). The glue-UI trio stays parked on its own
settle-through-use clock, and the calibration and design items wait on
decisions that are the operator's, not an agent's.

## Two small gates, one incident class

The incident both items trace to: a batch import followed the moduledoc's
own bare-id example, stored bare ids into a namespaced graph, and every
namespaced lookup and intra-batch dep dangled - while nineteen of nineteen
schema checks passed. The dangle was caught only because someone happened
to run `mix bs tree`.

The class is now closed at two layers. The write gate: `mix cb.import`
derives the graph's namespace as the single prefix every existing id
shares and rejects a spec whose new ids lack it, before any write.
Rejection was chosen over normalization deliberately - normalizing ids
would also require heuristically rewriting intra-batch dep references, and
would write a graph that differs from the spec the dry run showed the
author. The misleading examples that taught the bare-id form in the first
place are corrected.

The verifier: `mix cb.verify.schema` gains a dep-resolution check - every
dep of every active belief must resolve in-collection. The one semantic
choice that mattered: a dep in a namespace the collection's ids never use
is cross-namespace and defers to `mix cb.verify.collection`'s union check,
but a bare dep is never cross-namespace - unresolved means dangling. The
wrong default there would have re-opened the exact incident the check
exists to catch. The incident itself is replayed as a test case.

## The discharge teaches its own lesson

Discharging the pair was the materialize flow's first batch use, and it
surfaced a gap of the same species as the morning's success-message lesson
(agent-behavior:a405): the /materialize skill requires each action item to
carry notes referencing the directive's reasoning "for traceability", but
the default JSON sink records only id, action, source, created, and
status - extra keys are dropped by design. The flow reported success; the
rationale notes written for t0003 through t0006 landed nowhere. The skill
mandates what the sink discards, and nothing says so out loud. That gap is
now cb:a523 on the desk. Smaller friction from the same pass: /materialize
takes a single belief id, so a two-directive discharge meant running the
module by hand, with the skill template interpolating the full argument
string into its own example commands.

One rationale that would otherwise have lived only in the chat - why
rejection rather than normalization - was appended as evidence on a513,
since the code shows the behavior but not the reason.

## Where things stand

The desk stands at fifteen: sixteen minus the discharged pair, plus a523.
All gates green - tests, schema verify (the new check included, running
over the freshly modified graph), and every collection union. Commits
06b6bc5 (the implementation), c598a0d (formatting), dde7676 (the
discharge), plus this close, all pushed. The standing recommendation for
the next session is unchanged: a512, the draft-mode anchor resolver.
