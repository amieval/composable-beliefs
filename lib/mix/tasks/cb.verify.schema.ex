defmodule Mix.Tasks.Cb.Verify.Schema do
  @moduledoc """
  Verify a belief collection against the schema contracts it carries.

  Thin IO wrapper over `CB.Schema.Verifier` - see that module for the check
  semantics. In brief: framework-universal structure (types, the
  `contract: true` biconditional, the `c`-prefix convention, artifact format,
  status linkage) is checked against `CB.Belief`'s canon; collection-specific
  vocabulary (the `kind`, `domain`, and `artifact-scheme` enums and the status
  lifecycle) is *discovered* from the collection's own contracts by role. A
  field a collection declares no enum for is skipped, not failed.

  This generalizes the dogfooding the `cb:` graph relies on, so any collection
  (a belief-collection, or a host's own) verifies against its own schema.

  ## Usage

      mix cb.verify.schema                    - verify the default graph
      mix cb.verify.schema --beliefs PATH     - verify an alternate collection
      mix cb.verify.schema --quiet            - only print failures

  ## Exit codes

  0 = all pass (or skipped), 1 = one or more failures
  """
  @shortdoc "Verify a belief collection against the schema contracts it carries"

  use Mix.Task

  alias CB.Belief.Store, as: BeliefStore
  alias CB.Schema.Verifier

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [quiet: :boolean, beliefs: :string],
        aliases: [q: :quiet]
      )

    if path = opts[:beliefs], do: Application.put_env(:cb, :beliefs_path, path)
    quiet = opts[:quiet] || false

    with {:ok, all} <- BeliefStore.read() do
      results = Verifier.check(all)

      unless quiet do
        Enum.each(results, &print_result/1)
      end

      failures = Enum.count(results, fn {_, status, _} -> status == :fail end)
      passes = Enum.count(results, fn {_, status, _} -> status == :ok end)
      skipped = Enum.count(results, fn {_, status, _} -> status == :skip end)

      IO.puts("")

      IO.puts(
        "#{passes} passed, #{failures} failed, #{skipped} skipped (#{length(results)} checks)"
      )

      if failures > 0, do: System.halt(1)
    else
      {:error, reason} ->
        IO.puts(:stderr, "Error reading belief graph: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp print_result({name, :ok, detail}), do: IO.puts("  PASS  #{name} - #{detail}")

  defp print_result({name, :fail, detail}) do
    IO.puts("  FAIL  #{name}")
    IO.puts("        #{detail}")
  end

  defp print_result({name, :skip, detail}), do: IO.puts("  SKIP  #{name} - #{detail}")
end
