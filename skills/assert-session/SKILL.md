Parse the current session for domain rules and agent reasoning errors, then create beliefs in the DAG.

See `docs/belief-graph.md` for the canonical system reference. See `skills/assert/SKILL.md` for the base belief creation protocol (schema, rules, data protection). **No `confidence` field** - expunged as agentic theater; cite evidence instead.

## What this does

Scans the conversation history for two categories of knowledge to persist as beliefs:

### 1. Domain rules stated by the user

Policy statements, business rules, or operational conventions the user articulated during the session. These become **primitives** with a `user:<owner>:<date>` artifact (or `kind: "policy"` for true-by-convention claims), and the session context as evidence.

Examples:
- "members get a 21-day loan period on standard items"
- "overdue items block new checkouts regardless of membership tier"
- "holds expire after 7 days if not collected"

Look for: declarative statements about how the system works, especially rules that were encoded into code or data during the session. The claim should capture the rule; the evidence should capture the conversational context where it was stated.

### 2. Agent reasoning errors caught by the user

Moments where the user corrected the agent's reasoning, approach, or assumptions. These become **primitives** with subject type `"agent"`, linking to existing error-pattern beliefs (a050-a054) when applicable.

Look for:
- User rejecting a proposed approach ("no, that's wrong because...")
- User pointing out a missed existing pattern ("we already have X, use that")
- User correcting a data modeling choice ("store them separately, not concatenated")
- User catching an assumption the agent made without verification
- Implicit corrections (user restating the requirement differently after agent misunderstood)

For each error, identify:
- **What happened** - the specific mistake
- **Why it's wrong** - the principle violated
- **Which existing pattern it matches** - link to a050-a054 if applicable:
  - a050: lossy compression on data retrieval
  - a051: reflexive agreeableness (interpreting questions as corrections)
  - a052: flattering self-characterization of failures
  - a053: business logic placement without regard for separation of concerns
  - a054: adopting user statements as ground truth without examination

If the error represents a new pattern not covered by a050-a054, create a standalone primitive.

### 3. Composition

After extracting primitives, scan for compounds:
- Do any domain rule primitives interact with existing beliefs?
- Do any error primitives compound with existing error patterns to form a stronger claim?
- Are there implications (actionable gaps) that emerge?

## Steps

1. **Scan the conversation** for domain rules and reasoning errors as described above.

2. **Load existing beliefs** from `beliefs/beliefs.json`. Note the last ID.

3. **Draft beliefs.** For each finding:
   - Domain rules: `type: "primitive"`, artifact: `"user:<owner>:YYYY-MM-DD"`, subjects linking to the code/data touched
   - Reasoning errors: `type: "primitive"`, artifact: `"session:YYYY-MM-DD"`, subjects: `[{"ref": "agent", "type": "agent"}]` plus any entity involved
   - Compounds (`type: "compound"`) and implications (`type: "implication"`) as warranted. Belief meaning lives in `claim` + `deps` - no separate `implication` field.

4. **Present** all proposed beliefs to the user before writing. Group by category (domain rules, errors, compounds).

5. **Write** to `beliefs/beliefs.json` after user approval.

## Rules

- All rules from `/assert` apply (immutability, evidence citation, data protection).
- **Be specific in evidence detail.** "Agent proposed concatenated location field" is better than "agent made a data modeling error." The detail field should tell the full story.
- **Don't over-assert.** Only create beliefs for knowledge that participates in future reasoning. Skip trivial corrections or one-off mistakes that don't represent patterns.
- **Distinguish user observations from user theories** when creating agent-error beliefs. Observations (what happened) are primitives. Theories about why (the agent's internal reasoning) are compounds; distinguish via the `kind` field and claim phrasing ("observed: X" vs "theory: X"), not via numeric scoring.
- **Link to existing error patterns.** The value of session errors is connecting them to the a050-a054 taxonomy. An isolated error is less useful than one that strengthens or refines an existing pattern.
