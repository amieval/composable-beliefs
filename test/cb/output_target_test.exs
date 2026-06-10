defmodule CB.OutputTargetTest do
  use ExUnit.Case, async: true

  alias CB.Belief
  alias CB.OutputTarget

  defp b(fields), do: struct(Belief, Map.merge(%{status: "active", deps: []}, Map.new(fields)))

  defp claim_belief(id, anchor \\ "def from_map(") do
    b(id: id, type: "primitive", kind: "fact", artifact: "code:lib/cb/belief.ex##{anchor}")
  end

  defp codepath_target(overrides \\ []) do
    defaults = [
      id: "x:c100",
      type: "implication",
      kind: "output-target",
      contract: true,
      tags: ["output:codepath"],
      deps: ["x:a001", "x:a002"],
      rules: [
        %{"entry" => "data"},
        %{
          "render_steps" => [
            %{
              "id" => "data",
              "belief" => "x:a001",
              "choices" => [%{"label" => "Onward?", "goto" => "next"}]
            },
            %{"id" => "next", "belief" => "x:a002", "goto" => "data"}
          ]
        }
      ]
    ]

    b(Keyword.merge(defaults, overrides))
  end

  defp beliefs, do: [claim_belief("x:a001"), claim_belief("x:a002", "def read")]

  describe "codepath_target?/1" do
    test "true for an active output-target tagged output:codepath" do
      assert OutputTarget.codepath_target?(codepath_target())
    end

    test "false for other output-targets, other kinds, and inactive targets" do
      refute OutputTarget.codepath_target?(codepath_target(tags: ["output:claude-md"]))
      refute OutputTarget.codepath_target?(codepath_target(kind: "schema"))
      refute OutputTarget.codepath_target?(codepath_target(status: "superseded"))
    end
  end

  describe "validate_codepath/2" do
    test "a well-formed codepath target validates" do
      assert :ok = OutputTarget.validate_codepath(codepath_target(), beliefs())
    end

    test "missing entry or steps fails" do
      target = codepath_target(rules: [%{"render_steps" => []}])
      assert {:error, errors} = OutputTarget.validate_codepath(target, beliefs())
      assert Enum.any?(errors, &(&1 =~ "entry"))
      assert Enum.any?(errors, &(&1 =~ "render_steps"))
    end

    test "entry must name a step id" do
      target = codepath_target(rules: put_entry(codepath_target().rules, "nope"))
      assert {:error, errors} = OutputTarget.validate_codepath(target, beliefs())
      assert Enum.any?(errors, &(&1 =~ "entry"))
    end

    test "goto and choice targets must name existing step ids" do
      rules = [
        %{"entry" => "data"},
        %{
          "render_steps" => [
            %{
              "id" => "data",
              "belief" => "x:a001",
              "goto" => "ghost",
              "choices" => [%{"label" => "?", "goto" => "phantom"}]
            }
          ]
        }
      ]

      target = codepath_target(rules: rules, deps: ["x:a001"])
      assert {:error, errors} = OutputTarget.validate_codepath(target, beliefs())
      assert Enum.any?(errors, &(&1 =~ "ghost"))
      assert Enum.any?(errors, &(&1 =~ "phantom"))
    end

    test "duplicate step ids fail" do
      rules = [
        %{"entry" => "data"},
        %{
          "render_steps" => [
            %{"id" => "data", "belief" => "x:a001"},
            %{"id" => "data", "belief" => "x:a002"}
          ]
        }
      ]

      target = codepath_target(rules: rules)
      assert {:error, errors} = OutputTarget.validate_codepath(target, beliefs())
      assert Enum.any?(errors, &(&1 =~ "duplicate step ids"))
    end

    test "referenced beliefs must exist and carry a valid code: artifact" do
      document_anchored =
        b(id: "x:a002", type: "primitive", kind: "fact", artifact: "document:lib/cb/belief.ex")

      assert {:error, errors} =
               OutputTarget.validate_codepath(codepath_target(), [
                 claim_belief("x:a001"),
                 document_anchored
               ])

      assert Enum.any?(errors, &(&1 =~ "x:a002"))

      assert {:error, errors} =
               OutputTarget.validate_codepath(codepath_target(), [claim_belief("x:a001")])

      assert Enum.any?(errors, &(&1 =~ "x:a002 not found"))
    end

    test "deps must equal the union of referenced belief ids" do
      target = codepath_target(deps: ["x:a001"])
      assert {:error, errors} = OutputTarget.validate_codepath(target, beliefs())
      assert Enum.any?(errors, &(&1 =~ "deps"))

      target = codepath_target(deps: ["x:a001", "x:a002", "x:a999"])
      assert {:error, errors} = OutputTarget.validate_codepath(target, beliefs())
      assert Enum.any?(errors, &(&1 =~ "x:a999"))
    end
  end

  defp put_entry(rules, entry) do
    Enum.map(rules, fn
      %{"entry" => _} -> %{"entry" => entry}
      other -> other
    end)
  end
end
