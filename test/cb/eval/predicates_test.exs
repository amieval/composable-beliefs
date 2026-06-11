defmodule CB.Eval.PredicatesTest do
  use ExUnit.Case, async: true

  alias CB.Belief
  alias CB.Eval.Predicates

  # --- fixture builders ---

  defp belief(map) do
    map
    |> Map.put_new("status", "active")
    |> Belief.from_map()
  end

  defp observation(id, run, ruler, attrs \\ %{}) do
    belief(
      Map.merge(
        %{
          "id" => id,
          "type" => "primitive",
          "kind" => "observation",
          "tags" => ["aggregate"],
          "artifact" => "eval:e1/#{run}/#{ruler}",
          "evidence" => [
            %{
              "date" => "2026-06-09",
              "detail" => "fixture",
              "artifact" => "document:logs/#{run}.eval"
            }
          ],
          "subjects" => [
            %{"ref" => "eval/e1", "type" => "eval"},
            %{"ref" => "run/#{run}", "type" => "run"},
            %{"ref" => "model/m", "type" => "model"},
            %{"ref" => "model-version/m@1", "type" => "model_version"},
            %{"ref" => "ruler/#{ruler}", "type" => "ruler"}
          ]
        },
        attrs
      )
    )
  end

  defp agreement(id, deps) do
    belief(%{
      "id" => id,
      "type" => "compound",
      "kind" => "observation",
      "tags" => ["cross-ruler-agreement"],
      "deps" => deps
    })
  end

  defp verdict(id, deps, attrs \\ %{}) do
    belief(
      Map.merge(
        %{"id" => id, "type" => "inference", "kind" => "verdict", "deps" => deps},
        attrs
      )
    )
  end

  # A fully compliant miniature: 3 runs x 2 rulers (one LLM judge with a
  # validation record), agreement compound, corroborated verdict.
  defp compliant do
    obs =
      for run <- ~w(r1 r2 r3), ruler <- ~w(det llm-judge-basic) do
        observation("t:#{run}-#{ruler}", run, ruler)
      end

    validation =
      belief(%{
        "id" => "t:val",
        "type" => "primitive",
        "kind" => "protocol",
        "tags" => ["judge-validation"],
        "subjects" => [
          %{"ref" => "eval/e1", "type" => "eval"},
          %{"ref" => "ruler/llm-judge-basic", "type" => "ruler"}
        ]
      })

    agreement = agreement("t:agree", Enum.map(obs, & &1.id))
    verdict = verdict("t:verdict", ["t:agree"])

    obs ++ [validation, agreement, verdict]
  end

  # --- resolve / invoke gate ---

  describe "resolve/2 and invoke/4" do
    test "refuses names violating the inspection-only invariant" do
      assert {:error, :bad_name} = Predicates.resolve("delete_everything")
      assert {"fail", detail} = Predicates.invoke("delete_everything", [], %{})
      assert detail =~ "inspection-only"
    end

    test "refuses unknown predicates" do
      assert {:error, :unknown_predicate} = Predicates.resolve("not_a_real_one?")
      assert {"fail", detail} = Predicates.invoke("not_a_real_one?", [], %{})
      assert detail =~ "no exported arity-2 predicate"
    end

    test "refuses zero-arity functions at the wrong arity" do
      # module_info/0 exists but not at arity 2; also fails the name gate first.
      assert {:error, :bad_name} = Predicates.resolve("module_info")
    end

    test "nil predicate fails without crashing" do
      assert {"fail", "no predicate named"} = Predicates.invoke(nil, [], %{})
    end

    test "a raising predicate normalizes to fail-with-detail" do
      defmodule Raiser do
        def boom?(_beliefs, _params), do: raise("kapow")
      end

      assert {"fail", detail} = Predicates.invoke(Raiser, "boom?", [], %{})
      assert detail =~ "kapow"
    end

    test "non-boolean returns normalize to fail-with-detail" do
      defmodule NonBool do
        def odd?(_beliefs, _params), do: :maybe
      end

      assert {"fail", detail} = Predicates.invoke(NonBool, "odd?", [], %{})
      assert detail =~ "non-boolean"
    end

    test "true passes and {false, detail} carries the detail through" do
      defmodule Verdicts do
        def yes?(_b, _p), do: true
        def no?(_b, _p), do: {false, "t:x is the problem"}
      end

      assert {"pass", nil} = Predicates.invoke(Verdicts, "yes?", [], %{})
      assert {"fail", "t:x is the problem"} = Predicates.invoke(Verdicts, "no?", [], %{})
    end
  end

  # --- the v1 library ---

  describe "verdicts_corroborated?/2" do
    test "passes when every verdict reaches an agreement compound" do
      assert Predicates.verdicts_corroborated?(compliant(), %{}) == true
    end

    test "passes a verdict carrying the single-ruler escape tag" do
      beliefs = [
        observation("t:o", "r1", "det"),
        verdict("t:v", ["t:o"], %{"tags" => ["single-ruler"]})
      ]

      assert Predicates.verdicts_corroborated?(beliefs, %{}) == true
    end

    test "fails an uncorroborated verdict, naming it" do
      beliefs = [observation("t:o", "r1", "det"), verdict("t:v", ["t:o"])]
      assert {false, detail} = Predicates.verdicts_corroborated?(beliefs, %{})
      assert detail =~ "t:v"
    end

    test "a superseded agreement compound does not corroborate" do
      beliefs = [
        observation("t:o", "r1", "det"),
        belief(%{
          "id" => "t:agree",
          "type" => "compound",
          "kind" => "observation",
          "tags" => ["cross-ruler-agreement"],
          "deps" => ["t:o"],
          "status" => "superseded",
          "superseded_by" => "t:agree2"
        }),
        verdict("t:v", ["t:agree"])
      ]

      assert {false, detail} = Predicates.verdicts_corroborated?(beliefs, %{})
      assert detail =~ "t:v"
    end
  end

  describe "observations_cite_runlogs?/2" do
    test "passes observations with eval: artifact and a raw-log evidence artifact" do
      assert Predicates.observations_cite_runlogs?(compliant(), %{}) == true
    end

    test "fails an observation without an eval: artifact" do
      beliefs = [observation("t:o", "r1", "det", %{"artifact" => "document:not-an-eval"})]
      assert {false, detail} = Predicates.observations_cite_runlogs?(beliefs, %{})
      assert detail =~ "t:o"
    end

    test "fails an observation whose evidence has no document:/https: artifact" do
      beliefs = [
        observation("t:o", "r1", "det", %{
          "evidence" => [%{"date" => "2026-06-09", "detail" => "no pointer"}]
        })
      ]

      assert {false, detail} = Predicates.observations_cite_runlogs?(beliefs, %{})
      assert detail =~ "t:o"
    end

    test "ignores superseded observations and non-observations" do
      beliefs = [
        observation("t:o", "r1", "det", %{
          "artifact" => "document:x",
          "status" => "superseded",
          "superseded_by" => "t:o2"
        }),
        belief(%{"id" => "t:c", "type" => "primitive", "kind" => "convention"})
      ]

      assert Predicates.observations_cite_runlogs?(beliefs, %{}) == true
    end
  end

  describe "observation_subjects_complete?/2" do
    test "passes aggregates without case and per-case observations with case" do
      per_case =
        observation("t:pc", "r1", "det", %{
          "tags" => [],
          "subjects" => [
            %{"ref" => "eval/e1", "type" => "eval"},
            %{"ref" => "run/r1", "type" => "run"},
            %{"ref" => "case/c7", "type" => "case"},
            %{"ref" => "model/m", "type" => "model"},
            %{"ref" => "model-version/m@1", "type" => "model_version"},
            %{"ref" => "ruler/det", "type" => "ruler"}
          ]
        })

      assert Predicates.observation_subjects_complete?(compliant() ++ [per_case], %{}) == true
    end

    test "fails a non-aggregate observation missing case, naming the gap" do
      beliefs = [observation("t:o", "r1", "det", %{"tags" => []})]
      assert {false, detail} = Predicates.observation_subjects_complete?(beliefs, %{})
      assert detail =~ "t:o"
      assert detail =~ "case"
    end

    test "fails an observation missing core subjects" do
      beliefs = [
        observation("t:o", "r1", "det", %{"subjects" => [%{"ref" => "eval/e1", "type" => "eval"}]})
      ]

      assert {false, detail} = Predicates.observation_subjects_complete?(beliefs, %{})
      assert detail =~ "ruler"
      assert detail =~ "model_version"
    end
  end

  describe "min_runs_met?/2" do
    test "passes a verdict reaching min distinct runs through its closure" do
      assert Predicates.min_runs_met?(compliant(), %{"min" => 3}) == true
    end

    test "fails a verdict short of the minimum, counting its runs" do
      beliefs = [
        observation("t:o", "r1", "det"),
        agreement("t:agree", ["t:o"]),
        verdict("t:v", ["t:agree"])
      ]

      assert {false, detail} = Predicates.min_runs_met?(beliefs, %{"min" => 3})
      assert detail =~ "t:v"
      assert detail =~ "1 run(s)"
    end

    test "rejects missing or invalid params as untrusted shape" do
      assert {false, detail} = Predicates.min_runs_met?(compliant(), %{})
      assert detail =~ "params.min"

      assert {false, _} = Predicates.min_runs_met?(compliant(), %{"min" => "3"})
      assert {false, _} = Predicates.min_runs_met?(compliant(), %{"min" => 0})
    end
  end

  describe "llm_judges_validated?/2" do
    test "passes when the judge has a validation record for the eval" do
      assert Predicates.llm_judges_validated?(compliant(), %{}) == true
    end

    test "fails an unvalidated LLM-judge observation, naming the pair" do
      beliefs = [observation("t:o", "r1", "llm-judge-vanilla")]
      assert {false, detail} = Predicates.llm_judges_validated?(beliefs, %{})
      assert detail =~ "t:o"
      assert detail =~ "ruler/llm-judge-vanilla"
    end

    test "a validation record for a different eval does not count" do
      beliefs = [
        observation("t:o", "r1", "llm-judge-basic"),
        belief(%{
          "id" => "t:val",
          "type" => "primitive",
          "kind" => "protocol",
          "tags" => ["judge-validation"],
          "subjects" => [
            %{"ref" => "eval/other-eval", "type" => "eval"},
            %{"ref" => "ruler/llm-judge-basic", "type" => "ruler"}
          ]
        })
      ]

      assert {false, _} = Predicates.llm_judges_validated?(beliefs, %{})
    end

    test "non-judge rulers need no validation" do
      assert Predicates.llm_judges_validated?([observation("t:o", "r1", "det")], %{}) == true
    end
  end

  describe "corrections_are_supersessions?/2" do
    test "passes a correction that supersedes with dated evidence" do
      beliefs = [
        verdict("t:v1", ["t:x"], %{"status" => "superseded", "superseded_by" => "t:v2"}),
        verdict("t:v2", ["t:x"], %{
          "tags" => ["correction"],
          "evidence" => [%{"date" => "2026-06-09", "detail" => "corrected"}]
        })
      ]

      assert Predicates.corrections_are_supersessions?(beliefs, %{}) == true
    end

    test "fails a correction tag on a belief that supersedes nothing" do
      beliefs = [
        verdict("t:v", ["t:x"], %{
          "tags" => ["correction"],
          "evidence" => [%{"date" => "2026-06-09", "detail" => "d"}]
        })
      ]

      assert {false, detail} = Predicates.corrections_are_supersessions?(beliefs, %{})
      assert detail =~ "t:v"
    end

    test "fails a correction without dated evidence" do
      beliefs = [
        verdict("t:v1", ["t:x"], %{"status" => "superseded", "superseded_by" => "t:v2"}),
        verdict("t:v2", ["t:x"], %{"tags" => ["correction"]})
      ]

      assert {false, detail} = Predicates.corrections_are_supersessions?(beliefs, %{})
      assert detail =~ "t:v2"
    end

    test "fails a retraction without the withdrawn tag" do
      beliefs = [
        belief(%{
          "id" => "t:r",
          "type" => "primitive",
          "kind" => "observation",
          "status" => "retracted",
          "retracted_on" => "2026-06-09",
          "retracted_reason" => "fixture"
        })
      ]

      assert {false, detail} = Predicates.corrections_are_supersessions?(beliefs, %{})
      assert detail =~ "t:r"
      assert detail =~ "withdrawn"
    end

    test "passes a withdrawn retraction" do
      beliefs = [
        belief(%{
          "id" => "t:r",
          "type" => "primitive",
          "kind" => "observation",
          "tags" => ["withdrawn"],
          "status" => "retracted",
          "retracted_on" => "2026-06-09",
          "retracted_reason" => "fixture"
        })
      ]

      assert Predicates.corrections_are_supersessions?(beliefs, %{}) == true
    end
  end
end
