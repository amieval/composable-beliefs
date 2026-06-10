defmodule CB.CodepathTest do
  use ExUnit.Case, async: true

  alias CB.Belief
  alias CB.Codepath

  @moduletag :tmp_dir

  defp b(fields), do: struct(Belief, Map.merge(%{status: "active", deps: []}, Map.new(fields)))

  defp write_source(dir) do
    File.mkdir_p!(Path.join(dir, "lib"))

    File.write!(Path.join(dir, "lib/pipe.ex"), """
    defmodule Pipe do
      def read do
        :data
      end

      def render do
        :out
      end

      def render_all, do: :out
    end
    """)
  end

  defp claim_belief(id, anchor, claim) do
    b(
      id: id,
      type: "primitive",
      kind: "fact",
      claim: claim,
      artifact: "code:lib/pipe.ex##{anchor}"
    )
  end

  defp target(steps, deps, entry \\ "start") do
    b(
      id: "x:c001",
      type: "implication",
      kind: "output-target",
      contract: true,
      tags: ["output:codepath"],
      deps: deps,
      rules: [%{"entry" => entry}, %{"render_steps" => steps}]
    )
  end

  defp fixture do
    beliefs = [
      claim_belief("x:a001", "def read do", "Reads the data."),
      claim_belief("x:a002", "def render do", "Renders it."),
      claim_belief("x:a003", "defmodule Pipe do", "The module under tour.")
    ]

    steps = [
      %{
        "id" => "start",
        "belief" => "x:a003",
        "choices" => [
          %{"label" => "How is data read?", "goto" => "read"},
          %{"label" => "How is it rendered?", "goto" => "render"}
        ]
      },
      %{"id" => "read", "belief" => "x:a001", "goto" => "render"},
      %{"id" => "render", "belief" => "x:a002"}
    ]

    {beliefs, target(steps, ["x:a003", "x:a001", "x:a002"])}
  end

  test "resolves stops in deterministic depth-first order with re-convergence visited once",
       %{tmp_dir: dir} do
    write_source(dir)
    {beliefs, target} = fixture()

    assert {:ok, resolved} = Codepath.resolve(target, beliefs ++ [target], root: dir)
    assert resolved.entry == "start"
    # start -> (choice) read -> (goto) render; the second choice re-converges on
    # the already-visited render step.
    assert Enum.map(resolved.stops, & &1.step) == ["start", "read", "render"]
    assert Enum.all?(resolved.stops, &(&1.warnings == []))

    [start, read, render] = resolved.stops
    assert start.line == 1
    assert read.line == 2
    assert render.line == 6
    assert [%{label: "How is data read?", goto: "read"} | _] = start.choices
  end

  test "resolution is stable across calls", %{tmp_dir: dir} do
    write_source(dir)
    {beliefs, target} = fixture()
    all = beliefs ++ [target]

    assert Codepath.resolve(target, all, root: dir) == Codepath.resolve(target, all, root: dir)
  end

  test "a deleted anchor warns and continues with line: nil", %{tmp_dir: dir} do
    write_source(dir)
    beliefs = [claim_belief("x:a001", "def vanished do", "Gone.")]
    target = target([%{"id" => "start", "belief" => "x:a001"}], ["x:a001"])

    assert {:ok, %{stops: [stop]}} = Codepath.resolve(target, beliefs ++ [target], root: dir)
    assert stop.line == nil
    assert [warning] = stop.warnings
    assert warning =~ "not found"
    assert warning =~ "start"
  end

  test "moving anchored code re-resolves the line", %{tmp_dir: dir} do
    write_source(dir)
    beliefs = [claim_belief("x:a001", "def render do", "Renders it.")]
    target = target([%{"id" => "start", "belief" => "x:a001"}], ["x:a001"])
    all = beliefs ++ [target]

    assert {:ok, %{stops: [%{line: 6}]}} = Codepath.resolve(target, all, root: dir)

    src = File.read!(Path.join(dir, "lib/pipe.ex"))
    File.write!(Path.join(dir, "lib/pipe.ex"), "# moved\n# down\n" <> src)

    assert {:ok, %{stops: [%{line: 8, warnings: []}]}} = Codepath.resolve(target, all, root: dir)
  end

  test "a loose anchor renders the first match and warns with the count", %{tmp_dir: dir} do
    write_source(dir)
    beliefs = [claim_belief("x:a001", "def render", "Loose.")]
    target = target([%{"id" => "start", "belief" => "x:a001"}], ["x:a001"])

    assert {:ok, %{stops: [stop]}} = Codepath.resolve(target, beliefs ++ [target], root: dir)
    assert stop.line == 6
    assert [warning] = stop.warnings
    assert warning =~ "matches 2 lines"
    assert warning =~ "tighten"
  end

  test "an explicit @N selects the Nth match without a warning, and warns out of range",
       %{tmp_dir: dir} do
    write_source(dir)
    beliefs = [claim_belief("x:a001", "def render@2", "Second.")]
    target = target([%{"id" => "start", "belief" => "x:a001"}], ["x:a001"])

    assert {:ok, %{stops: [%{line: 10, warnings: []}]}} =
             Codepath.resolve(target, beliefs ++ [target], root: dir)

    beliefs = [claim_belief("x:a001", "def render@9", "Too far.")]
    target = target([%{"id" => "start", "belief" => "x:a001"}], ["x:a001"])

    assert {:ok, %{stops: [stop]}} = Codepath.resolve(target, beliefs ++ [target], root: dir)
    assert stop.line == nil
    assert hd(stop.warnings) =~ "only 2 match(es)"
  end

  test "an invalid target returns the validation errors", %{tmp_dir: dir} do
    write_source(dir)
    {beliefs, target} = fixture()
    broken = %{target | deps: []}

    assert {:error, errors} = Codepath.resolve(broken, beliefs ++ [broken], root: dir)
    assert Enum.any?(errors, &(&1 =~ "deps"))
  end

  test "find_target resolves bare and namespaced ids" do
    {beliefs, target} = fixture()
    all = beliefs ++ [target]

    assert {:ok, %{id: "x:c001"}} = Codepath.find_target(all, "x:c001")
    assert {:ok, %{id: "x:c001"}} = Codepath.find_target(all, "c001")
    assert {:error, :not_found} = Codepath.find_target(all, "c999")
  end

  test "the shipped belief-pipeline codepath resolves against this repo with no warnings" do
    # The seed collection anchors this repo's own source; a warning here
    # means an anchor rotted and the codepath needs maintenance.
    path = Path.join(CB.repo_root(), "codepath/beliefs.json")

    if File.exists?(path) do
      {:ok, data} = CB.JSON.read(path)
      beliefs = Enum.map(data, &CB.Belief.from_map/1)

      assert [target] = Codepath.targets(beliefs)

      assert {:ok, resolved} = Codepath.resolve(target, beliefs, root: CB.repo_root())
      assert Enum.map(resolved.stops, & &1.step) == ["data", "from-map", "store", "formatter"]

      for stop <- resolved.stops do
        assert stop.warnings == [], "anchor rot: #{inspect(stop.warnings)}"
        assert is_integer(stop.line)
      end
    end
  end
end
