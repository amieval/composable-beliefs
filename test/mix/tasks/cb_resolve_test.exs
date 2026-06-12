defmodule Mix.Tasks.Cb.ResolveTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Cb.Resolve, as: Task

  describe "parse_rows/1" do
    test "object rows parse with optional nth defaulting to nil" do
      assert {:ok, [%{path: "lib/a.ex", anchor: "def go", nth: nil}]} =
               Task.parse_rows([%{"path" => "lib/a.ex", "anchor" => "def go"}])

      assert {:ok, [%{path: "lib/a.ex", anchor: "def go", nth: 2}]} =
               Task.parse_rows([%{"path" => "lib/a.ex", "anchor" => "def go", "nth" => 2}])
    end

    test "code: URI strings parse through the c043 grammar" do
      assert {:ok, [%{path: "lib/a.ex", anchor: "def go(", nth: 3}]} =
               Task.parse_rows(["code:lib/a.ex#def go(@3"])
    end

    test "object and URI rows mix in one file" do
      assert {:ok, [%{path: "lib/a.ex"}, %{path: "lib/b.ex"}]} =
               Task.parse_rows([
                 %{"path" => "lib/a.ex", "anchor" => "x"},
                 "code:lib/b.ex#y"
               ])
    end

    test "every invalid row is reported with its index" do
      assert {:error, messages} =
               Task.parse_rows([
                 %{"path" => "", "anchor" => "x"},
                 %{"path" => "lib/a.ex", "anchor" => ""},
                 %{"path" => "lib/a.ex", "anchor" => "x", "nth" => 0},
                 "code:lib/a.ex",
                 42
               ])

      assert length(messages) == 5
      assert Enum.at(messages, 0) =~ ~s(row 0: "path" must be a non-empty string)
      assert Enum.at(messages, 1) =~ ~s(row 1: "anchor" must be a non-empty string)
      assert Enum.at(messages, 2) =~ ~s(row 2: "nth" must be a positive integer)
      assert Enum.at(messages, 3) =~ "row 3: invalid code: URI (missing_anchor)"
      assert Enum.at(messages, 4) =~ "row 4: must be a code: URI string"
    end

    test "a non-array top level is rejected" do
      assert {:error, [message]} = Task.parse_rows(%{"path" => "lib/a.ex", "anchor" => "x"})
      assert message =~ "top level must be a JSON array"
    end
  end

  describe "render_text/1" do
    test "resolved, failed, and warning rows render with a summary" do
      results = [
        %{path: "lib/a.ex", anchor: "def go", nth: nil, line: 12, warnings: []},
        %{
          path: "lib/b.ex",
          anchor: "def render",
          nth: nil,
          line: 6,
          warnings: [~s(anchor "def render" matches 2 lines in lib/b.ex)]
        },
        %{path: "lib/c.ex", anchor: "gone", nth: 2, line: nil, warnings: ["not found"]}
      ]

      text = Task.render_text(results)

      assert text =~ ~s(ok    lib/a.ex:12  "def go")
      assert text =~ ~s(ok    lib/b.ex:6  "def render")
      assert text =~ ~s(! anchor "def render" matches 2 lines)
      assert text =~ ~s(FAIL  lib/c.ex  "gone"@2)
      assert text =~ "3 row(s): 2 resolved, 1 failed"
    end
  end
end
