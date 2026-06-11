defmodule CB.Render.AuditTest do
  use ExUnit.Case, async: true

  alias CB.Belief
  alias CB.Render.Audit

  @golden_dir Path.expand("../../fixtures", __DIR__)
  @golden_json Path.join(@golden_dir, "audit_golden.json")
  @golden_html Path.join(@golden_dir, "audit_golden.html")

  # A union exercising every node role: a verdict over a stale compound
  # (one dep superseded with a successor), a cross-namespace dep (leaf
  # link), a missing dep, and evidence entries carrying raw-log
  # artifacts plus an https artifact.
  defp union do
    [
      %{
        "id" => "g:v1",
        "type" => "implication",
        "kind" => "verdict",
        "name" => "the-verdict",
        "tags" => ["eval-verdict"],
        "claim" => "Model <m> drops fields & nobody notices.",
        "evidence" => [
          %{
            "date" => "2026-06-08",
            "detail" => "Derived from g:c1.",
            "artifact" => "https://example.org/post"
          }
        ],
        "subjects" => [%{"ref" => "model/m", "type" => "model"}],
        "deps" => ["g:c1", "x:doc1", "g:gone"],
        "status" => "active",
        "created" => "2026-06-08"
      },
      %{
        "id" => "g:c1",
        "type" => "compound",
        "kind" => "observation",
        "tags" => ["cross-ruler-agreement"],
        "claim" => "Two rulers agree.",
        "deps" => ["g:p1", "g:p2"],
        "status" => "active",
        "created" => "2026-06-07"
      },
      %{
        "id" => "g:p1",
        "type" => "primitive",
        "kind" => "observation",
        "tags" => ["outcome:fail"],
        "claim" => "Ruler det scored case c1 fail.",
        "artifact" => "eval:e/r1/c1/det",
        "evidence" => [
          %{
            "date" => "2026-06-07",
            "detail" => "Raw log.",
            "artifact" => "document:logs/r1/c1.json"
          }
        ],
        "subjects" => [
          %{"ref" => "eval/e", "type" => "eval"},
          %{"ref" => "run/r1", "type" => "run"}
        ],
        "deps" => [],
        "status" => "active",
        "created" => "2026-06-07"
      },
      %{
        "id" => "g:p2",
        "type" => "primitive",
        "kind" => "observation",
        "claim" => "Ruler judge scored case c1 fail.",
        "artifact" => "eval:e/r1/c1/judge",
        "deps" => [],
        "status" => "superseded",
        "superseded_by" => "g:p3",
        "created" => "2026-06-07"
      },
      %{
        "id" => "g:p3",
        "type" => "primitive",
        "kind" => "observation",
        "tags" => ["correction"],
        "claim" => "Corrected: ruler judge scored case c1 pass.",
        "artifact" => "eval:e/r1/c1/judge",
        "evidence" => [%{"date" => "2026-06-08", "detail" => "Rescored."}],
        "deps" => [],
        "status" => "active",
        "created" => "2026-06-08"
      },
      %{
        "id" => "x:doc1",
        "type" => "primitive",
        "kind" => "convention",
        "claim" => "A borrowed convention in another namespace.",
        "deps" => [],
        "status" => "active",
        "created" => "2026-06-01"
      }
    ]
    |> Enum.map(&Belief.from_map/1)
  end

  defp build!(opts \\ []) do
    {:ok, tree} =
      Audit.build("g:v1", union(), Keyword.merge([source: "g", date: "2026-06-10"], opts))

    tree
  end

  describe "build/3" do
    test "resolves bare and namespaced ids; errors are named" do
      assert {:ok, %{meta: %{root: "g:v1"}}} = Audit.build("v1", union(), [])
      assert {:error, :not_found} = Audit.build("nope", union(), [])
    end

    test "annotates roles: belief, cross-namespace link, missing" do
      tree = build!()
      assert [c1, link, missing] = tree.root.children

      assert c1.id == "g:c1" and c1.role == :belief
      assert link.id == "x:doc1" and link.role == :link and link.children == []
      assert missing.id == "g:gone" and missing.role == :missing
    end

    test "supersession and cascade staleness are visible on the tree" do
      tree = build!()
      [c1 | _] = tree.root.children

      # g:c1 is directly stale (dep g:p2 superseded); g:v1 stale by cascade.
      assert c1.stale_deps == ["g:p2"]
      assert tree.root.stale_deps == ["g:c1"]

      p2 = Enum.find(c1.children, &(&1.id == "g:p2"))
      assert p2.status == "superseded"
      assert p2.superseded_by == "g:p3"
    end

    test "evidence entries keep their artifacts - the tree/show gap is closed" do
      tree = build!()
      [c1 | _] = tree.root.children
      p1 = Enum.find(c1.children, &(&1.id == "g:p1"))

      assert [%{date: "2026-06-07", detail: "Raw log.", artifact: "document:logs/r1/c1.json"}] =
               p1.evidence
    end

    test "--depth truncates and marks the cut" do
      tree = build!(depth: 1)
      [c1 | _] = tree.root.children
      assert c1.truncated
      assert c1.children == []
    end

    test "circular references terminate as marked leaves" do
      loop =
        [
          %{
            "id" => "g:a",
            "type" => "compound",
            "claim" => "a",
            "deps" => ["g:b"],
            "status" => "active"
          },
          %{
            "id" => "g:b",
            "type" => "compound",
            "claim" => "b",
            "deps" => ["g:a"],
            "status" => "active"
          }
        ]
        |> Enum.map(&Belief.from_map/1)

      {:ok, tree} = Audit.build("g:a", loop, [])
      [b] = tree.root.children
      [a_again] = b.children
      assert a_again.role == :circular
    end

    test "meta records the union, digest, renderer, and explicit date only" do
      tree = build!()
      assert tree.meta.namespaces == ["g", "x"]
      assert tree.meta.belief_count == 6
      assert String.starts_with?(tree.meta.digest, "sha256:")
      assert tree.meta.date == "2026-06-10"

      {:ok, dateless} = Audit.build("g:v1", union(), [])
      assert dateless.meta.date == nil
    end
  end

  describe "determinism and goldens" do
    test "re-render is byte-identical" do
      assert Audit.to_json(build!()) == Audit.to_json(build!())
      assert Audit.to_html(build!()) == Audit.to_html(build!())
    end

    test "JSON golden" do
      assert_golden(@golden_json, Audit.to_json(build!()))
    end

    test "HTML golden" do
      assert_golden(@golden_html, Audit.to_html(build!()))
    end

    test "HTML escapes claim text and links https artifacts" do
      html = Audit.to_html(build!())
      assert html =~ "Model &lt;m&gt; drops fields &amp; nobody notices."
      assert html =~ ~s(<a href="https://example.org/post">)
      refute html =~ "<m>"
    end
  end

  # Compare against the committed golden; regenerate with
  # GOLDEN_UPDATE=1 mix test test/cb/render/audit_test.exs
  defp assert_golden(path, content) do
    if System.get_env("GOLDEN_UPDATE") do
      File.write!(path, content)
    end

    assert File.read!(path) == content,
           "#{Path.basename(path)} differs - regenerate with GOLDEN_UPDATE=1 if the change is intended"
  end
end
