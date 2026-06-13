# Chronicle: the house lists its doors

**Span:** 2026-06-12 - one ceremony: the generated CLAUDE.md learns the
full sanctioned write surface. Session ref:
`session:2026-06-12-claude-md-write-surface`.
**Register:** chronicle (cb:a520) - narrative for the operator; the audit
trail lives in the graph and in this close's commit.

## Where things stood

a531 was the documentation tail of the front-door arc: `mix cb.evidence`
(the a522 discharge) and `mix cb.todo.close` (the a530 discharge) both
existed, both first-production-run hardened, and neither was visible to
a cold session reading CLAUDE.md. The Operations write-flow line - cb:a449,
rendered via the c063 output-target contract - still named only
preflight/adjudicate/import, the surface as it stood on 2026-06-07.
The a530 close had already widened a531's scope (evidence 2): name the
whole surface in one pass, not the evidence door alone.

## The ceremony

The a515 close was the template (a521 -> a524, c062 -> c063); this close
ran the same two-supersession shape.

Materialized t0019 through the bare-id path, then a449 -> a533: the
successor carries the original three-task sentence verbatim and adds the
two doors with their dry-run default. Preflight under the c064
calibration: 0 contract, 0 schema, 28 neutral - the claim_overlap hits
being the supersession target itself and the grounding family
(a522/a530/a531). The wall the old bucketing would have raised never
appeared; the calibration keeps earning its keep.

Then c063 -> c065: the render contract's Operations section points at
cb:a533 in place of cb:a449, deps re-unioned per the contract's own
invariant, everything else verbatim. The chain is c060 -> c061 -> c062 ->
c063 -> c065. Preflight: exactly one contract-level hit - c063 itself,
the supersession target, claim_overlap - and one schema-level hit, a483,
the descriptive v2-migration record with phrasing overlap and no
semantic contact. Reviewed per c055.

c049 (the codepath output-target) depped on c063 and went stale on the
supersession, as it has at every link in the chain; re-pointed to c065
through the drop-dep/add-dep Mutation clauses, which append their own
evidence trail (entries 8 and 9 on c049). Still a `mix run` script
rather than a front door - the dep re-point remains the one recurring
write without a mix task, now at three specimens (c061 -> c062,
c062 -> c063, c063 -> c065).

## The torn commit

Discovered at the close: a concurrent session committed 585f9ec
(minting a535/a536 onto the desk) while this ceremony was mid-flight.
Staging the graph file swept this session's in-progress writes - the
a533/c065 supersessions and the t0019 materialization went into that
commit - while the regenerated CLAUDE.md did not. At 585f9ec the repo's
own gate is red: beliefs.json renders from c065, CLAUDE.md still shows
the a449 text, `mix cb.generate.claude_md --check` fails. No data was
lost in either direction (a535/a536 and this close's writes coexist
cleanly; the id mint skipped a534), and this close's commit repairs
main. But the shape is now a recorded specimen: in a concurrently
written repo, a selective stage of the graph file can land a torn HEAD.
Swept to the desk as a commit-hygiene directive at this close.

## Where things stand

CLAUDE.md regenerates from c065 and the Operations section now names all
five doors: preflight, adjudicate, import, evidence, todo.close. A cold
session reading the file sees the same write surface the graph
sanctions - the gap a531 named is closed.

a531 discharged and off the desk. 326 tests green, schema verify 20/20,
collection 21/23, `mix cb.generate.claude_md --check` current, no stale
beliefs. The desk holds the concurrent session's new a535/a536 plus this
close's sweep items: the dep re-point front door (three specimens, the
last recurring write without a sanctioned task) and concurrent-repo
commit hygiene (the 585f9ec specimen).
