defmodule CB.Belief.FilterTest do
  use ExUnit.Case, async: true

  alias CB.Belief
  alias CB.Belief.Filter

  @primitive %Belief{
    id: "a001",
    type: "primitive",
    kind: "rule",
    tags: ["loan-policy"],
    claim: "Standard loan period",
    artifact: "document:policy.md",
    subjects: [%{"ref" => "policy/loan-period", "type" => "policy"}],
    status: "active",
    deps: [],
    created: "2024-09-01"
  }

  @compound %Belief{
    id: "a013",
    type: "compound",
    kind: "observation",
    tags: [],
    claim: "Combined meaning",
    subjects: [
      %{"ref" => "policy/loan-period", "type" => "policy"},
      %{"ref" => "policy/overdue-definition", "type" => "policy"}
    ],
    deps: ["a001", "a005"],
    status: "active",
    created: "2024-09-15"
  }

  @implication %Belief{
    id: "a015",
    type: "implication",
    kind: "rule",
    tags: ["hold-queue", "lifecycle"],
    claim: "Action needed",
    subjects: [%{"ref" => "policy/hold-queue", "type" => "policy"}],
    deps: ["a013"],
    materialized: nil,
    status: "active",
    created: "2024-09-15"
  }

  @contract %Belief{
    id: "c001",
    type: "implication",
    kind: "state-machine",
    tags: ["loan-lifecycle"],
    contract: true,
    rules: [%{"scenario" => "test"}],
    invariants: [],
    claim: "Contract",
    subjects: [],
    deps: [],
    status: "active",
    created: "2024-09-20"
  }

  @superseded %Belief{@primitive | id: "a099", status: "superseded"}

  test "default filter excludes non-active" do
    {filters, _opts} = Filter.parse_args([])
    result = Filter.apply_filters([@primitive, @superseded], filters)
    assert length(result) == 1
    assert hd(result).id == "a001"
  end

  test "type filter selects by structural type" do
    {filters, _opts} = Filter.parse_args(["compound"])
    result = Filter.apply_filters([@primitive, @compound, @implication], filters)
    assert length(result) == 1
    assert hd(result).id == "a013"
  end

  test "kind filter selects by semantic kind" do
    {filters, _opts} = Filter.parse_args(["kind:observation"])
    result = Filter.apply_filters([@primitive, @compound, @implication], filters)
    assert length(result) == 1
    assert hd(result).id == "a013"
  end

  test "tag filter selects by tag" do
    {filters, _opts} = Filter.parse_args(["tag:hold-queue"])
    result = Filter.apply_filters([@primitive, @compound, @implication], filters)
    assert length(result) == 1
    assert hd(result).id == "a015"
  end

  test "--tag flag selects by tag" do
    {filters, _opts} = Filter.parse_args(["--tag", "loan-policy"])
    result = Filter.apply_filters([@primitive, @compound, @implication], filters)
    assert length(result) == 1
    assert hd(result).id == "a001"
  end

  test "contracts filter selects contract-grade implications" do
    {filters, _opts} = Filter.parse_args(["contracts"])
    result = Filter.apply_filters([@primitive, @compound, @implication, @contract], filters)
    assert length(result) == 1
    assert hd(result).id == "c001"
  end

  test "status filter overrides default" do
    {filters, _opts} = Filter.parse_args(["superseded"])
    result = Filter.apply_filters([@primitive, @superseded], filters)
    assert length(result) == 1
    assert hd(result).id == "a099"
  end

  test "all filter includes all statuses" do
    {filters, _opts} = Filter.parse_args(["all"])
    result = Filter.apply_filters([@primitive, @superseded], filters)
    assert length(result) == 2
  end

  test "unlinked filter finds implications without materialized items" do
    linked = %Belief{@implication | id: "a016", materialized: %{"date" => "x", "todos" => []}}
    {filters, _opts} = Filter.parse_args(["unlinked"])
    result = Filter.apply_filters([@implication, linked], filters)
    assert length(result) == 1
    assert hd(result).id == "a015"
  end

  test "subject ref filter matches by ref path" do
    other = %Belief{@primitive | id: "a011", subjects: [%{"ref" => "policy/fines", "type" => "policy"}]}
    {filters, _opts} = Filter.parse_args(["policy/loan-period"])
    result = Filter.apply_filters([@primitive, other], filters)
    assert length(result) == 1
    assert hd(result).id == "a001"
  end

  test "subject_type filter matches by subject type" do
    member = %Belief{@primitive | id: "a011", subjects: [%{"ref" => "members/m-001", "type" => "member"}]}
    {filters, _opts} = Filter.parse_args(["subject_type:member"])
    result = Filter.apply_filters([@compound, member], filters)
    assert length(result) == 1
    assert hd(result).id == "a011"
  end

  test "sort orders by type then id" do
    sorted = Filter.sort([@implication, @primitive, @compound])
    assert Enum.map(sorted, & &1.id) == ["a001", "a013", "a015"]
  end

  test "unknown filter is reported in opts" do
    {_filters, opts} = Filter.parse_args(["bogus"])
    assert Keyword.get(opts, :unknown) == "bogus"
  end
end
