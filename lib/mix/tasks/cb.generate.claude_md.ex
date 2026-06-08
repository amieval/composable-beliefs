defmodule Mix.Tasks.Cb.Generate.ClaudeMd do
  @moduledoc """
  Generate a CLAUDE.md from the DAG.

  Reads the active output-target contract tagged `output:claude-md` and
  renders its beliefs into the file declared by the contract's
  `output_path`, relative to `CB.repo_root/0`. The generated file is
  read-only; edits are overwritten on the next run.

  ## Usage

      mix cb.generate.claude_md          - generate the file
      mix cb.generate.claude_md --check  - diff against current; no write

  ## Exit codes

  0 = generated or check passed, 1 = errors or check failed

  ## Invariants

  - Every line of output traces to exactly one belief's claim field
  - Authoring happens by creating beliefs and by editing the
    output-target contract's render_sections
  - Hand-edits to the generated file are not preserved
  """
  @shortdoc "Generate a CLAUDE.md from the DAG"

  use Mix.Task

  alias CB.OutputTarget

  @tag "output:claude-md"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [check: :boolean])
    check? = opts[:check] || false

    root = CB.repo_root()

    with {:ok, [target | _] = targets, all} <- OutputTarget.find_targets(tag: @tag),
         :ok <- validate_single_target(targets),
         :ok <- OutputTarget.validate_deps_match_sections(target),
         {:ok, rel_path, content} <- OutputTarget.compile(target, all) do
      abs_path = Path.join(root, rel_path)

      if check? do
        run_check(abs_path, content)
      else
        ensure_dir(abs_path)
        File.write!(abs_path, content)

        IO.puts(:stderr, "Generated #{rel_path} from #{target.id}")
        IO.puts(:stderr, "  #{length(target.deps)} beliefs compiled, #{byte_size(content)} bytes")
      end
    else
      {:ok, [], _all} ->
        IO.puts(:stderr, "Error: no active output-target contract tagged `#{@tag}`")
        System.halt(1)

      {:error, {:missing_rule, key}} ->
        IO.puts(:stderr, "Error: output-target missing required rule `#{key}`")
        System.halt(1)

      {:error, {:deps_mismatch, missing, extra}} ->
        IO.puts(:stderr, "Error: deps do not match render_sections")
        if missing != [], do: IO.puts(:stderr, "  In sections but not deps: #{inspect(missing)}")
        if extra != [], do: IO.puts(:stderr, "  In deps but not sections: #{inspect(extra)}")
        System.halt(1)

      {:error, :multiple_targets} ->
        IO.puts(:stderr, "Error: multiple active contracts tagged `#{@tag}`. Expected one.")
        System.halt(1)

      {:error, reason} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp validate_single_target([_only]), do: :ok
  defp validate_single_target(_many), do: {:error, :multiple_targets}

  defp ensure_dir(abs_path) do
    abs_path |> Path.dirname() |> File.mkdir_p!()
  end

  defp run_check(abs_path, new_content) do
    case File.read(abs_path) do
      {:ok, current} when current == new_content ->
        IO.puts(:stderr, "CLAUDE.md is up to date")
        :ok

      {:ok, _current} ->
        IO.puts(:stderr, "CLAUDE.md is stale - run without --check to regenerate")
        System.halt(1)

      {:error, :enoent} ->
        IO.puts(:stderr, "CLAUDE.md does not exist - run without --check to generate")
        System.halt(1)

      {:error, reason} ->
        IO.puts(:stderr, "Error reading CLAUDE.md: #{inspect(reason)}")
        System.halt(1)
    end
  end
end
