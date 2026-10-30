defmodule ElixiratorChallenge.Data.FlightStep do
  @moduledoc """
  Data Layer: one step of a flight path - an action at a planet
  """

  alias ElixiratorChallenge.Data.Planet

  @enforce_keys [:action, :planet]
  defstruct [:action, :planet]

  @type action :: :launch | :land
  @type t :: %__MODULE__{action: action(), planet: Planet.t()}

  @spec parse_action(String.t()) :: {:ok, action()} | {:error, :unknown_action}
  def parse_action("launch"), do: {:ok, :launch}
  def parse_action("land"), do: {:ok, :land}
  def parse_action(_), do: {:error, :unknown_action}
end
