defmodule CB.Belief.GraphTest do
  use ExUnit.Case, async: true

  alias CB.Belief
  alias CB.Belief.Graph

  # A small DAG:
  #   a001, a002 (primitives)
  #   a010 compound deps [a001, a002]
  #   a020 directive deps [a010]
  #   a001 was superseded by a003
  defp dag do
    [
      %Belief{
        id: "a001",
        type: "primitive",
        kind: "rule",
        claim: "fact one",
        status: "active",
        deps: []
      },
      %Belief{
        id: "a002",
        type: "primitive",
        kind: "rule",
        claim: "fact two",
        status: "active",
        deps: []
      },
      %Belief{
        id: "a010",
        type: "compound",
        kind: "observation",
        claim: "combined",
        status: "active",
        deps: ["a001", "a002"]
      },
      %Belief{
        id: "a020",
        type: "directive",
        kind: "rule",
        claim: "action",
        status: "active",
        deps: ["a010"]
      }
    ]
  end

  describe "resolve_id" do
    test "an exact id resolves to itself" do
      beliefs = [
        %Belief{
          id: "cb:c029",
          type: "directive",
          kind: "rule",
          claim: "x",
          status: "active",
          deps: []
        }
      ]

      assert Graph.resolve_id(beliefs, "cb:c029") == {:ok, "cb:c029"}
    end

    test "a bare local id resolves to its single namespaced form" do
      beliefs = [
        %Belief{
          id: "cb:c029",
          type: "directive",
          kind: "rule",
          claim: "x",
          status: "active",
          deps: []
        }
      ]

      assert Graph.resolve_id(beliefs, "c029") == {:ok, "cb:c029"}
    end

    test "an unknown id is not found" do
      beliefs = [
        %Belief{
          id: "cb:c029",
          type: "directive",
          kind: "rule",
          claim: "x",
          status: "active",
          deps: []
        }
      ]

      assert Graph.resolve_id(beliefs, "z999") == {:error, :not_found}
    end

    test "a bare id matching multiple namespaces is ambiguous" do
      beliefs = [
        %Belief{
          id: "cb:c029",
          type: "directive",
          kind: "rule",
          claim: "x",
          status: "active",
          deps: []
        },
        %Belief{
          id: "ops:c029",
          type: "directive",
          kind: "rule",
          claim: "y",
          status: "active",
          deps: []
        }
      ]

      assert Graph.resolve_id(beliefs, "c029") == {:error, {:ambiguous, ["cb:c029", "ops:c029"]}}
    end
  end

  describe "deps / resolve_deps" do
    test "deps/2 returns direct dependency ids" do
      idx = Graph.index(dag())
      assert Graph.deps(Enum.at(dag(), 2), idx) == ["a001", "a002"]
    end

    test "resolve_deps/2 returns dependency structs" do
      d = dag()
      idx = Graph.index(d)
      compound = Enum.find(d, &(&1.id == "a010"))
      resolved = Graph.resolve_deps(compound, idx)
      assert Enum.map(resolved, & &1.id) == ["a001", "a002"]
    end

    test "primitive has no deps" do
      idx = Graph.index(dag())
      assert Graph.deps(Enum.find(dag(), &(&1.id == "a001")), idx) == []
    end
  end

  describe "dependents" do
    test "direct dependents of a primitive" do
      results = Graph.dependents("a001", dag())
      assert Enum.map(results, & &1.id) == ["a010"]
    end

    test "deep dependents reach transitively beyond the direct layer" do
      shallow = Graph.dependents("a001", dag()) |> Enum.map(& &1.id)
      deep = Graph.dependents("a001", dag(), deep: true) |> Enum.map(& &1.id)

      # The transitive dependent a020 is only reachable with deep: true.
      refute "a020" in shallow
      assert "a020" in deep
    end

    test "nothing depends on the top implication" do
      assert Graph.dependents("a020", dag()) == []
    end
  end

  describe "stale" do
    test "active node depending on a superseded node is stale" do
      d =
        dag() ++
          [
            %Belief{
              id: "a003",
              type: "primitive",
              kind: "rule",
              claim: "newer fact",
              status: "active",
              deps: []
            },
            %Belief{
              id: "a001",
              type: "primitive",
              kind: "rule",
              claim: "old fact",
              status: "superseded",
              superseded_by: "a003",
              deps: []
            }
          ]

      # Replace the active a001 with the superseded one for a clean fixture.
      d = Enum.reject(d, &(&1.id == "a001" and &1.status == "active"))

      stale = Graph.stale(d)
      stale_ids = Enum.map(stale, fn {node, _bad} -> node.id end)
      assert "a010" in stale_ids

      {_node, bad} = Enum.find(stale, fn {node, _} -> node.id == "a010" end)
      assert "a001" in bad
    end

    test "cascade surfaces transitively stale nodes" do
      d = [
        %Belief{
          id: "p1",
          type: "primitive",
          kind: "rule",
          claim: "p",
          status: "superseded",
          superseded_by: "p2",
          deps: []
        },
        %Belief{
          id: "p2",
          type: "primitive",
          kind: "rule",
          claim: "p2",
          status: "active",
          deps: []
        },
        %Belief{
          id: "co",
          type: "compound",
          kind: "observation",
          claim: "co",
          status: "active",
          deps: ["p1"]
        },
        %Belief{
          id: "im",
          type: "directive",
          kind: "rule",
          claim: "im",
          status: "active",
          deps: ["co"]
        }
      ]

      direct = Graph.stale(d) |> Enum.map(fn {n, _} -> n.id end)
      assert direct == ["co"]

      cascade = Graph.stale(d, cascade: true) |> Enum.map(fn {n, _} -> n.id end) |> Enum.sort()
      assert cascade == ["co", "im"]
    end

    test "no stale nodes in a clean DAG" do
      assert Graph.stale(dag()) == []
    end
  end

  describe "path" do
    test "finds downstream path from implication to primitive" do
      idx = Graph.index(dag())
      assert {:ok, path} = Graph.path("a020", "a001", idx, dag())
      assert path == ["a020", "a010", "a001"]
    end

    test "finds upstream path from primitive to implication" do
      idx = Graph.index(dag())
      assert {:ok, path} = Graph.path("a001", "a020", idx, dag())
      assert List.first(path) == "a001"
      assert List.last(path) == "a020"
    end

    test "no path between unconnected nodes" do
      d = [
        %Belief{id: "x", type: "primitive", kind: "rule", claim: "x", status: "active", deps: []},
        %Belief{id: "y", type: "primitive", kind: "rule", claim: "y", status: "active", deps: []}
      ]

      idx = Graph.index(d)
      assert Graph.path("x", "y", idx, d) == :no_path
    end
  end

  describe "history" do
    test "returns predecessors and successors of a supersession chain" do
      d = [
        %Belief{
          id: "v1",
          type: "primitive",
          kind: "rule",
          claim: "v1",
          status: "superseded",
          superseded_by: "v2",
          deps: [],
          created: "2024-01-01"
        },
        %Belief{
          id: "v2",
          type: "primitive",
          kind: "rule",
          claim: "v2",
          status: "superseded",
          superseded_by: "v3",
          deps: [],
          created: "2024-02-01"
        },
        %Belief{
          id: "v3",
          type: "primitive",
          kind: "rule",
          claim: "v3",
          status: "active",
          deps: [],
          created: "2024-03-01"
        }
      ]

      {predecessors, successors} = Graph.history("v2", d)
      assert Enum.map(predecessors, & &1.id) == ["v1"]
      assert Enum.map(successors, & &1.id) == ["v3"]
    end

    test "standalone node has empty history" do
      {pre, post} = Graph.history("a001", dag())
      assert pre == []
      assert post == []
    end
  end

  describe "by_subject / stats" do
    test "by_subject finds nodes by ref" do
      d = [
        %Belief{
          id: "a1",
          type: "primitive",
          kind: "rule",
          claim: "c",
          status: "active",
          deps: [],
          subjects: [%{"ref" => "policy/x", "type" => "policy"}]
        },
        %Belief{
          id: "a2",
          type: "primitive",
          kind: "rule",
          claim: "c",
          status: "active",
          deps: [],
          subjects: [%{"ref" => "policy/y", "type" => "policy"}]
        }
      ]

      assert Graph.by_subject(d, ref: "policy/x") |> Enum.map(& &1.id) == ["a1"]

      assert Graph.by_subject(d, type: "policy") |> Enum.map(& &1.id) |> Enum.sort() == [
               "a1",
               "a2"
             ]
    end

    test "stats reports type and status frequencies" do
      s = Graph.stats(dag())
      assert s.total == 4
      assert s.by_type == %{"primitive" => 2, "compound" => 1, "directive" => 1}
      assert s.stale_count == 0
      assert s.unlinked_directives == 1
    end
  end

  describe "recent" do
    # Events spread around a 2026-06-10 window boundary:
    #   r001 created before the window, evidence appended inside it
    #   r002 created on the boundary (inclusive), superseded by r003 inside
    #   r003 successor created inside the window
    #   r004 created before, materialized inside
    #   r005 created before, retracted inside
    #   r006 entirely before the window
    defp recent_dag do
      [
        %Belief{
          id: "r001",
          type: "primitive",
          kind: "rule",
          claim: "old node, new evidence",
          status: "active",
          deps: [],
          created: "2026-06-01",
          evidence: [
            %{"date" => "2026-06-01", "detail" => "founding"},
            %{"date" => "2026-06-11", "detail" => "appended"}
          ]
        },
        %Belief{
          id: "r002",
          type: "directive",
          kind: "rule",
          claim: "boundary node",
          status: "superseded",
          deps: [],
          created: "2026-06-10",
          superseded_by: "r003"
        },
        %Belief{
          id: "r003",
          type: "directive",
          kind: "rule",
          claim: "successor",
          status: "active",
          deps: [],
          created: "2026-06-11"
        },
        %Belief{
          id: "r004",
          type: "directive",
          kind: "action-item",
          claim: "materialized in window",
          status: "active",
          deps: [],
          created: "2026-06-01",
          materialized: %{"date" => "2026-06-11", "todos" => [%{"id" => "t1", "action" => "x"}]}
        },
        %Belief{
          id: "r005",
          type: "primitive",
          kind: "rule",
          claim: "retracted in window",
          status: "retracted",
          deps: [],
          created: "2026-06-01",
          retracted_on: "2026-06-10"
        },
        %Belief{
          id: "r006",
          type: "primitive",
          kind: "rule",
          claim: "entirely before the window",
          status: "active",
          deps: [],
          created: "2026-06-01",
          evidence: [%{"date" => "2026-06-02", "detail" => "old append"}]
        }
      ]
    end

    test "new nodes include the boundary date (inclusive since)" do
      r = Graph.recent(recent_dag(), ~D[2026-06-10])
      assert Enum.map(r.new, & &1.id) == ["r002", "r003"]
    end

    test "supersessions are dated by the successor's created" do
      r = Graph.recent(recent_dag(), ~D[2026-06-11])
      assert Enum.map(r.superseded, fn {old, succ} -> {old.id, succ.id} end) == [{"r002", "r003"}]

      # successor outside the window -> no event
      r2 = Graph.recent(recent_dag(), ~D[2026-06-12])
      assert r2.superseded == []
    end

    test "a supersession pointing at a missing successor is ignored" do
      dangling = [
        %Belief{
          id: "r010",
          type: "primitive",
          kind: "rule",
          claim: "x",
          status: "superseded",
          deps: [],
          created: "2026-06-01",
          superseded_by: "r999"
        }
      ]

      assert Graph.recent(dangling, ~D[2026-06-01]).superseded == []
    end

    test "evidence appended after creation counts; founding and pre-window entries do not" do
      r = Graph.recent(recent_dag(), ~D[2026-06-10])
      assert [{belief, entries}] = r.evidence
      assert belief.id == "r001"
      assert Enum.map(entries, & &1["detail"]) == ["appended"]
    end

    test "same-day evidence on a new node is founding, not an append" do
      same_day = [
        %Belief{
          id: "r020",
          type: "primitive",
          kind: "rule",
          claim: "x",
          status: "active",
          deps: [],
          created: "2026-06-11",
          evidence: [%{"date" => "2026-06-11", "detail" => "founding"}]
        }
      ]

      r = Graph.recent(same_day, ~D[2026-06-10])
      assert r.evidence == []
      assert Enum.map(r.new, & &1.id) == ["r020"]
    end

    test "materializations and retractions are picked up by their own dates" do
      r = Graph.recent(recent_dag(), ~D[2026-06-10])
      assert Enum.map(r.materialized, & &1.id) == ["r004"]
      assert Enum.map(r.retracted, & &1.id) == ["r005"]
    end

    test "events sort by date then id" do
      r = Graph.recent(recent_dag(), ~D[2026-06-01])
      assert Enum.map(r.new, & &1.id) == ["r001", "r004", "r005", "r006", "r002", "r003"]
    end

    test "a window after all activity is empty" do
      r = Graph.recent(recent_dag(), ~D[2026-07-01])
      assert r == %{new: [], superseded: [], evidence: [], materialized: [], retracted: []}
    end
  end
end
