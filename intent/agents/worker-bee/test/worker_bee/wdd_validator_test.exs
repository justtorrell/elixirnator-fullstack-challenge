defmodule WorkerBee.WddValidatorTest do
  use ExUnit.Case, async: true

  alias WorkerBee.{ProjectMapper, WddValidator}

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    project_map = %ProjectMapper{
      project_name: "shop",
      project_type: :phoenix_web,
      root_path: tmp_dir,
      layer_paths: %{
        functions: "lib/shop_web/functional_core",
        boundaries: "lib/shop_web",
        tests: "test"
      }
    }

    %{project_map: project_map}
  end

  describe "determine_file_layer/2" do
    test "invariant: the longest matching layer path wins", %{tmp_dir: tmp_dir, project_map: map} do
      file = Path.join(tmp_dir, "lib/shop_web/functional_core/pricing.ex")

      assert WddValidator.determine_file_layer(file, map) == :functions
    end

    test "invariant: a layer path matches whole path segments only",
         %{tmp_dir: tmp_dir, project_map: map} do
      file = Path.join(tmp_dir, "lib/shop_webhooks/stripe.ex")

      assert WddValidator.determine_file_layer(file, map) == :unknown
    end
  end

  describe "validate_file/2" do
    test "failure: functional core violations are reported and scored",
         %{tmp_dir: tmp_dir, project_map: map} do
      file = Path.join(tmp_dir, "lib/shop_web/functional_core/cart.ex")
      File.mkdir_p!(Path.dirname(file))

      File.write!(file, """
      defmodule Cart do
        def add(cart, item), do: GenServer.call(cart, {:add, item})
      end
      """)

      result = WddValidator.validate_file(file, map)

      assert {result.layer, Enum.map(result.violations, & &1.type), result.score} ==
               {:functions, [:side_effect, :poor_error_handling], 88.0}
    end
  end

  describe "analyze_project_structure_changes/2" do
    test "failure: more than five unmapped files is reported as drift",
         %{tmp_dir: tmp_dir, project_map: map} do
      files = Enum.map(1..6, &Path.join(tmp_dir, "lib/shop/legacy/module_#{&1}.ex"))

      analysis = WddValidator.analyze_project_structure_changes(files, map)

      assert {Enum.map(analysis.violations, & &1.type), analysis.recommendations} ==
               {[:unmapped_files],
                [
                  "Found 6 files outside mapped WDD layers. Consider running 'mix wdd.remap' to update your project structure mapping."
                ]}
    end
  end
end
