defmodule ElixiratorChallenge.Data.Planet do
  @moduledoc """
  Data Layer: the supported planets and their gravity
  The core will only ever pass valid data so anything unknown should crash loudly
  """

  @gravity [earth: 9.807, moon: 1.62, mars: 3.711]

  @type t :: :earth | :moon | :mars

  @spec gravity(t()) :: float()
  def gravity(planet) do
    Keyword.fetch!(@gravity, planet)
  end

  @spec planets() :: [t()]
  def planets do
    Keyword.keys(@gravity)
  end

  @spec parse(String.t()) :: {:ok, t()} | {:error, :unknown_planet}
  def parse(string) do
    planet_list = planets()

    case Enum.find(planet_list, fn planet -> string == Atom.to_string(planet) end) do
      nil ->
        {:error, :unknown_planet}

      planet ->
        {:ok, planet}
    end
  end
end
