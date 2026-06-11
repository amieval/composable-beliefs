defmodule CB.Belief.Filter do
  @moduledoc """
  Parses CLI filter arguments and applies them to belief lists.
  """

  def parse_args(args) do
    {flags, positional} = extract_flags(args)

    {filters, opts} =
      Enum.reduce(positional, {[], []}, fn arg, {filters, opts} ->
        cond do
          # Structural type filter
          arg in ~w(primitive compound inference directive) ->
            {[(&(&1.type == arg)) | filters], opts}

          # Status filter
          arg in ~w(active superseded retracted retired) ->
            {[(&(&1.status == arg)) | filters], [{:status_override, true} | opts]}

          arg == "all" ->
            {filters, [{:status_override, true} | opts]}

          arg == "stale" ->
            {filters, [{:stale, true} | opts]}

          arg == "contracts" ->
            {[(&CB.Belief.contract?/1) | filters], opts}

          arg == "unlinked" ->
            {[(&(&1.type == "directive" and &1.materialized == nil)) | filters], opts}

          # Tag filter: --tag <tag> or tag:<tag>
          String.starts_with?(arg, "tag:") ->
            tag = String.replace_prefix(arg, "tag:", "")
            {[(&(tag in (&1.tags || []))) | filters], opts}

          # Kind filter: kind:<kind>
          String.starts_with?(arg, "kind:") ->
            k = String.replace_prefix(arg, "kind:", "")
            {[(&(&1.kind == k)) | filters], opts}

          # Domain filter: domain:<domain>
          String.starts_with?(arg, "domain:") ->
            d = String.replace_prefix(arg, "domain:", "")
            {[(&(&1.domain == d)) | filters], opts}

          String.starts_with?(arg, "subject_type:") ->
            st = String.replace_prefix(arg, "subject_type:", "")
            {[(&Enum.any?(&1.subjects || [], fn s -> s["type"] == st end)) | filters], opts}

          String.contains?(arg, "/") ->
            {[(&Enum.any?(&1.subjects || [], fn s -> s["ref"] == arg end)) | filters], opts}

          true ->
            {filters, [{:unknown, arg} | opts]}
        end
      end)

    # Handle --tag flag from extract_flags
    filters =
      Enum.reduce(Keyword.get_values(flags, :tag), filters, fn tag, acc ->
        [(&(tag in (&1.tags || []))) | acc]
      end)

    flags = Keyword.delete(flags, :tag)

    filters =
      if Keyword.has_key?(opts, :status_override) do
        filters
      else
        [(&(&1.status == "active")) | filters]
      end

    merged_opts = Keyword.merge(flags, opts)
    {Enum.reverse(filters), merged_opts}
  end

  def apply_filters(beliefs, filters) do
    Enum.filter(beliefs, fn a ->
      Enum.all?(filters, fn f -> f.(a) end)
    end)
  end

  def sort(beliefs) do
    type_order = %{"primitive" => 0, "compound" => 1, "inference" => 2, "directive" => 3}

    Enum.sort_by(beliefs, fn a ->
      {Map.get(type_order, a.type, 3), a.id}
    end)
  end

  defp extract_flags(args) do
    extract_flags(args, [], [])
  end

  defp extract_flags([], flags, rest), do: {flags, rest}

  defp extract_flags([arg | tail], flags, rest) when arg in ~w(-v --verbose) do
    extract_flags(tail, [{:verbose, true} | flags], rest)
  end

  defp extract_flags(["--tag", tag | tail], flags, rest) do
    extract_flags(tail, [{:tag, tag} | flags], rest)
  end

  defp extract_flags([arg | tail], flags, rest) do
    extract_flags(tail, flags, rest ++ [arg])
  end
end
