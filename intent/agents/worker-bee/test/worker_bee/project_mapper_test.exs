defmodule WorkerBee.ProjectMapperTest do
  use ExUnit.Case, async: true

  alias WorkerBee.ProjectMapper

  @moduletag :tmp_dir

  describe "save_project_map/2 and load_project_map/1" do
    test "invariant: a saved map loads back unchanged", %{tmp_dir: tmp_dir} do
      map_file = Path.join(tmp_dir, ".wdd_project_map.yaml")

      project_map = %ProjectMapper{
        project_name: "shop",
        project_type: :phoenix_web,
        root_path: "/projects/shop",
        layer_paths: %{
          data: "lib/shop/types",
          functions: "lib/shop/core",
          tests: "test",
          boundaries: "lib/shop_web",
          lifecycles: "lib/shop/application.ex",
          workers: nil
        },
        framework_considerations: ["Phoenix contexts as boundary layers"],
        naming_conventions: %{module_prefix: "Shop", functional_core_suffix: "Core"},
        discovered_patterns: []
      }

      {:ok, _message} = ProjectMapper.save_project_map(project_map, map_file)

      assert ProjectMapper.load_project_map(map_file) == {:ok, project_map}
    end
  end

  describe "load_project_map/1" do
    test "failure: an unknown project type is an error", %{tmp_dir: tmp_dir} do
      map_file = write_map(tmp_dir, "project_type: spaceship\n")

      assert ProjectMapper.load_project_map(map_file) ==
               {:error, ~s(Unknown project_type "spaceship" in project map)}
    end

    test "failure: an unknown layer is an error", %{tmp_dir: tmp_dir} do
      map_file = write_map(tmp_dir, "project_type: library\nwdd_layers:\n  services: \"lib/x\"\n")

      assert ProjectMapper.load_project_map(map_file) ==
               {:error, ~s(Unknown WDD layer "services" in project map)}
    end

    test "failure: malformed YAML is an error", %{tmp_dir: tmp_dir} do
      map_file = write_map(tmp_dir, "project_type: [unclosed\n")

      assert {:error, "Invalid project map YAML: " <> _detail} =
               ProjectMapper.load_project_map(map_file)
    end
  end

  defp write_map(tmp_dir, yaml) do
    map_file = Path.join(tmp_dir, ".wdd_project_map.yaml")
    File.write!(map_file, yaml)
    map_file
  end
end
