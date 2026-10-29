defmodule WorkerBee.WddValidator do
  @moduledoc """
  WDD compliance validation engine.

  Validates Elixir code against Worker-Bee Driven Design principles
  based on the project's established WDD layer mapping. Each layer's
  rules live in a `WorkerBee.Validation.*Rules` module; this module
  decides which layer a file belongs to and scores the results.
  """

  alias WorkerBee.ProjectMapper

  alias WorkerBee.Validation.{
    BoundaryRules,
    DataRules,
    FunctionalCoreRules,
    LifecycleRules,
    TestingRules
  }

  defstruct [
    :project_map,
    :validation_results,
    :compliance_score,
    :violations,
    :recommendations
  ]

  @type validation_result :: %{
          file_path: String.t(),
          layer: atom(),
          violations: [violation()],
          score: float(),
          recommendations: [String.t()]
        }

  @type violation :: WorkerBee.Validation.Helpers.violation()

  @type t :: %__MODULE__{
          project_map: ProjectMapper.t(),
          validation_results: [validation_result()],
          compliance_score: float(),
          violations: [violation()],
          recommendations: [String.t()]
        }

  # Workers follow the same patterns as boundaries.
  @layer_rules %{
    functions: FunctionalCoreRules,
    boundaries: BoundaryRules,
    workers: BoundaryRules,
    data: DataRules,
    tests: TestingRules,
    lifecycles: LifecycleRules
  }

  @doc """
  Validates the entire project against WDD compliance, loading the
  project map from `.wdd_project_map.yaml` in the project root.
  """
  @spec validate_project(String.t()) :: {:ok, t()} | {:error, String.t()}
  def validate_project(project_path) do
    with {:ok, project_map} <-
           ProjectMapper.load_project_map(Path.join(project_path, ".wdd_project_map.yaml")) do
      validate_project(project_path, project_map)
    end
  end

  @doc """
  Validates the entire project against the given project map.
  """
  @spec validate_project(String.t(), ProjectMapper.t()) :: {:ok, t()}
  def validate_project(project_path, project_map) do
    file_list = project_files(project_path)
    validation_results = Enum.map(file_list, &validate_file(&1, project_map))
    structure_analysis = analyze_project_structure_changes(file_list, project_map)

    {:ok,
     %__MODULE__{
       project_map: project_map,
       validation_results: validation_results,
       compliance_score: calculate_compliance_score(validation_results),
       violations: extract_violations(validation_results) ++ structure_analysis.violations,
       recommendations:
         generate_recommendations(validation_results) ++ structure_analysis.recommendations
     }}
  end

  @doc """
  Validates a single file against WDD principles.
  """
  @spec validate_file(String.t(), ProjectMapper.t()) :: validation_result()
  def validate_file(file_path, project_map) do
    layer = determine_file_layer(file_path, project_map)

    case File.read(file_path) do
      {:ok, content} ->
        violations = validate_content(content, layer, file_path)

        %{
          file_path: file_path,
          layer: layer,
          violations: violations,
          score: calculate_file_score(violations),
          recommendations: generate_file_recommendations(violations, layer)
        }

      {:error, reason} ->
        %{
          file_path: file_path,
          layer: :unknown,
          violations: [
            %{
              type: :file_read_error,
              severity: :error,
              line: nil,
              message: "Cannot read file: #{reason}",
              rule: "file_accessibility",
              file: file_path
            }
          ],
          score: 0.0,
          recommendations: ["Ensure file is accessible and readable"]
        }
    end
  end

  @doc """
  The WDD layer a file belongs to: the layer whose mapped path is the
  longest prefix of the file's path relative to the project root, or
  `:unknown` when no layer's path contains it.
  """
  @spec determine_file_layer(String.t(), ProjectMapper.t()) :: atom()
  def determine_file_layer(file_path, project_map) do
    relative = relative_path(file_path, project_map)

    project_map.layer_paths
    |> Enum.filter(fn {_layer, layer_path} -> in_layer_path?(relative, layer_path) end)
    |> Enum.max_by(fn {_layer, layer_path} -> String.length(layer_path) end, fn -> nil end)
    |> case do
      {layer, _layer_path} -> layer
      nil -> :unknown
    end
  end

  @doc """
  Analyzes project structure to detect when re-mapping might be needed.
  """
  @spec analyze_project_structure_changes([String.t()], ProjectMapper.t()) :: map()
  def analyze_project_structure_changes(file_list, project_map) do
    unmapped_files = find_unmapped_files(file_list, project_map)
    new_directories = find_potential_new_layer_directories(file_list, project_map)
    type_changes = detect_project_type_changes(file_list, project_map)

    {violations, recommendations} =
      structure_findings(unmapped_files, new_directories, type_changes)

    %{
      violations: violations,
      recommendations: recommendations,
      unmapped_files: unmapped_files,
      new_directories: new_directories,
      type_changes: type_changes
    }
  end

  # Private helper functions

  defp structure_findings(unmapped_files, new_directories, type_changes) do
    cond do
      length(unmapped_files) > 5 ->
        {[
           create_structure_violation(
             :unmapped_files,
             :info,
             "Multiple files found outside WDD layer mapping",
             "project_structure_drift"
           )
         ],
         [
           "Found #{length(unmapped_files)} files outside mapped WDD layers. Consider running 'mix wdd.remap' to update your project structure mapping."
         ]}

      unmapped_files != [] ->
        {[],
         [
           "Found #{length(unmapped_files)} files outside mapped directories. You may want to update your WDD layer mapping."
         ]}

      new_directories != [] ->
        new_dir_names = Enum.map_join(new_directories, ", ", &Path.basename/1)

        {[],
         [
           "Detected new directories (#{new_dir_names}) that could be WDD layers. Consider re-mapping if your project structure has evolved."
         ]}

      type_changes.has_changes? ->
        {[],
         [
           "Project type indicators suggest structural changes (#{type_changes.change_description}). Consider re-mapping your WDD layers."
         ]}

      true ->
        {[], []}
    end
  end

  defp project_files(project_path) do
    project_path
    |> Path.join("**/*.{ex,exs}")
    |> Path.wildcard()
    |> Enum.reject(&String.contains?(&1, "/_build/"))
    |> Enum.reject(&String.contains?(&1, "/deps/"))
  end

  defp validate_content(content, layer, file_path) do
    case Map.fetch(@layer_rules, layer) do
      {:ok, rules} -> rules.validate(content, file_path)
      :error -> []
    end
  end

  defp relative_path(file_path, project_map) do
    root = Path.expand(project_map.root_path || File.cwd!())
    file_path |> Path.expand() |> Path.relative_to(root)
  end

  defp in_layer_path?(relative, layer_path) when is_binary(layer_path) and layer_path != "" do
    layer_path = String.trim_trailing(layer_path, "/")
    relative == layer_path or String.starts_with?(relative, layer_path <> "/")
  end

  defp in_layer_path?(_relative, _layer_path), do: false

  defp calculate_file_score(violations) do
    penalty =
      violations
      |> Enum.map(&severity_penalty(&1.severity))
      |> Enum.sum()

    max(0.0, 100.0 - penalty)
  end

  defp severity_penalty(:error), do: 10.0
  defp severity_penalty(:warning), do: 5.0
  defp severity_penalty(:info), do: 2.0

  defp calculate_compliance_score([]), do: 0.0

  defp calculate_compliance_score(validation_results) do
    total_score = validation_results |> Enum.map(& &1.score) |> Enum.sum()
    total_score / length(validation_results)
  end

  defp extract_violations(validation_results) do
    Enum.flat_map(validation_results, & &1.violations)
  end

  defp generate_recommendations(validation_results) do
    validation_results
    |> extract_violations()
    |> Enum.frequencies_by(& &1.type)
    |> Enum.map(fn {type, count} -> generate_recommendation_for_type(type, count) end)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_file_recommendations(violations, layer) do
    side_effects =
      if Enum.any?(violations, &(&1.type == :side_effect)),
        do: ["Move side effects to boundary layer"],
        else: []

    composition =
      if layer == :functions and Enum.any?(violations, &(&1.type == :poor_composition)),
        do: ["Improve function composition with pipes"],
        else: []

    composition ++ side_effects
  end

  defp generate_recommendation_for_type(:side_effect, count),
    do: "Found #{count} side effect(s) in functional core. Move these to boundary layer."

  defp generate_recommendation_for_type(:missing_spec, count),
    do:
      "#{count} public function(s) missing @spec. Add type specifications for better documentation."

  defp generate_recommendation_for_type(:poor_test_naming, count),
    do: "#{count} test(s) have poor naming. Use descriptive test names that explain behavior."

  defp generate_recommendation_for_type(:generic_assertions, count),
    do:
      "#{count} test(s) use generic assertions. Use specific assertions for better test clarity."

  defp generate_recommendation_for_type(_type, _count), do: nil

  # Structure analysis helper functions

  defp find_unmapped_files(file_list, project_map) do
    Enum.filter(file_list, fn file_path ->
      determine_file_layer(file_path, project_map) == :unknown and
        not standard_project_file?(relative_path(file_path, project_map))
    end)
  end

  defp standard_project_file?(relative) do
    Enum.any?(
      ["mix.exs", "config/", "_build/", "deps/", ".git/", "README", "LICENSE"],
      &String.contains?(relative, &1)
    )
  end

  # Directories under lib/ outside every mapped layer that hold three or
  # more Elixir files.
  defp find_potential_new_layer_directories(file_list, project_map) do
    relative_files = Enum.map(file_list, &relative_path(&1, project_map))

    relative_files
    |> Enum.map(&Path.dirname/1)
    |> Enum.uniq()
    |> Enum.filter(&String.starts_with?(&1, "lib/"))
    |> Enum.reject(fn dir ->
      Enum.any?(project_map.layer_paths, fn {_layer, layer_path} ->
        in_layer_path?(dir, layer_path)
      end)
    end)
    |> Enum.filter(fn dir ->
      Enum.count(relative_files, &(Path.dirname(&1) == dir)) >= 3
    end)
  end

  defp detect_project_type_changes(file_list, project_map) do
    current_indicators = detect_current_project_indicators(file_list)

    type_change_detected =
      case project_map.project_type do
        :phoenix_web ->
          not (current_indicators.has_phoenix_web? and current_indicators.has_web_files?)

        :phoenix_api ->
          not (current_indicators.has_phoenix? and current_indicators.has_api_files?)

        :otp_application ->
          not current_indicators.has_otp_patterns?

        :library ->
          current_indicators.has_application_patterns?

        _ ->
          false
      end

    change_description =
      if type_change_detected,
        do: describe_type_changes(project_map.project_type, current_indicators),
        else: ""

    %{
      has_changes?: type_change_detected,
      change_description: change_description,
      current_indicators: current_indicators
    }
  end

  defp detect_current_project_indicators(file_list) do
    content_samples =
      file_list
      |> Enum.take(10)
      |> Enum.map_join("\n", &read_file_head/1)

    %{
      has_phoenix?: String.contains?(content_samples, "Phoenix."),
      has_phoenix_web?: Enum.any?(file_list, &String.contains?(&1, "_web/")),
      has_web_files?: Enum.any?(file_list, &String.contains?(&1, "router.ex")),
      has_api_files?: Enum.any?(file_list, &String.contains?(&1, "api/")),
      has_otp_patterns?:
        String.contains?(content_samples, "GenServer") or
          String.contains?(content_samples, "Supervisor"),
      has_application_patterns?: String.contains?(content_samples, "use Application")
    }
  end

  # The first 1KB of a file, used only as a heuristic sample. A file that
  # cannot be read here is reported by validate_file/2.
  defp read_file_head(file_path) do
    case File.read(file_path) do
      {:ok, content} -> String.slice(content, 0, 1000)
      {:error, _reason} -> ""
    end
  end

  defp describe_type_changes(:library, %{has_application_patterns?: true}),
    do: "library evolved into OTP application"

  defp describe_type_changes(:otp_application, %{has_phoenix?: true}),
    do: "OTP application now includes Phoenix"

  defp describe_type_changes(:phoenix_api, %{has_web_files?: true}),
    do: "Phoenix API now includes web components"

  defp describe_type_changes(_original_type, _current_indicators),
    do: "project structure has evolved"

  defp create_structure_violation(type, severity, message, rule) do
    %{
      type: type,
      severity: severity,
      line: nil,
      message: message,
      rule: rule,
      file: "project_structure"
    }
  end
end
