defmodule ElixiratorChallenge.Data.PlanetTest do
  use ExUnit.Case, async: true

  alias ElixiratorChallenge.Data.Planet

  describe "gravity/1" do
    test "success: returns the gravity for each supported planet" do
      assert Planet.gravity(:earth) == 9.807
      assert Planet.gravity(:moon) == 1.62
      assert Planet.gravity(:mars) == 3.711
    end
  end

  describe "planets/0" do
    test "success: lists the supported planets" do
      assert Planet.planets() == [:earth, :moon, :mars]
    end
  end

  describe "parse/1" do
    test "success: parse a known planet name into its atom" do
      assert Planet.parse("mars") == {:ok, :mars}
      assert Planet.parse("earth") == {:ok, :earth}
      assert Planet.parse("moon") == {:ok, :moon}
    end

    test "failure: rejects an unknown planet name" do
      assert Planet.parse("jupiter") == {:error, :unknown_planet}
    end
  end
end
