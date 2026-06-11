# Why "inference" - README source material

Status: D1 resolved as `inference` (Mark, 2026-06-10). This file preserves the
explanatory prose semi-verbatim for the plan-4 README update, per Mark's
directive: present WHY inference is the word, without framing it as a contest
with "implication"; let the edges define the territory. The explanatory style
itself is the asset - carry as much of it into the README as fits.

---

## The deductive/ampliative boundary, in CB's own terms

"Deduce" in everyday speech covers any reasoned conclusion. The technical sense
is narrower: a deduction is truth-preserving because the conclusion's content is
already contained in the premises. If the premises are true, the conclusion is
guaranteed true - and the price of that guarantee is that deduction can never
tell you anything about the world beyond what the premises already encode.

Look at what actually happens in a graph. The deps say: "on case 7 of run 3,
record #7 was omitted from a 12-record bulk write" (twice, two rulers). The
inference says: "the model at this snapshot silently drops records from bulk
writes larger than ten items." The premises are about one case in one run; the
conclusion is about all bulk writes over ten items, ever, by that model version.
No chain of deductive steps gets you from "it happened in case 7" to "it happens
in general" - that gap is the problem of induction, and it is unbridgeable by
deduction from any finite set of observations. The agent authoring that node
performed an ampliative move: a generalization, or in other cases an abduction
("these three failures share a root cause"). Ampliative inference is precisely
inference whose conclusion outruns its premises, which is why it can be wrong
while every premise stays right.

And here is the design payoff: the falsification lifecycle requires that gap. A
deductive consequence can only fall when a premise falls. The inference type is
built to be superseded by new evidence while its deps stay active - a clean
run 4 can kill the generalization without laying a finger on the case-7
observations, which remain perfectly true records of case 7 forever. The
lifecycle only makes sense for conclusions that exceeded their evidence.

## The compound is the one deduction the schema blesses

"A, B, therefore A-and-B" (conjunction introduction) is truth-preserving and
non-ampliative, and the subject-containment check is exactly the formal shadow
of that: a conjunction cannot be about anything its parts are not about. A
compound can only fail if a dep fails - the deduction guarantee, enforced. So
the type boundary is the deductive/ampliative line itself: compound is the safe,
contained move; inference is everything riskier.

A compound is the only node type whose claim genuinely is entailed by its deps.
The epistemic work a compound records is in the selection - which beliefs to
assemble, and that they agree - while the claim itself stays inside the
entailment boundary. Deductive consequences in general are infinite and free,
so the graph never stores them; query tools compute them on demand. The graph
stores the moves that cost something epistemically: attestations (trusting a
source), conjunctions worth assembling (compounds), risky generalizations
(inferences), and commitments (directives).

## The relation, never the mental act

Deduction versus induction is a property of the premises-to-conclusion relation,
never of the mental act. An agent can feel like it is deducing while
generalizing, and vice versa. That is why the verifier interrogates the relation
- does the claim's scope stay inside the deps' scope or exceed it? - instead of
asking the author what kind of reasoning they think they did.

## The membership test: what would count as being wrong

Ask what would count as the belief being wrong:

- An inference is falsified: if the world disagrees, the belief is defective and
  is superseded or retracted. Mind fits world.
- A directive is violated (the world disobeys; the response is to flag the
  violation) or withdrawn (the house stops standing behind it). World fits mind.

Falsified: inference. Violated: directive. Withdrawn: directive.

## The glossary line

An inference is a conclusion drawn from beliefs, licensed to state more than
they jointly state. The licence is the type: a primitive attests, a compound
states exactly what its deps jointly state, an inference is allowed to exceed
them - and pays for the licence by being falsifiable on its own, independent of
its deps. A directive prescribes; it is never falsified, only violated or
withdrawn.

## Style notes for the README pass (from Mark, 2026-06-10)

- Semi-verbatim use encouraged; the explanatory register above is the target
  for the README generally, not just this section.
- No contest framing against "implication"; present the positive case.
- "How the edges define the territory": types are defined by what their dep
  edges license and what failure means for them, not by vibes about content.
- House rules still apply: no emdashes; no "X doesn't Y, it Z" sentence shape.
