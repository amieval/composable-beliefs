defmodule CB.Belief.ConflictTest do
  use ExUnit.Case, async: true

  alias CB.Belief
  alias CB.Belief.Conflict

  @unrelated %Belief{
    id: "a100",
    type: "primitive",
    kind: "rule",
    domain: "ops",
    tags: ["loan-policy"],
    claim: "Standard loan period is twenty one days",
    artifact: "document:a.md",
    subjects: [%{"ref" => "policy/loan-period", "type" => "policy"}],
    status: "active",
    deps: [],
    rules: [],
    invariants: [],
    created: "2024-09-01"
  }

  @shared_subject %Belief{
    id: "a200",
    type: "primitive",
    kind: "observation",
    domain: "ops",
    tags: ["overdue"],
    claim: "Overdue threshold is midnight after the due date",
    artifact: "document:b.md",
    subjects: [%{"ref" => "policy/overdue-definition", "type" => "policy"}],
    status: "active",
    deps: [],
    rules: [],
    invariants: [],
    created: "2024-09-05"
  }

  @shared_tag %Belief{
    id: "a300",
    type: "primitive",
    kind: "note",
    domain: "ops",
    tags: ["fines"],
    claim: "Fine accrual pauses while the branch is closed",
    artifact: "document:c.md",
    subjects: [%{"ref" => "policy/fines", "type" => "policy"}],
    status: "active",
    deps: [],
    rules: [],
    invariants: [],
    created: "2024-09-06"
  }

  @status_contract %Belief{
    id: "c029",
    type: "implication",
    kind: "state-machine",
    domain: "system",
    tags: ["dag-schema", "status-lifecycle"],
    name: "dag-status-lifecycle",
    claim:
      "DAG node status follows a directed transition: active -> superseded | retracted | retired, with all non-active states terminal",
    contract: true,
    rules: [%{"scenario" => "closed-enum"}],
    invariants: ["status is a closed enum: active | superseded | retracted | retired"],
    subjects: [],
    status: "active",
    deps: [],
    created: "2024-09-10"
  }

  @schema_primitive %Belief{
    id: "a373",
    type: "primitive",
    kind: "schema",
    domain: "system",
    tags: ["dag-schema", "lifecycle"],
    claim: "Implications carry a lifecycle distinct from truth",
    artifact: "document:schema.md",
    subjects: [%{"ref" => "docs/schema.md", "type" => "doc"}],
    status: "superseded",
    superseded_by: "a379",
    deps: [],
    rules: [],
    invariants: [],
    created: "2024-09-11"
  }

  # A proposal that materializes a fifth status value. Matches c029 on
  # the `dag-schema` tag AND on claim tokens (status, active, superseded,
  # retracted, retired); the semantic contact is what licenses the
  # contract-level escalation.
  defp fifth_status_proposal do
    %Belief{
      type: "primitive",
      kind: "schema",
      domain: "system",
      tags: ["dag-schema", "lifecycle"],
      claim:
        "Implications carry a fifth status value materialized alongside active, superseded, retracted, retired",
      artifact: "document:test.md",
      subjects: [%{"ref" => "docs/schema.md", "type" => "doc"}],
      status: "active",
      deps: [],
      rules: [],
      invariants: []
    }
  end

  describe "preflight/2 classification" do
    test "no matches returns empty lists" do
      proposed = %Belief{
        type: "primitive",
        kind: "rule",
        domain: "facilities",
        tags: ["hours"],
        claim: "Branch opens at nine on weekdays",
        subjects: [%{"ref" => "facilities/hours", "type" => "facility"}],
        status: "active",
        deps: [],
        rules: [],
        invariants: []
      }

      result = Conflict.preflight(proposed, [@unrelated, @shared_tag, @shared_subject])
      assert result == %{supportive: [], neutral: [], conflicting: []}
    end

    test "subject-only match classifies as supportive" do
      proposed = %Belief{
        type: "primitive",
        kind: "note",
        domain: "circulation",
        tags: ["renewal"],
        claim: "Overdue items are ineligible for renewal until returned",
        subjects: [%{"ref" => "policy/overdue-definition", "type" => "policy"}],
        status: "active",
        deps: [],
        rules: [],
        invariants: []
      }

      result = Conflict.preflight(proposed, [@unrelated, @shared_subject])
      assert result.conflicting == []
      assert result.neutral == []
      assert [entry] = result.supportive
      assert entry.id == "a200"
      assert :subject_overlap in entry.reasons
      refute Map.has_key?(entry, :priority)
    end

    test "tag-only match classifies as neutral" do
      proposed = %Belief{
        type: "primitive",
        kind: "note",
        domain: "finance",
        tags: ["fines"],
        claim: "Fine ceiling is capped per member account",
        subjects: [%{"ref" => "policy/fine-ceiling", "type" => "policy"}],
        status: "active",
        deps: [],
        rules: [],
        invariants: []
      }

      result = Conflict.preflight(proposed, [@unrelated, @shared_tag])
      assert result.conflicting == []
      assert result.supportive == []
      assert [entry] = result.neutral
      assert entry.id == "a300"
      assert :tag_overlap in entry.reasons
      refute :subject_overlap in entry.reasons
      refute Map.has_key?(entry, :priority)
    end

    test "contract-level conflict surfaces with :contract_level priority" do
      result = Conflict.preflight(fifth_status_proposal(), [@status_contract, @unrelated])

      assert result.supportive == []
      assert result.neutral == []
      assert [entry] = result.conflicting
      assert entry.id == "c029"
      assert entry.priority == :contract_level
      assert :tag_overlap in entry.reasons
      assert :claim_overlap in entry.reasons
    end

    test "bare tag overlap with a contract is neutral but keeps the grade marker" do
      proposed = %Belief{
        type: "directive",
        kind: "action-item",
        domain: "dev",
        tags: ["dag-schema", "backlog"],
        claim: "Provide a renderer for belief cards in the graph viewer",
        subjects: [],
        status: "active",
        deps: [],
        rules: [],
        invariants: []
      }

      result = Conflict.preflight(proposed, [@status_contract])

      assert result.conflicting == []
      assert result.supportive == []
      assert [entry] = result.neutral
      assert entry.id == "c029"
      assert entry.reasons == [:tag_overlap]
      assert entry.priority == :contract_level
    end

    test "bare tag overlap with a schema-tagged non-contract is neutral" do
      active_schema_primitive = %Belief{@schema_primitive | status: "active"}

      proposed = %Belief{
        type: "directive",
        kind: "action-item",
        domain: "dev",
        tags: ["dag-schema", "backlog"],
        claim: "Provide a renderer for belief cards in the graph viewer",
        subjects: [],
        status: "active",
        deps: [],
        rules: [],
        invariants: []
      }

      result = Conflict.preflight(proposed, [active_schema_primitive])

      assert result.conflicting == []
      assert result.supportive == []
      assert [entry] = result.neutral
      assert entry.id == "a373"
      assert entry.reasons == [:tag_overlap]
      refute Map.has_key?(entry, :priority)
    end

    test "subject overlap with a contract escalates without claim overlap" do
      contract_with_subject = %Belief{
        @status_contract
        | subjects: [%{"ref" => "docs/schema.md", "type" => "doc"}]
      }

      proposed = %Belief{
        type: "primitive",
        kind: "note",
        domain: "circulation",
        tags: ["renewal"],
        claim: "Branch opens at nine on weekdays for renewals",
        subjects: [%{"ref" => "docs/schema.md", "type" => "doc"}],
        status: "active",
        deps: [],
        rules: [],
        invariants: []
      }

      result = Conflict.preflight(proposed, [contract_with_subject])

      assert [entry] = result.conflicting
      assert entry.id == "c029"
      assert entry.priority == :contract_level
      assert entry.reasons == [:subject_overlap]
    end

    test "dag-schema primitive match is conflicting but not contract-level" do
      active_schema_primitive = %Belief{@schema_primitive | status: "active"}
      result = Conflict.preflight(fifth_status_proposal(), [active_schema_primitive])

      assert result.supportive == []
      assert result.neutral == []
      assert [entry] = result.conflicting
      assert entry.id == "a373"
      refute Map.has_key?(entry, :priority)
    end

    test "multiple overlapping matches distribute across categories" do
      existing = [@status_contract, @shared_subject, @shared_tag, @unrelated]

      proposal = %Belief{
        type: "primitive",
        kind: "note",
        domain: "ops",
        tags: ["dag-schema", "fines"],
        claim: "Some proposal touching fines on the overdue policy",
        subjects: [%{"ref" => "policy/overdue-definition", "type" => "policy"}],
        status: "active",
        deps: [],
        rules: [],
        invariants: []
      }

      result = Conflict.preflight(proposal, existing)

      conflicting_ids = Elixir.Enum.map(result.conflicting, & &1.id)
      supportive_ids = Elixir.Enum.map(result.supportive, & &1.id)
      neutral_ids = Elixir.Enum.map(result.neutral, & &1.id)

      # c029 matches on the dag-schema tag alone (claim overlap is barred
      # by the domain mismatch): family resemblance without semantic
      # contact stays informational, grade marker intact.
      assert "c029" in neutral_ids
      assert Elixir.Enum.find(result.neutral, &(&1.id == "c029")).priority == :contract_level
      assert "a200" in supportive_ids
      assert "a300" in neutral_ids
      refute "a100" in (conflicting_ids ++ supportive_ids ++ neutral_ids)
    end

    test "self-match is skipped when proposed already has an id" do
      proposed = %Belief{@status_contract | claim: "different claim entirely"}
      result = Conflict.preflight(proposed, [@status_contract])
      assert result == %{supportive: [], neutral: [], conflicting: []}
    end

    test "superseded and retracted beliefs are skipped" do
      result = Conflict.preflight(fifth_status_proposal(), [@schema_primitive])
      assert result == %{supportive: [], neutral: [], conflicting: []}
    end
  end
end
