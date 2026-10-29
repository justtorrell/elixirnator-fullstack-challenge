defmodule WorkerBee.Validation.DataRules do
  @moduledoc """
  Validation rules for data layer compliance.

  Data structures should be immutable, well-designed, and follow
  appropriate access patterns.
  """

  import WorkerBee.Validation.Helpers
  alias WorkerBee.Validation.Helpers

  @doc """
  Runs every data layer rule against the content.
  """
  @spec validate(String.t(), String.t()) :: [Helpers.violation()]
  def validate(content, file_path) do
    run_checks(
      [&check_default_values/2, &check_mutation_patterns/2, &check_deep_nesting/2],
      content,
      file_path
    )
  end

  defp check_default_values(content, file_path) do
    flag_if(
      Regex.match?(~r/defstruct\s+\[/, content) and
        not Regex.match?(~r/defstruct.*:.*,/, content),
      violation(
        :struct_without_defaults,
        :info,
        nil,
        "Consider providing default values in struct definition",
        "struct_best_practices",
        file_path
      )
    )
  end

  defp check_mutation_patterns(content, file_path) do
    flag_if(
      String.contains?(content, "defstruct") and Regex.match?(~r/Map\.put\(.*,.*,.*\)/, content),
      violation(
        :data_mutation,
        :info,
        nil,
        "Consider using struct update syntax: %{struct | field: value}",
        "immutability_patterns",
        file_path
      )
    )
  end

  defp check_deep_nesting(content, file_path) do
    flag_if(
      Regex.match?(~r/%\{.*%\{.*%\{/, content),
      violation(
        :deep_nesting,
        :warning,
        nil,
        "Deeply nested maps are hard to work with. Consider flattening or using structs",
        "data_structure_design",
        file_path
      )
    )
  end
end
