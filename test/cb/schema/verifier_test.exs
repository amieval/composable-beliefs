defmodule CB.Schema.VerifierTest do
  # Exercises the collection-agnostic discovery directly, with tiny in-memory
  # collections, so the generalization is pinned independent of any graph file.
  use ExUnit.Case, async: true

  alias CB.Belief
  alias CB.Schema.Verifier

  defp status_of(results, name) do
    {^name, status, _detail} = Enum.find(results, fn {n, _, _} -> n == name end)
    status
  end

  # A belief from a sparse field list, with sensible active/empty defaults.
  defp b(fields), do: struct(Belief, Map.merge(%{status: "active", deps: []}, Map.new(fields)))

  defp kind_enum(values) do
    b(
      id: "x:c001",
      type: "implication",
      kind: "enum-registry",
      contract: true,
      tags: ["enum", "kind"],
      rules: [%{"field" => "kind", "values" => values}]
    )
  end

  test "an enum is discovered by the field it declares, not by id" do
    beliefs = [
      kind_enum(["rule", "enum-registry"]),
      b(id: "x:a001", type: "primitive", kind: "rule")
    ]

    assert status_of(Verifier.check(beliefs), "kind enum") == :ok
  end

  test "a value outside the declared enum fails" do
    beliefs = [
      kind_enum(["rule", "enum-registry"]),
      b(id: "x:a001", type: "primitive", kind: "bogus")
    ]

    assert status_of(Verifier.check(beliefs), "kind enum") == :fail
  end

  test "a field with no enum contract is skipped, not failed" do
    beliefs = [b(id: "x:a001", type: "primitive", kind: "anything", domain: "whatever")]
    results = Verifier.check(beliefs)

    assert status_of(results, "kind enum") == :skip
    assert status_of(results, "domain enum") == :skip
    assert status_of(results, "artifact-scheme enum") == :skip
  end

  test "a superseded enum contract is not used for discovery" do
    superseded = %{kind_enum(["rule"]) | status: "superseded", superseded_by: "x:c002"}
    beliefs = [superseded, b(id: "x:a001", type: "primitive", kind: "rule")]
    # No *active* enum contract declares kind, so the check skips.
    assert status_of(Verifier.check(beliefs), "kind enum") == :skip
  end

  test "an artifact scheme outside the declared enum fails (closed enum)" do
    scheme_enum =
      b(
        id: "x:c002",
        type: "implication",
        kind: "enum-registry",
        contract: true,
        rules: [%{"field" => "artifact-scheme", "values" => ["document", "code"]}]
      )

    ok = [scheme_enum, b(id: "x:a001", type: "primitive", artifact: "code:lib/a.ex#def read")]
    assert status_of(Verifier.check(ok), "artifact-scheme enum") == :ok

    bad = [scheme_enum, b(id: "x:a002", type: "primitive", artifact: "undeclared:thing")]
    assert status_of(Verifier.check(bad), "artifact-scheme enum") == :fail
  end

  test "a malformed code: artifact fails the locator format check" do
    beliefs = [
      b(id: "x:a001", type: "primitive", artifact: "code:lib/a.ex#def read"),
      b(id: "x:a002", type: "primitive", artifact: "code:lib/a.ex")
    ]

    assert status_of(Verifier.check(beliefs), "code: locator format") == :fail
  end

  test "well-formed code: artifacts pass the locator format check" do
    beliefs = [b(id: "x:a001", type: "primitive", artifact: "code:lib/a.ex#def read@2")]
    assert status_of(Verifier.check(beliefs), "code: locator format") == :ok
  end

  test "codepath targets are skipped when none are present" do
    beliefs = [b(id: "x:a001", type: "primitive", kind: "fact")]
    assert status_of(Verifier.check(beliefs), "codepath output-targets") == :skip
  end

  test "a valid codepath output-target passes; a broken one fails" do
    anchored = b(id: "x:a001", type: "primitive", artifact: "code:lib/a.ex#def read")

    target =
      b(
        id: "x:c100",
        type: "implication",
        kind: "output-target",
        contract: true,
        tags: ["output:codepath"],
        deps: ["x:a001"],
        rules: [
          %{"entry" => "data"},
          %{"render_steps" => [%{"id" => "data", "belief" => "x:a001"}]}
        ]
      )

    assert status_of(Verifier.check([anchored, target]), "codepath output-targets") == :ok

    broken = %{target | deps: []}
    assert status_of(Verifier.check([anchored, broken]), "codepath output-targets") == :fail
  end

  test "status falls back to framework canon when no status-lifecycle contract is present" do
    beliefs = [b(id: "x:a001", type: "primitive", kind: "rule", status: "active")]
    assert status_of(Verifier.check(beliefs), "status enum") == :ok
  end

  test "a status outside the framework canon fails under the canon fallback" do
    beliefs = [b(id: "x:a001", type: "primitive", kind: "rule", status: "bogus")]
    assert status_of(Verifier.check(beliefs), "status enum") == :fail
  end
end
