defmodule ElixiratorChallenge.MissionFixtures do
  @moduledoc """
  Test Layer: the different mission fixtures that will be tested and validated against
  We have one function per spec mission
  """

  @doc """
  Apollo 11 - Flight Path: launch earth, land moon, launch moon, land earth
  """
  def apollo_11(_context) do
    %{
      # input will be received by a form from the user in string format
      mission_params: %{
        "equipment_mass" => "28801",
        "flight_path" => [
          %{"action" => "launch", "planet" => "earth"},
          %{"action" => "land", "planet" => "moon"},
          %{"action" => "launch", "planet" => "moon"},
          %{"action" => "land", "planet" => "earth"}
        ]
      },
      expected_total: 51_898
    }
  end

  @doc """
  Mars - Flight Path: launch earth, land mars, launch mars, land earth
  """
  def mars(_context) do
    %{
      mission_params: %{
        "equipment_mass" => "14606",
        "flight_path" => [
          %{"action" => "launch", "planet" => "earth"},
          %{"action" => "land", "planet" => "mars"},
          %{"action" => "launch", "planet" => "mars"},
          %{"action" => "land", "planet" => "earth"}
        ]
      },
      expected_total: 33_388
    }
  end

  @doc """
  Passenger Ship - Flight Path: launch earth, land moon, launch moon, land mars, launch mars, land earth
  """
  def passenger_ship(_context) do
    %{
      mission_params: %{
        "equipment_mass" => "75432",
        "flight_path" => [
          %{"action" => "launch", "planet" => "earth"},
          %{"action" => "land", "planet" => "moon"},
          %{"action" => "launch", "planet" => "moon"},
          %{"action" => "land", "planet" => "mars"},
          %{"action" => "launch", "planet" => "mars"},
          %{"action" => "land", "planet" => "earth"}
        ]
      },
      expected_total: 212_161
    }
  end
end
