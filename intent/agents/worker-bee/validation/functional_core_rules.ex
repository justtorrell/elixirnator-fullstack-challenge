defmodule WorkerBee.Validation.FunctionalCoreRules do
  @moduledoc """
  Validation rules for functional core layer compliance.

  The functional core must be pure, composable, and free from side effects.
  These rules enforce the fundamental principles of Worker-Bee Driven Design.
  """

  import WorkerBee.Validation.Helpers
  alias WorkerBee.Validation.Helpers

  @doc """
  Runs every functional core rule against the content.
  """
  @spec validate(String.t(), String.t()) :: [Helpers.violation()]
  def validate(content, file_path) do
    run_checks(
      [
        &validate_purity/2,
        &validate_composition/2,
        &validate_single_responsibility/2,
        &validate_pattern_matching/2
      ],
      content,
      file_path
    )
  end

  @doc """
  Validates that functional core modules follow purity principles.
  """
  @spec validate_purity(String.t(), String.t()) :: [Helpers.violation()]
  def validate_purity(content, file_path) do
    run_checks(
      [
        &check_genserver_calls/2,
        &check_process_operations/2,
        &check_file_operations/2,
        &check_network_operations/2,
        &check_logging_operations/2,
        &check_database_operations/2
      ],
      content,
      file_path
    )
  end

  @doc """
  Validates function composition patterns.
  """
  @spec validate_composition(String.t(), String.t()) :: [Helpers.violation()]
  def validate_composition(content, file_path) do
    run_checks([&check_error_composition/2, &check_function_chaining/2], content, file_path)
  end

  @doc """
  Validates single responsibility principle adherence.
  """
  @spec validate_single_responsibility(String.t(), String.t()) :: [Helpers.violation()]
  def validate_single_responsibility(content, file_path) do
    run_checks([&check_function_complexity/2, &check_function_naming/2], content, file_path)
  end

  @doc """
  Validates proper use of pattern matching.
  """
  @spec validate_pattern_matching(String.t(), String.t()) :: [Helpers.violation()]
  def validate_pattern_matching(content, file_path) do
    run_checks(
      [&check_pattern_vs_conditionals/2, &check_guard_usage/2, &check_function_heads/2],
      content,
      file_path
    )
  end

  # Private validation functions

  defp check_genserver_calls(content, file_path) do
    [
      ~r/GenServer\.(call|cast|start|start_link)/,
      ~r/Agent\.(get|update|start|start_link)/,
      ~r/Task\.(start|start_link|async)/
    ]
    |> flag_each_match(
      content,
      violation(
        :side_effect,
        :error,
        nil,
        "Functional core should not contain GenServer/Agent/Task operations",
        "functional_core_purity",
        file_path
      )
    )
  end

  defp check_process_operations(content, file_path) do
    [
      ~r/spawn(_link|_monitor)?/,
      ~r/Process\.(send|send_after|exit|flag)/,
      ~r/receive\s+do/,
      ~r/:timer\./
    ]
    |> flag_each_match(
      content,
      violation(
        :side_effect,
        :error,
        nil,
        "Functional core should not perform process operations",
        "functional_core_purity",
        file_path
      )
    )
  end

  defp check_file_operations(content, file_path) do
    [
      ~r/File\.(read|write|open|close|copy|rename|rm|mkdir)/,
      ~r/IO\.(puts|write|read|gets)/,
      ~r/Path\.(wildcard|expand)/
    ]
    |> flag_each_match(
      content,
      violation(
        :side_effect,
        :error,
        nil,
        "Functional core should not perform file I/O operations",
        "functional_core_purity",
        file_path
      )
    )
  end

  defp check_network_operations(content, file_path) do
    [
      ~r/HTTPoison\./,
      ~r/Tesla\./,
      ~r/Req\./,
      ~r/:httpc\./,
      ~r/:gen_tcp/,
      ~r/:ssl/
    ]
    |> flag_each_match(
      content,
      violation(
        :side_effect,
        :error,
        nil,
        "Functional core should not perform network operations",
        "functional_core_purity",
        file_path
      )
    )
  end

  defp check_logging_operations(content, file_path) do
    flag_if(
      Regex.match?(~r/Logger\.(info|debug|warn|error)/, content),
      violation(
        :side_effect,
        :warning,
        nil,
        "Consider moving logging to boundary layer",
        "functional_core_purity",
        file_path
      )
    )
  end

  defp check_database_operations(content, file_path) do
    [
      ~r/Repo\.(get|insert|update|delete|all)/,
      ~r/Ecto\.Query/,
      ~r/from\s+\w+\s+in/,
      ~r/:mnesia\./
    ]
    |> flag_each_match(
      content,
      violation(
        :side_effect,
        :error,
        nil,
        "Functional core should not perform database operations",
        "functional_core_purity",
        file_path
      )
    )
  end

  defp check_error_composition(content, file_path) do
    untagged =
      flag_if(
        Regex.match?(~r/def \w+.*do/, content) and
          not Regex.match?(~r/\{:ok,|\{:error,/, content),
        violation(
          :poor_error_handling,
          :info,
          nil,
          "Consider using tagged tuples {:ok, result} or {:error, reason}",
          "error_composition",
          file_path
        )
      )

    missing_with =
      content
      |> function_definitions()
      |> Enum.filter(fn {_name, body, _line} ->
        complexity(body) > 5 and not Regex.match?(~r/\bwith\s/, body)
      end)
      |> Enum.map(fn {name, _body, line} ->
        violation(
          :missing_error_composition,
          :info,
          line,
          "Complex function '#{name}' might benefit from 'with' statement",
          "error_composition",
          file_path
        )
      end)

    untagged ++ missing_with
  end

  defp check_function_chaining(content, file_path) do
    flag_if(
      Regex.match?(~r/\(\s*\w+\(\s*\w+\(\s*\w+\(/, content),
      violation(
        :poor_composition,
        :info,
        nil,
        "Consider using pipe operator instead of nested function calls",
        "function_chaining",
        file_path
      )
    )
  end

  defp check_function_complexity(content, file_path) do
    content
    |> function_definitions()
    |> Enum.flat_map(fn {name, body, line} ->
      complexity_violation(name, complexity(body), line, file_path)
    end)
  end

  defp complexity_violation(name, score, line, file_path) when score > 10 do
    [
      violation(
        :high_complexity,
        :warning,
        line,
        "Function '#{name}' is too complex (score: #{score})",
        "function_complexity",
        file_path
      )
    ]
  end

  defp complexity_violation(name, score, line, file_path) when score > 7 do
    [
      violation(
        :moderate_complexity,
        :info,
        line,
        "Function '#{name}' could be simplified (score: #{score})",
        "function_complexity",
        file_path
      )
    ]
  end

  defp complexity_violation(_name, _score, _line, _file_path), do: []

  defp check_function_naming(content, file_path) do
    content
    |> function_definitions()
    |> Enum.uniq_by(fn {name, _body, _line} -> name end)
    |> Enum.flat_map(fn {name, _body, line} -> naming_violation(name, line, file_path) end)
  end

  defp naming_violation(name, line, file_path) do
    cond do
      String.length(name) < 3 ->
        [
          violation(
            :poor_naming,
            :info,
            line,
            "Function name '#{name}' is too short",
            "function_naming",
            file_path
          )
        ]

      not Regex.match?(~r/^[a-z_][a-z0-9_]*[?!]?$/, name) ->
        [
          violation(
            :poor_naming,
            :warning,
            line,
            "Function name '#{name}' doesn't follow Elixir conventions",
            "function_naming",
            file_path
          )
        ]

      String.contains?(name, ["temp", "tmp", "test", "foo", "bar"]) ->
        [
          violation(
            :poor_naming,
            :info,
            line,
            "Function name '#{name}' appears to be a placeholder",
            "function_naming",
            file_path
          )
        ]

      true ->
        []
    end
  end

  defp check_pattern_vs_conditionals(content, file_path) do
    ~r/if\s+.*\s+do.*else.*end/s
    |> Regex.scan(content, return: :index)
    |> Enum.map(fn [{start, _length}] ->
      violation(
        :suboptimal_pattern_matching,
        :info,
        line_at(content, start),
        "Consider using pattern matching instead of if/else",
        "pattern_matching_preference",
        file_path
      )
    end)
  end

  defp check_guard_usage(content, file_path) do
    if Regex.match?(~r/when\s+is_\w+/, content) do
      []
    else
      [
        ~r/is_atom\(/,
        ~r/is_binary\(/,
        ~r/is_integer\(/,
        ~r/is_list\(/,
        ~r/is_map\(/
      ]
      |> flag_each_match(
        content,
        violation(
          :missing_guards,
          :info,
          nil,
          "Consider using guard clauses for type checks",
          "guard_usage",
          file_path
        )
      )
    end
  end

  defp check_function_heads(content, file_path) do
    content
    |> function_definitions()
    |> Enum.filter(fn {name, body, _line} ->
      Regex.match?(~r/case\s+.*\s+do/, body) and not multiple_heads?(content, name)
    end)
    |> Enum.map(fn {name, _body, line} ->
      violation(
        :could_use_function_heads,
        :info,
        line,
        "Function '#{name}' could use multiple function heads instead of case",
        "function_heads",
        file_path
      )
    end)
  end

  # Helper functions

  # One copy of the violation for each pattern that matches the content.
  defp flag_each_match(patterns, content, violation) do
    patterns
    |> Enum.filter(&Regex.match?(&1, content))
    |> Enum.map(fn _pattern -> violation end)
  end

  defp multiple_heads?(content, name) do
    length(Regex.scan(~r/def\s+#{Regex.escape(name)}(?![\w?!])/, content)) > 1
  end
end
