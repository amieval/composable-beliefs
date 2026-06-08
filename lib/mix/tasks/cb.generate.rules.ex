defmodule Mix.Tasks.Cb.Generate.Rules do
  @moduledoc """
  Generate scoped rule files from the DAG.

  Reads all active output-target contracts tagged `output:rule` and
  renders each into its declared `output_path` (relative to
  `CB.repo_root/0`). Each rule file has frontmatter `paths:` that scopes
  when an agent loads it.

  ## Usage

      mix cb.generate.rules          - regenerate all rule files
      mix cb.generate.rules --check  - diff against current; no write

  ## Exit codes

  0 = all generated or check passed, 1 = errors or check failed

  ## Invariants

  - Every line in every rule file traces to exactly one belief's claim
  - The rule file's `paths:` frontmatter comes from the contract's rules
  - Hand-edits are not preserved
  """
  @shortdoc "Generate all scoped rule files from the DAG"

  use Mix.Task

  alias CB.OutputTarget

  @tag "output:rule"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [check: :boolean])
    check? = opts[:check] || false

    root = CB.repo_root()

    with {:ok, targets, all} <- OutputTarget.find_targets(tag: @tag) do
      if targets == [] do
        IO.puts(:stderr, "No active output-target contracts tagged `#{@tag}`. Nothing to do.")
      else
        results =
          Enum.map(targets, fn target ->
            compile_one(target, all, root, check?)
          end)

        errors = Enum.filter(results, fn {status, _} -> status == :error end)

        if errors == [] do
          IO.puts(:stderr, "\n#{length(targets)} rule file(s) processed successfully")
        else
          IO.puts(:stderr, "\n#{length(errors)} error(s) encountered")
          System.halt(1)
        end
      end
    else
      {:error, reason} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp compile_one(target, all, root, check?) do
    with :ok <- OutputTarget.validate_deps_match_sections(target),
         {:ok, rel_path, content} <- OutputTarget.compile(target, all) do
      abs_path = Path.join(root, rel_path)

      if check? do
        check_file(abs_path, content, target.id)
      else
        ensure_dir(abs_path)
        File.write!(abs_path, content)

        IO.puts(
          :stderr,
          "Generated #{rel_path} from #{target.id} (#{length(target.deps)} beliefs)"
        )

        {:ok, target.id}
      end
    else
      {:error, {:deps_mismatch, missing, extra}} ->
        IO.puts(:stderr, "#{target.id}: deps do not match render_sections")
        if missing != [], do: IO.puts(:stderr, "  In sections but not deps: #{inspect(missing)}")
        if extra != [], do: IO.puts(:stderr, "  In deps but not sections: #{inspect(extra)}")
        {:error, target.id}

      {:error, {:missing_rule, key}} ->
        IO.puts(:stderr, "#{target.id}: missing required rule `#{key}`")
        {:error, target.id}

      {:error, reason} ->
        IO.puts(:stderr, "#{target.id}: #{inspect(reason)}")
        {:error, target.id}
    end
  end

  defp ensure_dir(abs_path) do
    abs_path |> Path.dirname() |> File.mkdir_p!()
  end

  defp check_file(abs_path, new_content, target_id) do
    case File.read(abs_path) do
      {:ok, current} when current == new_content ->
        IO.puts(:stderr, "#{target_id}: up to date")
        {:ok, target_id}

      {:ok, _current} ->
        IO.puts(:stderr, "#{target_id}: STALE - rerun without --check to regenerate")
        {:error, target_id}

      {:error, :enoent} ->
        IO.puts(:stderr, "#{target_id}: does not exist - rerun without --check to generate")
        {:error, target_id}

      {:error, reason} ->
        IO.puts(:stderr, "#{target_id}: error reading file: #{inspect(reason)}")
        {:error, target_id}
    end
  end
end
