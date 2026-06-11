defmodule CB.Belief.EditPairs do
  @moduledoc """
  Query and format edit-pair beliefs for composition subagent prompts.

  Edit-pairs are primitive beliefs with `kind: "edit-pair"` that record
  agent-proposed text alongside user-edited sent text. Their derived
  implications capture communication patterns.

  This module extracts edit-pairs and their implications from the DAG
  and formats them for inclusion in composition subagent payloads.
  """

  alias CB.Config

  @doc """
  Load all edit-pairs and their implications from the belief graph.

  Returns `{:ok, %{edit_pairs: [...], implications: [...]}}`.
  """
  def load do
    path = Config.beliefs_path()

    with {:ok, content} <- File.read(path),
         {:ok, all} <- Jason.decode(content) do
      edit_pairs =
        all
        |> Enum.filter(&(&1["kind"] == "edit-pair"))
        |> Enum.filter(&(&1["status"] == "active"))

      ep_ids = MapSet.new(Enum.map(edit_pairs, & &1["id"]))

      implications =
        all
        |> Enum.filter(&(&1["type"] == "directive"))
        |> Enum.filter(&(&1["status"] == "active"))
        |> Enum.filter(fn a ->
          deps = a["deps"] || []
          Enum.any?(deps, &MapSet.member?(ep_ids, &1))
        end)

      {:ok, %{edit_pairs: edit_pairs, implications: implications}}
    end
  end

  @doc """
  Format edit-pairs and implications as a text block for subagent prompts.

  Returns a string suitable for inclusion in the composition subagent's
  context. Each edit-pair shows proposed vs sent text, and implications
  are listed as derived communication rules.
  """
  def format_for_prompt do
    case load() do
      {:ok, %{edit_pairs: eps, implications: imps}} when eps != [] ->
        ep_text =
          eps
          |> Enum.map(&format_edit_pair/1)
          |> Enum.join("\n\n")

        imp_text =
          imps
          |> Enum.sort_by(& &1["id"])
          |> Enum.map(&format_implication/1)
          |> Enum.join("\n")

        """
        STYLE EXAMPLES (from real edits by the user):

        #{ep_text}

        DERIVED COMMUNICATION RULES (from edit analysis):

        #{imp_text}
        """
        |> String.trim()

      _ ->
        nil
    end
  end

  defp format_edit_pair(ep) do
    name = ep["name"] || ep["id"]
    evidence = ep["evidence"] || []

    edits =
      evidence
      |> Enum.map(fn e ->
        proposed = e["proposed"] || ""
        sent = e["sent"] || ""
        section = e["section"] || "unknown"
        "  [#{section}]\n  PROPOSED: #{truncate(proposed, 120)}\n  SENT: #{truncate(sent, 120)}"
      end)
      |> Enum.join("\n")

    "--- #{name} ---\n#{edits}"
  end

  defp format_implication(imp) do
    id = imp["id"]
    text = imp["implication"] || imp["claim"]
    "- (#{id}) #{text}"
  end

  defp truncate(str, max) do
    str = String.replace(str, "\n", " ")

    if String.length(str) > max do
      String.slice(str, 0, max) <> "..."
    else
      str
    end
  end
end
