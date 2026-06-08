defmodule CB.Belief.ContractTest do
  use ExUnit.Case, async: true

  alias CB.Belief
  alias CB.Belief.Contract.{Enum, Implies, StateMachine, Table}

  describe "Contract.StateMachine" do
    @sm %Belief{
      id: "c001",
      type: "implication",
      kind: "state-machine",
      contract: true,
      rules: [
        %{"from" => "available", "to" => "checked-out", "requires" => ["member_eligible"]},
        %{"from" => "checked-out", "to" => "overdue", "requires" => []},
        %{"from" => "checked-out", "to" => "available", "requires" => []},
        %{"from" => "overdue", "to" => "available", "requires" => ["fine_paid"]}
      ]
    }

    test "edges/1 returns all transition edges as atom-keyed maps" do
      edges = StateMachine.edges(@sm)
      assert length(edges) == 4
      assert %{from: "available", to: "checked-out", requires: ["member_eligible"]} in edges
    end

    test "transitions_from/2 lists reachable target states" do
      assert StateMachine.transitions_from(@sm, "checked-out") |> Elixir.Enum.sort() ==
               ["available", "overdue"]
    end

    test "transitions_from/2 is empty for terminal-like states" do
      assert StateMachine.transitions_from(@sm, "nonexistent") == []
    end

    test "requires/2 returns the edge's requirement slugs" do
      assert StateMachine.requires(@sm, {"overdue", "available"}) == {:ok, ["fine_paid"]}
      assert StateMachine.requires(@sm, {"checked-out", "overdue"}) == {:ok, []}
    end

    test "requires/2 returns :error for undeclared edges" do
      assert StateMachine.requires(@sm, {"available", "overdue"}) == :error
    end

    test "valid_edge?/2 reflects edge existence" do
      assert StateMachine.valid_edge?(@sm, {"available", "checked-out"})
      refute StateMachine.valid_edge?(@sm, {"available", "overdue"})
    end
  end

  describe "Contract.Enum" do
    @enum %Belief{
      id: "c002",
      type: "implication",
      kind: "enum-registry",
      contract: true,
      rules: [
        %{"field" => "status", "values" => ["available", "checked-out", "overdue"]},
        %{"field" => "tier", "values" => ["standard", "premium"]}
      ]
    }

    test "fields/1 lists declared fields" do
      assert Enum.fields(@enum) |> Elixir.Enum.sort() == ["status", "tier"]
    end

    test "values_for/2 returns the allowed value set" do
      assert Enum.values_for(@enum, "status") == ["available", "checked-out", "overdue"]
      assert Enum.values_for(@enum, "missing") == []
    end

    test "valid_value?/3 validates against the declared vocabulary" do
      assert Enum.valid_value?(@enum, "tier", "premium")
      refute Enum.valid_value?(@enum, "tier", "platinum")
      refute Enum.valid_value?(@enum, "missing", "anything")
    end

    test "fields_accepting/2 reverse-looks-up fields by value" do
      assert Enum.fields_accepting(@enum, "premium") == ["tier"]
    end

    test "entries/1 returns the raw fact relation" do
      assert %{field: "tier", values: ["standard", "premium"]} in Enum.entries(@enum)
    end
  end

  describe "Contract.Table" do
    @table %Belief{
      id: "c003",
      type: "implication",
      kind: "derivation-table",
      contract: true,
      rules: [
        %{"overdue" => true, "at_limit" => false, "can_checkout" => false},
        %{"overdue" => false, "at_limit" => true, "can_checkout" => false},
        %{"overdue" => false, "at_limit" => false, "can_checkout" => true}
      ]
    }

    test "rows/1 returns the full relation" do
      assert length(Table.rows(@table)) == 3
    end

    test "lookup/2 selects rows matching all conditions" do
      assert Table.lookup(@table, %{"overdue" => false, "at_limit" => false}) ==
               [%{"overdue" => false, "at_limit" => false, "can_checkout" => true}]
    end

    test "column_values/2 projects distinct values of a column" do
      assert Table.column_values(@table, "can_checkout") |> Elixir.Enum.sort() == [false, true]
    end

    test "has_match?/2 answers satisfiability" do
      assert Table.has_match?(@table, %{"can_checkout" => true})
      refute Table.has_match?(@table, %{"overdue" => true, "can_checkout" => true})
    end

    test "columns/1 lists all column names sorted" do
      assert Table.columns(@table) == ["at_limit", "can_checkout", "overdue"]
    end
  end

  describe "Contract.Implies" do
    @implies %Belief{
      id: "c004",
      type: "implication",
      kind: "implies",
      contract: true,
      rules: [
        %{"when" => %{"status" => "overdue"}, "requires" => "block_checkout"},
        %{"when" => %{"tier" => "premium", "status" => "checked-out"}, "requires" => "extend_eligible"}
      ]
    }

    test "invariants/1 returns when/requires maps" do
      assert %{when: %{"status" => "overdue"}, requires: "block_checkout"} in Implies.invariants(@implies)
    end

    test "applicable/2 fires invariants whose condition matches" do
      assert Implies.applicable(@implies, %{"status" => "overdue", "tier" => "standard"}) ==
               ["block_checkout"]
    end

    test "applicable/2 requires every when key to match (partial match on extra keys)" do
      fields = %{"tier" => "premium", "status" => "checked-out", "irrelevant" => 1}
      assert Implies.applicable(@implies, fields) == ["extend_eligible"]
    end

    test "applicable/2 is empty when no condition matches" do
      assert Implies.applicable(@implies, %{"status" => "available"}) == []
    end

    test "condition_for/2 returns the when map for a slug" do
      assert Implies.condition_for(@implies, "block_checkout") == {:ok, %{"status" => "overdue"}}
      assert Implies.condition_for(@implies, "missing") == :error
    end
  end
end
