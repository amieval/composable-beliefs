defmodule CB.AnchorTest do
  use ExUnit.Case, async: true

  alias CB.Anchor

  @moduletag :tmp_dir

  setup %{tmp_dir: dir} do
    File.write!(Path.join(dir, "sample.ex"), """
    defmodule Sample do
      def read do
        :data
      end

      def render do
        :out
      end

      def render_all, do: :out
    end
    """)

    {:ok, root: dir}
  end

  defp row(anchor, nth \\ nil), do: %{path: "sample.ex", anchor: anchor, nth: nth}

  test "a unique anchor resolves to its line with no warnings", %{root: root} do
    assert {2, []} = Anchor.resolve(root, row("def read do"))
  end

  test "a missing anchor yields nil plus a not-found warning", %{root: root} do
    assert {nil, [warning]} = Anchor.resolve(root, row("def vanish do"))
    assert warning =~ ~s(anchor "def vanish do" not found in sample.ex)
  end

  test "a missing file yields nil plus a cannot-read warning", %{root: root} do
    assert {nil, [warning]} = Anchor.resolve(root, %{path: "gone.ex", anchor: "x", nth: nil})
    assert warning =~ "cannot read gone.ex"
  end

  test "multiple matches without nth resolve to the first plus a tighten warning",
       %{root: root} do
    assert {6, [warning]} = Anchor.resolve(root, row("def render"))
    assert warning =~ ~s(anchor "def render" matches 2 lines in sample.ex)
  end

  test "an explicit in-range nth selects silently", %{root: root} do
    assert {10, []} = Anchor.resolve(root, row("def render", 2))
  end

  test "an out-of-range nth yields nil plus a count warning", %{root: root} do
    assert {nil, [warning]} = Anchor.resolve(root, row("def render", 3))
    assert warning =~ ~s{anchor "def render"@3 requested but only 2 match(es) in sample.ex}
  end
end
