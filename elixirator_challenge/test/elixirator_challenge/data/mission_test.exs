defmodule ElixiratorChallenge.Data.MissionTest do
  use ExUnit.Case, async: true

  alias ElixiratorChallenge.Data.Mission

  describe "%Mission{}" do
    test "failure: requires an equipment mass and a flight path" do
      assert_raise ArgumentError, fn -> struct!(Mission, equipment_mass: 100) end
    end
  end
end
