defmodule ElixiratorChallenge.Core.MissionCalculations do
  @moduledoc """
  Functional core: pure fuel calculations for launching from and landing on planets
  Input here is trusted - validation happens in ElixiratorChallenge.Boundary.Missions.
  """

  alias ElixiratorChallenge.Data.{FlightStep, Mission, Planet}

  @launch_multiplier 0.042
  @launch_subtractor 33
  @land_multiplier 0.033
  @land_subtractor 42

  @spec calculate_launch_fuel(number(), float()) :: integer()
  def calculate_launch_fuel(mass, gravity),
    do: floor(mass * gravity * @launch_multiplier - @launch_subtractor)

  @spec calculate_land_fuel(number(), float()) :: integer()
  def calculate_land_fuel(mass, gravity),
    do: floor(mass * gravity * @land_multiplier - @land_subtractor)

  @spec calculate_total_launch_fuel(number(), float()) :: integer()
  def calculate_total_launch_fuel(mass, gravity),
    do: total_fuel(calculate_launch_fuel(mass, gravity), gravity, &calculate_launch_fuel/2)

  @spec calculate_total_land_fuel(number(), float()) :: integer()
  def calculate_total_land_fuel(mass, gravity),
    do: total_fuel(calculate_land_fuel(mass, gravity), gravity, &calculate_land_fuel/2)

  @spec calculate_step_fuel(number(), FlightStep.t()) :: integer()
  def calculate_step_fuel(mass, %FlightStep{action: :launch, planet: planet}),
    do: calculate_total_launch_fuel(mass, Planet.gravity(planet))

  def calculate_step_fuel(mass, %FlightStep{action: :land, planet: planet}),
    do: calculate_total_land_fuel(mass, Planet.gravity(planet))

  @spec calculate_mission_fuel(Mission.t()) ::
          %{total_fuel: integer(), steps: [%{step: FlightStep.t(), fuel: integer()}]}
  def calculate_mission_fuel(%Mission{equipment_mass: mass, flight_path: path}) do
    # Build each steps running total from the final step to the first
    {reversed_steps, total} =
      path
      |> Enum.reverse()
      |> Enum.map_reduce(0, fn step, fuel_so_far ->
        fuel = calculate_step_fuel(mass + fuel_so_far, step)
        {%{step: step, fuel: fuel}, fuel_so_far + fuel}
      end)

    # reverse the list back to the original flight path
    %{total_fuel: total, steps: Enum.reverse(reversed_steps)}
  end

  # Helper function to handle the recursive nature of calculating the total fuel
  # no fuel needs no more
  defp total_fuel(fuel, _gravity, _step_fun) when fuel <= 0, do: 0

  # keep this fuel, plus the total for carrying it
  defp total_fuel(fuel, gravity, step_fun),
    do: fuel + total_fuel(step_fun.(fuel, gravity), gravity, step_fun)
end
