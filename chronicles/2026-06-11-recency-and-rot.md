# Chronicle: recency and rot

**Span:** 2026-06-11, evening - one thread, desk-driven, ending clean.
**Register:** chronicle (cb:a520) - narrative for the operator; the audit
trail lives in `plans/cb-schema-v2/transcript-execution.md` (postscript 8)
and the graph.

## Where things stood

The schema epoch had just closed at stasis. The graph owned the backlog,
CLAUDE.md compiled the bootstrap, and the new session-start ritual (a508)
had never actually been run cold by a thread that then did a full day's
work. The desk held seven items, with my ordering question - which of these
first? - still open.

## The bootstrap works, and the desk moves under it

This session was the ritual's first real test: it came up from nothing but
the graph, found the desk, and asked for an ordering. The answer surfaced
structure the graph doesn't encode: the observability items chain (recency
view, then overlay union, then cross-collection desk), the glue-UI pair has
a clock that only starts when cards exist, and the design pair waits on a
decision that is yours, not an agent's.

Then the day proved the recency view's case before it was built. Between
this session's bootstrap and its first commit attempt, concurrent threads
had already committed the belief it was about to commit and grown the desk
from seven items to sixteen. When `mix bs recent` compiled an hour later,
its first real run rendered that burst - 78 events in two days, grouped and
dated, no git archaeology. The tool's own birth was its best demo.

## The bug with a lesson attached

Materializing a501 reported success; nothing persisted. The serializer
only wrote fields that existed in the source JSON, so the materializer's
link-back - assigned in memory after load - was dropped without a sound.
The fix was small; the lesson was not: a tool's success message describes
the code path it took, not the state that landed. That pattern is now a
belief (agent-behavior:a405), and the fix means every future in-memory
field assignment actually lands - the close you are reading exercised that
fix a dozen times.

## The audit, and what rot looks like

You asked whether /assert-session was still current. The audit found
something better than a stale skill: a clean specimen of *why* skills go
stale. Every broken part of it had cached canon as prose - a taxonomy
snapshot, a schema restatement, a write procedure - and every part still
alive was judgment the graph doesn't carry. That is the digest antipattern
(a386) wearing a skill file as a coat. You then collapsed my case for
keeping it separate (its mid-session use was my own suggestion bouncing
back; its framework-wide scope was unwanted), and the skill folded into
your /end sweep: the framework now ships four skills (a521), CLAUDE.md
re-renders through c062, and /end learned to look for agent reasoning
errors, to retro-pair session slugs, and to graduate wire records.

## The close corrects its own author

The end-of-session sweep found the audit's one real error: I had declared
the a050-a054 error taxonomy "never ported" after querying a single
namespace. It lives in agent-behavior:, 101 beliefs strong, written to by
another session the same day. The wrong conclusion became the best evidence
yet appended to a500 (the cross-collection desk view): one-namespace
queries license confident nonexistence claims, and only a structural fix
removes the vigilance tax. The close also seeded a522 - evidence appends
have no front door and were hand-scripted three times today - and fed the
preflight-noise calibration item (a519) its second specimen: 51 bare
tag-overlaps drowning one true match.

## What the next session inherits

The desk holds fifteen-plus items; the recommended next is a519 (preflight
calibration - two same-day specimens make the spec nearly self-writing),
then the observability pair a499/a500, then a502 to start a503's clock.
The design pair (a494/a495) still waits on your direction call. The to_map
pattern (a405) is the first error-pattern node minted under the new /end
category; whether that category earns its place in the sweep is something
the next few closes will show.
