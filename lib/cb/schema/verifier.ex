defmodule CB.Schema.Verifier do
  @moduledoc """
  Verify a belief collection against the schema contracts it carries.

  The verifier is collection-agnostic. Two kinds of rule are checked:

  - **Framework-universal structure** - the four structural types, the
    `contract: true` biconditional, the `c`-prefix convention, the
    grounding rule (deps, or a stipulation artifact for directives),
    subject containment on compounds, artifact format, status linkage.
    These hold for any well-formed collection and are checked against
    `CB.Belief`'s own canon, not against ids.
  - **Collection-specific vocabulary** - the closed enums for `kind`,
    `domain`, and `artifact-scheme`, plus the status lifecycle. These are
    *discovered* from the collection's own contracts by role: an enum is
    found by the field it declares (via `CB.Belief.Contract.Enum`), the
    status lifecycle by a `status-lifecycle`-tagged state-machine contract
    (via `CB.Belief.Contract.StateMachine`). A collection that declares no
    enum for a field has that vocabulary check skipped; status falls back
    to `CB.Belief.statuses/0`.

  This is the same dogfooding the `cb:` graph relies on - its
  `cb:c029/c039/c040/c041` are discovered by role like any other contract -
  generalized so any belief-collection (or host graph) verifies
  against its own schema.

  `check/1` is pure: it takes the belief list and returns a list of
  `{name, status, detail}` where status is `:ok | :fail | :skip`. The
  `mix cb.verify.schema` task is a thin IO wrapper over it.
  """

  alias CB.Belief
  alias CB.Belief.Contract.Enum, as: EnumContract
  alias CB.Belief.Contract.StateMachine
  alias CB.Belief.Contract.Table

  @type status :: :ok | :fail | :skip
  @type result :: {String.t(), status(), String.t()}

  @doc "Run every schema check against `beliefs`. Pure - returns results."
  @spec check([Belief.t()]) :: [result()]
  def check(beliefs) do
    [
      check_schema_roles(beliefs),
      check_type_enum(beliefs),
      check_contract_requires_directive(beliefs),
      check_contract_biconditional(beliefs),
      check_kind_enum(beliefs),
      check_kind_type_table(beliefs),
      check_domain_enum(beliefs),
      check_artifact_format(beliefs),
      check_artifact_scheme_enum(beliefs),
      check_code_artifact_format(beliefs),
      check_codepath_targets(beliefs),
      check_no_implication_field(beliefs),
      check_action_item_shape(beliefs),
      check_grounding(beliefs),
      check_subject_containment(beliefs),
      check_retired_is_directive(beliefs),
      check_status_enum(beliefs),
      check_superseded_linkage(beliefs),
      check_retracted_linkage(beliefs),
      check_c_prefix_is_contract(beliefs)
    ]
  end

  # --- role discovery (no hardcoded ids) ---

  defp active_contracts(beliefs) do
    Enum.filter(beliefs, &(&1.status == "active" and &1.contract == true))
  end

  # The active enum-registry contract that declares `field`, or nil.
  defp enum_contract_for(beliefs, field) do
    beliefs
    |> active_contracts()
    |> Enum.filter(&(&1.kind == "enum-registry"))
    |> Enum.find(fn c -> field in EnumContract.fields(c) end)
  end

  # The active state-machine contract governing the belief status lifecycle,
  # identified by the `status-lifecycle` tag, or nil. (A collection may carry
  # other state machines - e.g. a domain entity's lifecycle - so the role is
  # marked by tag rather than inferred from kind alone.)
  defp status_lifecycle_contract(beliefs) do
    beliefs
    |> active_contracts()
    |> Enum.filter(&(&1.kind == "state-machine"))
    |> Enum.find(fn c -> "status-lifecycle" in (c.tags || []) end)
  end

  # --- schema roles present ---

  defp check_schema_roles(beliefs) do
    detail =
      "kind=#{role_id(enum_contract_for(beliefs, "kind"))}, " <>
        "domain=#{role_id(enum_contract_for(beliefs, "domain"))}, " <>
        "artifact-scheme=#{role_id(enum_contract_for(beliefs, "artifact-scheme"))}, " <>
        "status-lifecycle=#{role_id(status_lifecycle_contract(beliefs), "framework canon")}"

    {"schema roles discovered", :ok, detail}
  end

  defp role_id(contract, absent \\ "none")
  defp role_id(nil, absent), do: absent
  defp role_id(%{id: id}, _absent), do: id

  # --- type enum (framework-universal) ---

  defp check_type_enum(beliefs) do
    valid = Belief.types()
    bad = beliefs |> Enum.reject(&(&1.type in valid)) |> Enum.map(& &1.id)

    if bad == [] do
      {"type enum", :ok, "all nodes have type in #{inspect(valid)}"}
    else
      {"type enum", :fail, "nodes with invalid type: #{inspect(bad)}"}
    end
  end

  # --- contract structural rules (framework-universal) ---

  defp check_contract_requires_directive(beliefs) do
    violations =
      beliefs
      |> Enum.filter(&(&1.contract == true))
      |> Enum.reject(&(&1.type == "directive"))
      |> Enum.map(& &1.id)

    if violations == [] do
      {"contract requires directive", :ok, "all contract-grade beliefs are directives"}
    else
      {"contract requires directive", :fail,
       "contract: true on non-directive: #{inspect(violations)}"}
    end
  end

  # --- kind-type derivation table (discovered by columns) ---

  # The active derivation-table contract binding kinds to allowed types,
  # identified by its columns (kind + allowed_types), or nil. Mood becomes
  # a deterministic check only when a collection carries this table.
  defp kind_type_table(beliefs) do
    beliefs
    |> active_contracts()
    |> Enum.filter(&(&1.kind == "derivation-table"))
    |> Enum.find(fn c ->
      cols = Table.columns(c)
      "kind" in cols and "allowed_types" in cols
    end)
  end

  defp check_kind_type_table(beliefs) do
    case kind_type_table(beliefs) do
      nil ->
        {"kind-type table", :skip,
         "no active derivation-table contract binds kind to allowed_types"}

      table ->
        violations =
          beliefs
          |> Enum.filter(&(&1.status == "active" and not is_nil(&1.kind)))
          |> Enum.flat_map(fn b ->
            case Table.lookup(table, %{"kind" => b.kind}) do
              [] ->
                []

              rows ->
                allowed = Enum.flat_map(rows, &(&1["allowed_types"] || []))
                if b.type in allowed, do: [], else: [{b.id, b.kind, b.type}]
            end
          end)

        if violations == [] do
          {"kind-type table", :ok,
           "all active beliefs with table-bound kinds use an allowed type (#{table.id})"}
        else
          {"kind-type table", :fail,
           "kind/type violations per #{table.id}: #{inspect(violations)}"}
        end
    end
  end

  defp check_contract_biconditional(beliefs) do
    # contract: true iff (rules non-empty OR invariants non-empty)
    violations =
      beliefs
      |> Enum.filter(fn a ->
        has_payload =
          (is_list(a.rules) and a.rules != []) or (is_list(a.invariants) and a.invariants != [])

        has_payload != (a.contract == true)
      end)
      |> Enum.map(& &1.id)

    if violations == [] do
      {"contract biconditional", :ok, "contract: true iff rules/invariants non-empty"}
    else
      {"contract biconditional", :fail, "contract/payload mismatch: #{inspect(violations)}"}
    end
  end

  # --- kind / domain enums (discovered by field) ---

  defp check_kind_enum(beliefs), do: check_field_enum(beliefs, "kind", & &1.kind)
  defp check_domain_enum(beliefs), do: check_field_enum(beliefs, "domain", & &1.domain)

  defp check_field_enum(beliefs, field, getter) do
    case enum_contract_for(beliefs, field) do
      nil ->
        {"#{field} enum", :skip, "no active enum-registry contract declares #{field}"}

      contract ->
        allowed = MapSet.new(EnumContract.values_for(contract, field))

        violations =
          beliefs
          |> Enum.filter(&(&1.status == "active" and not is_nil(getter.(&1))))
          |> Enum.reject(&MapSet.member?(allowed, getter.(&1)))
          |> Enum.map(&{&1.id, getter.(&1)})

        if violations == [] do
          {"#{field} enum", :ok,
           "all active beliefs use #{field} values declared in #{contract.id} (#{MapSet.size(allowed)} values)"}
        else
          {"#{field} enum", :fail,
           "#{field} values outside #{contract.id} enum: #{inspect(violations)}"}
        end
    end
  end

  # --- artifact format and scheme ---

  defp check_artifact_format(beliefs) do
    # artifact is null OR matches /^[a-z][a-z0-9_-]*:.+/
    regex = ~r/^[a-z][a-z0-9_-]*:.+/

    violations =
      beliefs
      |> Enum.filter(&(is_binary(&1.artifact) and &1.artifact != ""))
      |> Enum.reject(&Regex.match?(regex, &1.artifact))
      |> Enum.map(&{&1.id, &1.artifact})

    if violations == [] do
      {"artifact format", :ok, "all artifacts match scheme:id"}
    else
      {"artifact format", :fail, "artifacts violating scheme:id form: #{inspect(violations)}"}
    end
  end

  defp check_artifact_scheme_enum(beliefs) do
    case enum_contract_for(beliefs, "artifact-scheme") do
      nil ->
        {"artifact-scheme enum", :skip,
         "no active enum-registry contract declares artifact-scheme"}

      contract ->
        allowed = MapSet.new(EnumContract.values_for(contract, "artifact-scheme"))

        violations =
          beliefs
          |> Enum.filter(&(&1.status == "active" and is_binary(&1.artifact)))
          |> Enum.map(fn a -> {a.id, scheme(a.artifact)} end)
          |> Enum.reject(fn {_, s} -> MapSet.member?(allowed, s) end)

        if violations == [] do
          {"artifact-scheme enum", :ok,
           "all artifact schemes declared in #{contract.id} (#{MapSet.size(allowed)} schemes)"}
        else
          {"artifact-scheme enum", :fail,
           "artifact schemes outside #{contract.id} enum: #{inspect(violations)}"}
        end
    end
  end

  # --- code: locator format (framework-universal) ---

  defp check_code_artifact_format(beliefs) do
    # Whether `code` is an allowed scheme is the enum check's job; this
    # check pins the locator grammar (path + '#' + opaque anchor, optional
    # trailing @N) on every code: artifact via the shared parser.
    violations =
      beliefs
      |> Enum.filter(&(is_binary(&1.artifact) and String.starts_with?(&1.artifact, "code:")))
      |> Enum.flat_map(fn b ->
        case CB.CodeLocator.parse(b.artifact) do
          {:ok, _} -> []
          {:error, reason} -> [{b.id, b.artifact, reason}]
        end
      end)

    if violations == [] do
      {"code: locator format", :ok, "all code: artifacts parse as code:<path>#<anchor>[@N]"}
    else
      {"code: locator format", :fail, "unparseable code: artifacts: #{inspect(violations)}"}
    end
  end

  # --- codepath output-targets (discovered by kind + tag) ---

  defp check_codepath_targets(beliefs) do
    targets = Enum.filter(beliefs, &CB.OutputTarget.codepath_target?/1)

    case targets do
      [] ->
        {"codepath output-targets", :skip, "no active output:codepath output-target present"}

      _ ->
        violations =
          Enum.flat_map(targets, fn target ->
            case CB.OutputTarget.validate_codepath(target, beliefs) do
              :ok -> []
              {:error, messages} -> Enum.map(messages, &"#{target.id}: #{&1}")
            end
          end)

        if violations == [] do
          {"codepath output-targets", :ok,
           "#{length(targets)} codepath target(s) valid - entry/steps resolve, beliefs carry code: anchors, deps match"}
        else
          {"codepath output-targets", :fail, Enum.join(violations, "; ")}
        end
    end
  end

  # --- implication field absent (framework-universal) ---

  defp check_no_implication_field(beliefs) do
    violations =
      beliefs
      |> Enum.filter(fn a -> a._keys && MapSet.member?(a._keys, "implication") end)
      |> Enum.map(& &1.id)

    if violations == [] do
      {"no implication field", :ok, "no belief carries the deleted implication field"}
    else
      {"no implication field", :fail,
       "beliefs still carrying implication: #{inspect(violations)}"}
    end
  end

  # --- action-item shape (framework-universal) ---

  defp check_action_item_shape(beliefs) do
    violations =
      beliefs
      |> Enum.filter(&(&1.kind == "action-item"))
      |> Enum.filter(fn a ->
        a.type != "directive" or a.contract == true or
          (is_list(a.rules) and a.rules != []) or
          (is_list(a.invariants) and a.invariants != [])
      end)
      |> Enum.map(& &1.id)

    if violations == [] do
      {"action-item shape", :ok,
       "all action-items are non-contract directives with empty rules/invariants"}
    else
      {"action-item shape", :fail, "action-items violating shape: #{inspect(violations)}"}
    end
  end

  # --- grounding rule ---

  # Artifact schemes that count as stipulation events for directive
  # grounding: a prescription is adopted, and adoption grounds either in
  # beliefs (deps) or in a stipulation (a plan, a user decision, a session,
  # or a house document - a policy file is where its rules were fixed).
  # External-source schemes (source:, https:) never ground a directive.
  @stipulation_schemes ~w(plan user session document)

  defp check_grounding(beliefs) do
    # Compounds and inferences must have deps. Directives must have deps
    # or a stipulation artifact, UNLESS they are contract-grade - contracts
    # may be declared from policy without composing.
    violations =
      beliefs
      |> Enum.filter(&(&1.status == "active"))
      |> Enum.filter(fn a ->
        has_deps = is_list(a.deps) and a.deps != []

        case a.type do
          "compound" -> not has_deps
          "inference" -> not has_deps
          "directive" -> a.contract != true and not (has_deps or stipulation_artifact?(a))
          _ -> false
        end
      end)
      |> Enum.map(& &1.id)

    if violations == [] do
      {"grounding", :ok,
       "compounds and inferences have deps; non-contract directives have deps or a stipulation artifact"}
    else
      {"grounding", :fail, "ungrounded nodes: #{inspect(violations)}"}
    end
  end

  defp stipulation_artifact?(%{artifact: a}) when is_binary(a) do
    scheme(a) in @stipulation_schemes
  end

  defp stipulation_artifact?(_), do: false

  # --- subject containment (compound = conjunction) ---

  defp check_subject_containment(beliefs) do
    # A conjunction cannot be about something its parts are not about: an
    # active compound's subject refs must be a subset of the union of its
    # deps' subject refs. Empty subjects pass vacuously; a compound with an
    # unresolvable dep (cross-namespace, not in this list) is skipped, since
    # its union cannot be computed here.
    by_id = Map.new(beliefs, &{&1.id, &1})

    {checked, skipped, violations} =
      beliefs
      |> Enum.filter(&(&1.status == "active" and &1.type == "compound"))
      |> Enum.reduce({0, 0, []}, fn c, {checked, skipped, violations} ->
        refs = subject_refs(c)
        deps = c.deps || []
        resolved = Enum.map(deps, &Map.get(by_id, &1))

        cond do
          refs == [] ->
            {checked + 1, skipped, violations}

          Enum.any?(resolved, &is_nil/1) ->
            {checked, skipped + 1, violations}

          true ->
            union = resolved |> Enum.flat_map(&subject_refs/1) |> MapSet.new()
            escaped = Enum.reject(refs, &MapSet.member?(union, &1))

            if escaped == [] do
              {checked + 1, skipped, violations}
            else
              {checked + 1, skipped, [{c.id, escaped} | violations]}
            end
        end
      end)

    if violations == [] do
      {"subject containment", :ok,
       "compound subjects contained in dep subject union (#{checked} checked, #{skipped} skipped on unresolvable deps)"}
    else
      {"subject containment", :fail,
       "compound subjects escape their deps: #{inspect(Enum.reverse(violations))}"}
    end
  end

  defp subject_refs(%{subjects: subjects}) when is_list(subjects) do
    subjects |> Enum.map(& &1["ref"]) |> Enum.reject(&is_nil/1)
  end

  defp subject_refs(_), do: []

  # --- retired is a directive state ---

  defp check_retired_is_directive(beliefs) do
    # A directive is withdrawn, never falsified: superseded by a successor
    # rule, or retired. Descriptive types have no "in force" to leave.
    violations =
      beliefs
      |> Enum.filter(&(&1.status == "retired"))
      |> Enum.reject(&(&1.type == "directive"))
      |> Enum.map(& &1.id)

    if violations == [] do
      {"retired is directive", :ok, "retired status appears only on directives"}
    else
      {"retired is directive", :fail, "retired non-directives: #{inspect(violations)}"}
    end
  end

  # --- status lifecycle (discovered SM, or framework canon) ---

  defp check_status_enum(beliefs) do
    {source, allowed} =
      case status_lifecycle_contract(beliefs) do
        nil ->
          {"framework canon", Belief.statuses()}

        c ->
          states =
            c
            |> StateMachine.edges()
            |> Enum.flat_map(fn e -> [e.from, e.to] end)
            |> Enum.reject(&is_nil/1)
            |> Enum.uniq()

          {c.id, states}
      end

    if allowed == [] do
      {"status enum", :skip, "status lifecycle contract has no parseable edges"}
    else
      allowed_set = MapSet.new(allowed)

      violations =
        beliefs
        |> Enum.reject(&MapSet.member?(allowed_set, &1.status))
        |> Enum.map(&{&1.id, &1.status})

      if violations == [] do
        {"status enum", :ok, "all nodes have status in #{inspect(allowed)} (#{source})"}
      else
        {"status enum", :fail, "invalid status: #{inspect(violations)}"}
      end
    end
  end

  defp check_superseded_linkage(beliefs) do
    violations =
      beliefs
      |> Enum.filter(&(&1.status == "superseded"))
      |> Enum.reject(&(is_binary(&1.superseded_by) and &1.superseded_by != ""))
      |> Enum.map(& &1.id)

    if violations == [] do
      {"superseded linkage", :ok, "all superseded nodes link to successor"}
    else
      {"superseded linkage", :fail, "superseded without link: #{inspect(violations)}"}
    end
  end

  defp check_retracted_linkage(beliefs) do
    violations =
      beliefs
      |> Enum.filter(&(&1.status == "retracted"))
      |> Enum.reject(fn a ->
        is_binary(a.retracted_on) and a.retracted_on != "" and
          is_binary(a.retracted_reason) and a.retracted_reason != ""
      end)
      |> Enum.map(& &1.id)

    if violations == [] do
      {"retracted linkage", :ok, "all retracted nodes have date and reason"}
    else
      {"retracted linkage", :fail, "retracted without metadata: #{inspect(violations)}"}
    end
  end

  # --- c-prefix identity (framework-universal) ---

  defp check_c_prefix_is_contract(beliefs) do
    # The prefix lives on the local id, so test the segment after the
    # namespace (`cb:c038` -> `c038`) rather than the raw id.
    mismatches =
      beliefs
      |> Enum.filter(&String.starts_with?(local_id(&1.id), "c"))
      |> Enum.reject(&(&1.contract == true))
      |> Enum.map(& &1.id)

    if mismatches == [] do
      {"c-prefix is contract-grade", :ok, "all c-prefix IDs carry contract: true"}
    else
      {"c-prefix is contract-grade", :fail,
       "c-prefix IDs without contract: true: #{inspect(mismatches)}"}
    end
  end

  # --- helpers ---

  defp scheme(uri) when is_binary(uri) do
    case String.split(uri, ":", parts: 2) do
      [s, _] -> s
      _ -> ""
    end
  end

  defp local_id(id) when is_binary(id), do: id |> String.split(":") |> List.last()
  defp local_id(id), do: id
end
