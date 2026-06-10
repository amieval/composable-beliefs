defmodule CB.CodeLocatorTest do
  use ExUnit.Case, async: true

  alias CB.CodeLocator

  test "parses a plain path + anchor" do
    assert {:ok, %{path: "lib/cb/belief.ex", anchor: "def from_map(", nth: nil}} =
             CodeLocator.parse("code:lib/cb/belief.ex#def from_map(")
  end

  test "anchor is opaque - spaces, colons, quotes, and further '#' stay literal" do
    assert {:ok, %{path: "lib/a.ex", anchor: ~s(field: "x" # note), nth: nil}} =
             CodeLocator.parse(~s(code:lib/a.ex#field: "x" # note))
  end

  test "trailing @N selects the Nth match" do
    assert {:ok, %{path: "lib/a.ex", anchor: "def read", nth: 3}} =
             CodeLocator.parse("code:lib/a.ex#def read@3")
  end

  test "a literal trailing @<digits> is percent-encoded as %40<digits>" do
    assert {:ok, %{anchor: "user@2", nth: nil}} = CodeLocator.parse("code:lib/a.ex#user%402")
  end

  test "occurrence selector composes with an encoded literal suffix" do
    assert {:ok, %{anchor: "user@2", nth: 3}} = CodeLocator.parse("code:lib/a.ex#user%402@3")
  end

  test "non-trailing %40 stays literal" do
    assert {:ok, %{anchor: "a%40b", nth: nil}} = CodeLocator.parse("code:lib/a.ex#a%40b")
  end

  test "@<non-digits> is part of the literal anchor, no encoding needed" do
    assert {:ok, %{anchor: "name@example", nth: nil}} =
             CodeLocator.parse("code:lib/a.ex#name@example")
  end

  test "rejects a whole-file reference (no anchor) - that is document:'s job" do
    assert {:error, :missing_anchor} = CodeLocator.parse("code:lib/cb/belief.ex")
  end

  test "rejects empty path, empty anchor, and zero occurrence" do
    assert {:error, :empty_path} = CodeLocator.parse("code:#anchor")
    assert {:error, :empty_anchor} = CodeLocator.parse("code:lib/a.ex#")
    assert {:error, :empty_anchor} = CodeLocator.parse("code:lib/a.ex#@2")
    assert {:error, :zero_occurrence} = CodeLocator.parse("code:lib/a.ex#def read@0")
  end

  test "rejects non-code schemes" do
    assert {:error, :not_code_scheme} = CodeLocator.parse("document:lib/cb/belief.ex")
  end

  test "valid?/1 mirrors parse/1" do
    assert CodeLocator.valid?("code:lib/cb/belief.ex#def from_map(")
    refute CodeLocator.valid?("code:lib/cb/belief.ex")
    refute CodeLocator.valid?("document:lib/cb/belief.ex")
    refute CodeLocator.valid?(nil)
  end
end
