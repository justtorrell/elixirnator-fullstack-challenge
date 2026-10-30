defmodule ElixiratorChallenge.Boundary.MissionsTest do
  use ExUnit.Case, async: true

  alias ElixiratorChallenge.Boundary.Missions

  import ElixiratorChallenge.MissionFixtures

  describe "calculate/1 for Mars" do
    setup :mars

    test "success: calculates the total fuel from the form params", %{
      mission_params: params,
      expected_total: total
    } do
      assert {:ok, result} = Missions.calculate(params)
      assert result.total_fuel == total
    end
  end

  describe "calculate/1 for Passenger Ship" do
    setup :passenger_ship

    test "success: calculates the total fuel from the form params", %{
      mission_params: params,
      expected_total: total
    } do
      assert {:ok, result} = Missions.calculate(params)
      assert result.total_fuel == total
    end
  end

  describe "calculate/1 for Apollo 11" do
    setup :apollo_11

    test "success: calculates the total fuel from the form params", %{
      mission_params: params,
      expected_total: total
    } do
      assert {:ok, result} = Missions.calculate(params)
      assert result.total_fuel == total
    end
  end

  describe "calculate/1 with an invalid mass" do
    setup :apollo_11

    test "failure: rejects a mass of zero or below", %{mission_params: params} do
      params = Map.put(params, "equipment_mass", "0")

      assert {:error, %{equipment_mass: "must be a positive number"}} ==
               Missions.calculate(params)

      params = Map.put(params, "equipment_mass", "-5")

      assert {:error, %{equipment_mass: "must be a positive number"}} ==
               Missions.calculate(params)
    end

    test "failure: rejects a mass that is not a number", %{mission_params: params} do
      params = Map.put(params, "equipment_mass", "abc")

      assert {:error, %{equipment_mass: "must be a positive number"}} ==
               Missions.calculate(params)

      params = Map.put(params, "equipment_mass", "")

      assert {:error, %{equipment_mass: "must be a positive number"}} ==
               Missions.calculate(params)

      params = Map.put(params, "equipment_mass", "28801kg")

      assert {:error, %{equipment_mass: "must be a positive number"}} ==
               Missions.calculate(params)
    end

    test "failure: rejects a missing mass", %{mission_params: params} do
      params = Map.delete(params, "equipment_mass")

      assert {:error, %{equipment_mass: "must be a positive number"}} ==
               Missions.calculate(params)
    end
  end

  describe "calculate/1 with an invalid flight path" do
    setup :apollo_11

    test "failure: reports an unknown planet at its position", %{mission_params: params} do
      params = replace_step(params, 1, %{"action" => "land", "planet" => "saturn"})

      assert Missions.calculate(params) == {:error, %{flight_path: %{1 => "unknown planet"}}}
    end

    test "failure: reports an unknown action at its position", %{mission_params: params} do
      params = replace_step(params, 2, %{"action" => "barrel_roll", "planet" => "moon"})

      assert Missions.calculate(params) == {:error, %{flight_path: %{2 => "unknown action"}}}
    end

    test "failure: reports a bad mass and a bad step together", %{mission_params: params} do
      params =
        params
        |> Map.put("equipment_mass", "-5")
        |> replace_step(1, %{"action" => "land", "planet" => "jupiter"})

      assert Missions.calculate(params) ==
               {:error,
                %{
                  equipment_mass: "must be a positive number",
                  flight_path: %{1 => "unknown planet"}
                }}
    end

    test "success: an empty flight path needs no fuel", %{mission_params: params} do
      params = Map.put(params, "flight_path", [])

      assert Missions.calculate(params) == {:ok, %{total_fuel: 0, steps: []}}
    end
  end

  # Private helpers
  defp replace_step(params, index, step) do
    # To invalidate parameters, such that we can test those
    path = List.replace_at(params["flight_path"], index, step)
    Map.put(params, "flight_path", path)
  end
end
