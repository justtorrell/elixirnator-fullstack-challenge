defmodule ElixiratorChallenge.Core.MissionCalculationsTest do
  # AT01: spec fuel examples and all three missions (covers AC01)
  use ExUnit.Case, async: true

  alias ElixiratorChallenge.Core.MissionCalculations
  alias ElixiratorChallenge.Data.{FlightStep, Mission}

  import ElixiratorChallenge.MissionFixtures
  # we want apollo_11/1, mars/1 and passenger_ship/1

  describe "calculate_launch_fuel/2" do
    test "success: applies the launch formula once and rounds down" do
      assert MissionCalculations.calculate_launch_fuel(28_801, 9.807) == 11_829
    end
  end

  describe "calculate_land_fuel/2" do
    test "success: applies the landing formula once and rounds down" do
      assert MissionCalculations.calculate_land_fuel(28_801, 9.807) == 9278
    end
  end

  describe "calculate_total_launch_fuel/2" do
    test "success: includes the fuel needed to carry its own fuel" do
      assert MissionCalculations.calculate_total_launch_fuel(28_801, 9.807) == 19_772
    end
  end

  describe "calculate_total_land_fuel/2" do
    test "success: matches the spec's Apollo 11 landing example" do
      assert MissionCalculations.calculate_total_land_fuel(28_801, 9.807) == 13_447
    end

    test "invariant: is zero when the first result is already zero or below" do
      assert MissionCalculations.calculate_total_land_fuel(100, 1.62) == 0
    end
  end

  describe "calculate_step_fuel/2" do
    test "success: uses the total launch fuel for a launch step" do
      step = %FlightStep{action: :launch, planet: :earth}

      assert MissionCalculations.calculate_step_fuel(28_801, step) == 19_772
    end

    test "success: uses the total landing fuel for a landing step" do
      step = %FlightStep{action: :land, planet: :earth}

      assert MissionCalculations.calculate_step_fuel(28_801, step) == 13_447
    end
  end

  describe "calculate_mission_fuel/1 for Apollo 11" do
    setup :apollo_11

    test "success: calculates the total fuel for the spec mission", %{
      mission: mission,
      expected_total: total
    } do
      result = MissionCalculations.calculate_mission_fuel(mission)

      assert result.total_fuel == total
    end

    test "success: lists each steps fuel in the flight order", %{mission: mission} do
      result = MissionCalculations.calculate_mission_fuel(mission)

      step_fuel = Enum.map(result.steps, fn step -> step.fuel end)

      assert step_fuel == [32_988, 2462, 3001, 13_447]
      #                   [launch earth, land moon, launch moon, land earth]
    end
  end

  describe "calculate_mission_fuel/1 for Mars" do
    setup :mars

    test "success: calculates the total fuel for the spec mission", %{
      mission: mission,
      expected_total: total
    } do
      result = MissionCalculations.calculate_mission_fuel(mission)

      assert result.total_fuel == total
    end
  end

  describe "calculate_mission_fuel/1 for Passenger Ship" do
    setup :passenger_ship

    test "success: calculates the total fuel for the spec mission", %{
      mission: mission,
      expected_total: total
    } do
      result = MissionCalculations.calculate_mission_fuel(mission)

      assert result.total_fuel == total
    end
  end

  describe "calculate_mission_fuel/1" do
    test "invariant: an empty flight path needs no more fuel" do
      mission = %Mission{equipment_mass: 28_801, flight_path: []}

      assert MissionCalculations.calculate_mission_fuel(mission) == %{total_fuel: 0, steps: []}
    end
  end
end
