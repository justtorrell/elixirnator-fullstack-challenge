defmodule ElixiratorChallenge.Boundary.Missions do
  @moduledoc """
  Boundary API: Parses and validates form params, errors as data and calls the core
  """

  @type errors :: %{
          optional(:equipment_mass) => String.t(),
          optional(:flight_path) => %{non_neg_integer() => String.t()}
        }

  alias ElixiratorChallenge.Core.MissionCalculations
  alias ElixiratorChallenge.Data.{FlightStep, Mission, Planet}

  @mass_error "must be a positive number"
  @action_error "unknown action"
  @planet_error "unknown planet"

  @spec calculate(map()) :: {:ok, map()} | {:error, errors()}
  def calculate(params) when is_map(params) do
    mass_result = parse_mass(params["equipment_mass"])
    path_result = parse_flight_path(params["flight_path"] || [])

    case {mass_result, path_result} do
      {{:ok, mass}, {:ok, path}} ->
        mission = %Mission{equipment_mass: mass, flight_path: path}
        {:ok, MissionCalculations.calculate_mission_fuel(mission)}

      _ ->
        {:error, collect_errors(mass_result, path_result)}
    end
  end

  defp parse_step(step) do
    with {:ok, action} <- FlightStep.parse_action(step["action"]),
         {:ok, planet} <- Planet.parse(step["planet"]) do
      {:ok, %FlightStep{action: action, planet: planet}}
    else
      {:error, :unknown_action} -> {:error, @action_error}
      {:error, :unknown_planet} -> {:error, @planet_error}
    end
  end

  defp parse_mass(value) when is_binary(value) do
    case Float.parse(value) do
      {mass, ""} when mass > 0 -> {:ok, mass}
      _ -> {:error, @mass_error}
    end
  end

  defp parse_mass(_value), do: {:error, @mass_error}

  defp parse_flight_path(steps) do
    # collect the errors by position
    {valid, invalid} =
      steps
      # add index
      |> Enum.with_index()
      # parse each step including index
      |> Enum.map(fn {step, index} -> {index, parse_step(step)} end)
      # split valid and invalid
      |> Enum.split_with(fn {_index, result} -> match?({:ok, _}, result) end)

    # return the errors, keyed by step position, if there are any
    case invalid do
      [] -> {:ok, Enum.map(valid, fn {_index, {:ok, step}} -> step end)}
      _ -> {:error, Map.new(invalid, fn {index, {:error, message}} -> {index, message} end)}
    end
  end

  defp collect_errors(mass_result, path_result) do
    %{}
    |> add_error(:equipment_mass, mass_result)
    |> add_error(:flight_path, path_result)
  end

  defp add_error(errors, key, {:error, reason}), do: Map.put(errors, key, reason)
  defp add_error(errors, _key, {:ok, _value}), do: errors
end
