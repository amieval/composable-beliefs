defmodule Mix.Tasks.Cb.EvidenceTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Cb.Evidence, as: Task

  describe "validate_detail/1" do
    test "missing detail is an error" do
      assert {:error, _} = Task.validate_detail(nil)
    end

    test "blank detail is an error" do
      assert {:error, _} = Task.validate_detail("   ")
    end

    test "non-empty detail passes through" do
      assert {:ok, "noted"} = Task.validate_detail("noted")
    end
  end

  describe "validate_artifact/1" do
    test "missing artifact is an error" do
      assert {:error, _} = Task.validate_artifact(nil)
    end

    test "scheme:rest URIs pass" do
      assert {:ok, _} = Task.validate_artifact("document:plans/x.md")
      assert {:ok, _} = Task.validate_artifact("adjudication:human:slug-2026-06-12")
    end

    test "a bare path without a scheme is an error" do
      assert {:error, _} = Task.validate_artifact("plans/x.md")
    end

    test "a scheme with empty rest is an error" do
      assert {:error, _} = Task.validate_artifact("document:")
    end

    test "an uppercase scheme is an error" do
      assert {:error, _} = Task.validate_artifact("Document:x.md")
    end
  end

  describe "validate_date/1" do
    test "nil passes through - mutation defaults to today" do
      assert {:ok, nil} = Task.validate_date(nil)
    end

    test "a valid ISO date passes" do
      assert {:ok, "2026-06-12"} = Task.validate_date("2026-06-12")
    end

    test "a malformed date is an error" do
      assert {:error, _} = Task.validate_date("06/12/2026")
      assert {:error, _} = Task.validate_date("2026-13-01")
    end
  end
end
