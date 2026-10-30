defmodule ElixiratorChallenge.Data.FlightStepTest do
  use ExUnit.Case, async: true

  alias ElixiratorChallenge.Data.FlightStep

  describe "parse_action/1" do
    test "success: valid action strings give the :ok tuple" do
      assert FlightStep.parse_action("land") == {:ok, :land}
      assert FlightStep.parse_action("launch") == {:ok, :launch}
    end

    test "failure: invalid action strings return an :error tuple" do
      assert FlightStep.parse_action("orbit") == {:error, :unknown_action}
    end
  end

  describe "%FlightStep{}" do
    test "failure: requires an action and a planet" do
      assert_raise ArgumentError, fn -> struct!(FlightStep, action: :launch) end
    end
  end
end
