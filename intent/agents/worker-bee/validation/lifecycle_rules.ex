defmodule WorkerBee.Validation.LifecycleRules do
  @moduledoc """
  Validation rules for lifecycle layer compliance.

  Applications and supervisors start the system and define how its
  processes are restarted.
  """

  import WorkerBee.Validation.Helpers
  alias WorkerBee.Validation.Helpers

  @doc """
  Runs every lifecycle rule against the content.
  """
  @spec validate(String.t(), String.t()) :: [Helpers.violation()]
  def validate(content, file_path) do
    run_checks(
      [&check_supervision_patterns/2, &check_application_structure/2, &check_child_specs/2],
      content,
      file_path
    )
  end

  defp check_supervision_patterns(content, file_path) do
    flag_if(
      String.contains?(content, "Supervisor") and not Regex.match?(~r/children\s*=/, content),
      violation(
        :missing_child_specs,
        :warning,
        nil,
        "Supervisor should define children specifications",
        "supervision_structure",
        file_path
      )
    )
  end

  defp check_application_structure(content, file_path) do
    flag_if(
      String.contains?(content, "use Application") and not Regex.match?(~r/def start/, content),
      violation(
        :missing_start_function,
        :error,
        nil,
        "Application must implement start/2 function",
        "application_structure",
        file_path
      )
    )
  end

  defp check_child_specs(content, file_path) do
    flag_if(
      Regex.match?(~r/children\s*=/, content) and
        not Regex.match?(~r/\{.*,.*\}|\w+\.child_spec/, content),
      violation(
        :improper_child_specs,
        :warning,
        nil,
        "Child specifications should follow proper format",
        "child_spec_format",
        file_path
      )
    )
  end
end
