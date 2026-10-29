defmodule WorkerBee.Validation.TestingRules do
  @moduledoc """
  Validation rules for testing layer compliance.

  Tests should focus on behavior, be well-organized, and provide
  comprehensive coverage of the application logic.
  """

  import WorkerBee.Validation.Helpers
  alias WorkerBee.Validation.Helpers

  @doc """
  Runs every testing rule against the content.
  """
  @spec validate(String.t(), String.t()) :: [Helpers.violation()]
  def validate(content, file_path) do
    run_checks(
      [&validate_test_organization/2, &validate_test_behavior_focus/2],
      content,
      file_path
    )
  end

  @doc """
  Validates how tests are grouped, named, and set up.
  """
  @spec validate_test_organization(String.t(), String.t()) :: [Helpers.violation()]
  def validate_test_organization(content, file_path) do
    run_checks(
      [&check_describe_blocks/2, &check_test_naming/2, &check_setup_patterns/2],
      content,
      file_path
    )
  end

  @doc """
  Validates that tests assert on public behaviour with specific assertions.
  """
  @spec validate_test_behavior_focus(String.t(), String.t()) :: [Helpers.violation()]
  def validate_test_behavior_focus(content, file_path) do
    run_checks(
      [&check_behavior_vs_implementation/2, &check_assertion_quality/2],
      content,
      file_path
    )
  end

  defp check_describe_blocks(content, file_path) do
    flag_if(
      String.contains?(file_path, "_test.exs") and
        Regex.match?(~r/test\s+"/, content) and
        not Regex.match?(~r/describe\s+"/, content),
      violation(
        :missing_describe_blocks,
        :info,
        nil,
        "Consider using 'describe' blocks to organize related tests",
        "test_organization",
        file_path
      )
    )
  end

  defp check_test_naming(content, file_path) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_num} ->
      case Regex.run(~r/test\s+"([^"]+)"/, line) do
        [_, name] -> [{name, line_num}]
        nil -> []
      end
    end)
    |> Enum.filter(fn {name, _line_num} ->
      String.length(name) < 10 or not String.contains?(name, " ")
    end)
    |> Enum.map(fn {name, line_num} ->
      violation(
        :poor_test_naming,
        :info,
        line_num,
        "Test name '#{name}' should be more descriptive",
        "test_naming",
        file_path
      )
    end)
  end

  defp check_setup_patterns(content, file_path) do
    flag_if(
      length(Regex.scan(~r/\bsetup\b/, content)) >= 3 and
        not Regex.match?(~r/setup_all/, content),
      violation(
        :repeated_setup,
        :info,
        nil,
        "Consider using setup_all or named setups to reduce duplication",
        "test_setup",
        file_path
      )
    )
  end

  defp check_behavior_vs_implementation(content, file_path) do
    flag_if(
      Regex.match?(~r/assert.*private_function/, content),
      violation(
        :testing_implementation,
        :warning,
        nil,
        "Tests should focus on public behavior, not private implementation",
        "behavior_testing",
        file_path
      )
    )
  end

  defp check_assertion_quality(content, file_path) do
    flag_if(
      Regex.match?(~r/assert\s+(true|false)\b/, content),
      violation(
        :generic_assertions,
        :warning,
        nil,
        "Avoid generic assertions like 'assert true'. Use specific assertions",
        "assertion_quality",
        file_path
      )
    )
  end
end
