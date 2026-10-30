defmodule ElixiratorChallenge.Data.Mission do
  @moduledoc """
  Data Layer: Equipment mass and the flight path
  """

  alias ElixiratorChallenge.Data.FlightStep

  @enforce_keys [:equipment_mass, :flight_path]
  defstruct [:equipment_mass, :flight_path]

  @type t :: %__MODULE__{equipment_mass: number(), flight_path: [FlightStep.t()]}
end
