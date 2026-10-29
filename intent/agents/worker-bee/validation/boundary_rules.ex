defmodule WorkerBee.Validation.BoundaryRules do
  @moduledoc """
  Validation rules for boundary layer compliance.

  The boundary layer handles state, side effects, and provides clean APIs
  while delegating business logic to the functional core.
  """

  import WorkerBee.Validation.Helpers
  alias WorkerBee.Validation.Helpers

  @operation_verbs ["create", "update", "delete", "get", "fetch", "process", "perform"]

  @doc """
  Runs every boundary layer rule against the content.
  """
  @spec validate(String.t(), String.t()) :: [Helpers.violation()]
  def validate(content, file_path) do
    run_checks(
      [
        &validate_genserver_patterns/2,
        &validate_error_handling/2,
        &validate_api_design/2,
        &validate_separation_of_concerns/2
      ],
      content,
      file_path
    )
  end

  @doc """
  Validates GenServer implementation patterns.
  """
  @spec validate_genserver_patterns(String.t(), String.t()) :: [Helpers.violation()]
  def validate_genserver_patterns(content, file_path) do
    if genserver?(content) do
      run_checks(
        [
          &check_genserver_structure/2,
          &check_callback_implementation/2,
          &check_state_management/2,
          &check_api_separation/2
        ],
        content,
        file_path
      )
    else
      []
    end
  end

  @doc """
  Validates error handling patterns.
  """
  @spec validate_error_handling(String.t(), String.t()) :: [Helpers.violation()]
  def validate_error_handling(content, file_path) do
    run_checks(
      [&check_with_statements/2, &check_tagged_tuples/2, &check_error_propagation/2],
      content,
      file_path
    )
  end

  @doc """
  Validates API design patterns.
  """
  @spec validate_api_design(String.t(), String.t()) :: [Helpers.violation()]
  def validate_api_design(content, file_path) do
    run_checks(
      [
        &check_function_specs/2,
        &check_input_validation/2,
        &check_api_consistency/2,
        &check_backwards_compatibility/2
      ],
      content,
      file_path
    )
  end

  @doc """
  Validates separation of concerns.
  """
  @spec validate_separation_of_concerns(String.t(), String.t()) :: [Helpers.violation()]
  def validate_separation_of_concerns(content, file_path) do
    run_checks(
      [
        &check_business_logic_delegation/2,
        &check_side_effect_isolation/2,
        &check_module_responsibilities/2
      ],
      content,
      file_path
    )
  end

  # Private validation functions

  defp check_genserver_structure(content, file_path) do
    missing_init =
      flag_if(
        not Regex.match?(~r/def init/, content),
        violation(
          :missing_callback,
          :error,
          nil,
          "GenServer must implement init/1 callback",
          "genserver_structure",
          file_path
        )
      )

    missing_handlers =
      flag_if(
        not Regex.match?(~r/def handle_(call|cast|info)/, content),
        violation(
          :incomplete_genserver,
          :warning,
          nil,
          "GenServer should implement at least one handle_* callback",
          "genserver_completeness",
          file_path
        )
      )

    missing_init ++ missing_handlers
  end

  defp check_callback_implementation(content, file_path) do
    ~r/def handle_call.*do(.*?)(?=def|\z)/s
    |> Regex.scan(content)
    |> Enum.reject(fn [_full_match, callback_body] ->
      Regex.match?(~r/\{:reply,.*,.*\}/, callback_body)
    end)
    |> Enum.map(fn _match ->
      violation(
        :improper_callback_return,
        :warning,
        nil,
        "handle_call should return {:reply, response, state}",
        "callback_patterns",
        file_path
      )
    end)
  end

  defp check_state_management(content, file_path) do
    direct_mutation =
      flag_if(
        Regex.match?(~r/state\s*=\s*.*/, content),
        violation(
          :direct_state_mutation,
          :info,
          nil,
          "Consider functional state updates instead of direct mutation",
          "state_management",
          file_path
        )
      )

    missing_state_type =
      flag_if(
        not Regex.match?(~r/@type state/, content),
        violation(
          :missing_state_type,
          :info,
          nil,
          "Consider defining @type state :: ... for state structure",
          "state_documentation",
          file_path
        )
      )

    direct_mutation ++ missing_state_type
  end

  defp check_api_separation(content, file_path) do
    flag_if(
      Regex.match?(~r/def (start_link|get_|set_|update_)/, content) and
        Regex.match?(~r/def (init|handle_)/, content) and
        not Regex.match?(~r/# (Client API|Server|Implementation|Callbacks)/, content),
      violation(
        :mixed_api_implementation,
        :info,
        nil,
        "Consider separating client API from server implementation with comments",
        "api_organization",
        file_path
      )
    )
  end

  defp check_with_statements(content, file_path) do
    content
    |> function_definitions()
    |> Enum.filter(fn {_name, body, _line} ->
      complexity(body) > 3 and multiple_operations?(body) and
        not Regex.match?(~r/with\s+.*<-/, body)
    end)
    |> Enum.map(fn {name, _body, line} ->
      violation(
        :missing_with_statement,
        :info,
        line,
        "Function '#{name}' could benefit from 'with' for error composition",
        "railway_oriented_programming",
        file_path
      )
    end)
  end

  defp check_tagged_tuples(content, file_path) do
    content
    |> function_definitions()
    |> Enum.filter(fn {name, body, _line} ->
      operation_function?(name) and not Regex.match?(~r/\{:ok,|\{:error,/, body)
    end)
    |> Enum.map(fn {name, _body, line} ->
      violation(
        :untagged_returns,
        :info,
        line,
        "Function '#{name}' should return tagged tuples {:ok, result} or {:error, reason}",
        "tagged_tuple_returns",
        file_path
      )
    end)
  end

  defp check_error_propagation(content, file_path) do
    case with_expressions(content) do
      {:ok, with_expressions} ->
        with_expressions
        |> Enum.reject(fn {_line, has_else?} -> has_else? end)
        |> Enum.map(fn {line, _has_else?} ->
          violation(
            :missing_error_handling,
            :warning,
            line,
            "'with' statement should have 'else' clause for error handling",
            "error_propagation",
            file_path
          )
        end)

      {:error, reason} ->
        [
          violation(
            :unparseable_file,
            :warning,
            nil,
            "Could not parse file, so 'with' error handling was not checked: #{reason}",
            "error_propagation",
            file_path
          )
        ]
    end
  end

  defp check_function_specs(content, file_path) do
    lines = String.split(content, "\n")

    content
    |> function_definitions()
    |> Enum.uniq_by(fn {name, _body, _line} -> name end)
    |> Enum.reject(fn {name, _body, line} -> spec_before?(lines, name, line) end)
    |> Enum.map(fn {name, _body, line} ->
      violation(
        :missing_spec,
        :info,
        line,
        "Public function '#{name}' should have @spec",
        "api_documentation",
        file_path
      )
    end)
  end

  defp check_input_validation(content, file_path) do
    content
    |> api_functions()
    |> Enum.filter(fn {_name, body, _line} ->
      Regex.match?(~r/def\s+\w+[?!]?\([^)]+\)/, body) and not input_validation?(body)
    end)
    |> Enum.map(fn {name, _body, line} ->
      violation(
        :missing_input_validation,
        :warning,
        line,
        "API function '#{name}' should validate input parameters",
        "input_validation",
        file_path
      )
    end)
  end

  defp check_api_consistency(content, file_path) do
    return_patterns =
      content
      |> api_functions()
      |> Enum.map(fn {_name, body, _line} -> return_pattern(body) end)
      |> Enum.uniq()

    flag_if(
      length(return_patterns) > 2,
      violation(
        :inconsistent_api,
        :info,
        nil,
        "API functions have inconsistent return patterns",
        "api_consistency",
        file_path
      )
    )
  end

  defp check_backwards_compatibility(content, file_path) do
    content
    |> function_definitions()
    |> Enum.map(fn {name, body, line} -> {name, required_parameter_count(body), line} end)
    |> Enum.filter(fn {_name, param_count, _line} -> param_count > 4 end)
    |> Enum.map(fn {name, param_count, line} ->
      violation(
        :too_many_parameters,
        :info,
        line,
        "Function '#{name}' has #{param_count} parameters. Consider using options map",
        "backwards_compatibility",
        file_path
      )
    end)
  end

  defp check_business_logic_delegation(content, file_path) do
    if genserver?(content) do
      content
      |> function_definitions()
      |> Enum.filter(fn {name, body, _line} ->
        String.starts_with?(name, "handle_") and business_logic?(body) and
          not delegates_to_core?(body)
      end)
      |> Enum.map(fn {name, _body, line} ->
        violation(
          :business_logic_in_boundary,
          :warning,
          line,
          "#{name} contains business logic. Consider delegating to functional core",
          "separation_of_concerns",
          file_path
        )
      end)
    else
      []
    end
  end

  defp check_side_effect_isolation(content, file_path) do
    side_effects? =
      Enum.any?(
        [~r/File\./, ~r/HTTPoison\./, ~r/Repo\./, ~r/Logger\./],
        &Regex.match?(&1, content)
      )

    flag_if(
      side_effects? and not Regex.match?(~r/with\s+.*<-|case\s+.*do/, content),
      violation(
        :improper_side_effect_handling,
        :info,
        nil,
        "Side effects should be wrapped with proper error handling",
        "side_effect_isolation",
        file_path
      )
    )
  end

  defp check_module_responsibilities(content, file_path) do
    responsibilities =
      [
        {~r/use GenServer/, "process_management"},
        {~r/def.*validate/, "validation"},
        {~r/def.*format/, "formatting"},
        {~r/def.*parse/, "parsing"},
        {~r/File\./, "file_operations"},
        {~r/HTTPoison\./, "http_operations"}
      ]
      |> Enum.filter(fn {pattern, _name} -> Regex.match?(pattern, content) end)
      |> Enum.map(fn {_pattern, name} -> name end)

    flag_if(
      length(responsibilities) > 3,
      violation(
        :too_many_responsibilities,
        :info,
        nil,
        "Module has too many responsibilities: #{Enum.join(responsibilities, ", ")}",
        "single_responsibility",
        file_path
      )
    )
  end

  # Helper functions

  defp genserver?(content), do: String.contains?(content, "use GenServer")

  # Each `with` expression as {line, has_else?}, read from the AST.
  defp with_expressions(content) do
    case Code.string_to_quoted(content) do
      {:ok, ast} ->
        {_ast, with_expressions} =
          Macro.prewalk(ast, [], fn
            {:with, meta, args} = node, acc when is_list(args) and args != [] ->
              {node, [{meta[:line], else_clause?(List.last(args))} | acc]}

            node, acc ->
              {node, acc}
          end)

        {:ok, Enum.reverse(with_expressions)}

      {:error, {meta, message, token}} ->
        {:error, "line #{meta[:line]}: #{inspect(message)}#{inspect(token)}"}
    end
  end

  defp else_clause?(blocks) when is_list(blocks), do: Keyword.has_key?(blocks, :else)
  defp else_clause?(_blocks), do: false

  defp multiple_operations?(body) do
    length(Regex.scan(~r/\w+\.\w+\(/, body)) + length(Regex.scan(~r/GenServer\./, body)) > 2
  end

  # GenServer and LiveView callbacks (handle_*) are not operation functions:
  # their return shapes are fixed by the behaviour.
  defp operation_function?(name) do
    Enum.any?(@operation_verbs, &String.starts_with?(name, &1))
  end

  defp spec_before?(lines, name, line_num) do
    previous_line = Enum.at(lines, line_num - 2, "")
    line_num > 1 and Regex.match?(~r/@spec\s+#{Regex.escape(name)}(?![\w?!])/, previous_line)
  end

  # Functions that look like public API (not handle_* or init)
  defp api_functions(content) do
    content
    |> function_definitions()
    |> Enum.reject(fn {name, _body, _line} ->
      String.starts_with?(name, "handle_") or name == "init"
    end)
  end

  defp input_validation?(body) do
    Enum.any?(
      [~r/when\s+is_/, ~r/validate/, ~r/\|>\s*check/, ~r/with\s+.*<-\s*.*validate/],
      &Regex.match?(&1, body)
    )
  end

  defp return_pattern(body) do
    cond do
      Regex.match?(~r/\{:ok,.*\}/, body) -> :tagged_tuple
      Regex.match?(~r/\w+/, body) -> :direct_value
      true -> :unknown
    end
  end

  defp required_parameter_count(body) do
    case Regex.run(~r/def\s+\w+[?!]?\(([^)]*)\)/, body) do
      [_, params] ->
        params
        |> String.split(",")
        |> Enum.reject(&String.contains?(&1, "\\\\"))
        |> length()

      nil ->
        0
    end
  end

  defp business_logic?(body) do
    Enum.any?(
      [~r/calculate/, ~r/compute/, ~r/process.*data/, ~r/transform/, ~r/aggregate/],
      &Regex.match?(&1, body)
    )
  end

  defp delegates_to_core?(body) do
    Enum.any?([~r/\w+Core\./, ~r/\w+Service\./, ~r/\w+Logic\./], &Regex.match?(&1, body))
  end
end
