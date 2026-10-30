defmodule ElixiratorChallengeWeb.MissionLiveTest do
  use ElixiratorChallengeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import ElixiratorChallenge.MissionFixtures

  describe "mount" do
    test "success: shows the Apollo 11 mission and its total on load", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#mission-form")
      assert has_element?(view, "#total-fuel", "51898")
    end

    test "success: shows each step's fuel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#step-fuel-0", "32988")
      assert has_element?(view, "#step-fuel-3", "13447")
    end
  end

  describe "flight path" do
    test "success: shows one row per step of the flight path", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#step-0")
      assert has_element?(view, "#step-1")
      assert has_element?(view, "#step-2")
      assert has_element?(view, "#step-3")
      refute has_element?(view, "#step-4")
    end

    test "success: adding a step adds a row and updates the total", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#add-step") |> render_click()

      assert has_element?(view, "#step-4")
      assert has_element?(view, "#total-fuel", "108119")
    end

    test "success: removing a step removes its row and updates the total", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#remove-step-3") |> render_click()

      refute has_element?(view, "#step-3")
      assert has_element?(view, "#total-fuel", "26011")
    end
  end

  describe "live recalculation" do
    test "success: shows the Mars total when the Mars mission is entered", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      %{mission_params: params, expected_total: total} = mars(%{})

      view
      |> element("#mission-form")
      |> render_change(%{"mission" => form_params(params)})

      assert has_element?(view, "#total-fuel", Integer.to_string(total))
    end
  end

  describe "validation" do
    test "failure: an invalid mass shows the error and hides the total", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      %{mission_params: params} = apollo_11(%{})
      invalid = Map.put(params, "equipment_mass", "-5")

      view
      |> element("#mission-form")
      |> render_change(%{"mission" => form_params(invalid)})

      assert has_element?(view, "#mission-form", "must be a positive number")
      assert has_element?(view, "#fuel-invalid")
      refute has_element?(view, "#total-fuel")
    end

    test "failure: an unknown planet shows the step's error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      %{mission_params: params} = apollo_11(%{})
      invalid = put_in(params, ["flight_path", Access.at(1), "planet"], "saturn")

      view
      |> element("#mission-form")
      |> render_change(%{"mission" => form_params(invalid)})

      assert has_element?(view, "#step-1", "unknown planet")
      assert has_element?(view, "#fuel-invalid")
    end
  end

  defp form_params(params) do
    steps =
      params["flight_path"]
      |> Enum.with_index()
      |> Map.new(fn {step, index} -> {Integer.to_string(index), step} end)

    Map.put(params, "flight_path", steps)
  end
end
