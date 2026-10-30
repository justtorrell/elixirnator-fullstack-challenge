defmodule ElixiratorChallengeWeb.MissionLive do
  use ElixiratorChallengeWeb, :live_view

  import ElixiratorChallengeWeb.MissionComponents

  alias ElixiratorChallenge.Boundary.Missions

  @default_params %{
    "equipment_mass" => "28801",
    "flight_path" => [
      %{"action" => "launch", "planet" => "earth"},
      %{"action" => "land", "planet" => "moon"},
      %{"action" => "launch", "planet" => "moon"},
      %{"action" => "land", "planet" => "earth"}
    ]
  }

  @new_step %{"action" => "launch", "planet" => "earth"}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_mission(socket, @default_params)}
  end

  @impl true
  def handle_event("add_step", _params, socket) do
    new_params =
      Map.update!(socket.assigns.params, "flight_path", fn path -> path ++ [@new_step] end)

    {:noreply, assign_mission(socket, new_params)}
  end

  @impl true
  def handle_event("remove_step", %{"index" => index}, socket) do
    index = String.to_integer(index)

    new_params =
      Map.update!(socket.assigns.params, "flight_path", &List.delete_at(&1, index))

    {:noreply, assign_mission(socket, new_params)}
  end

  @impl true
  def handle_event("validate", %{"mission" => mission_params}, socket) do
    {:noreply, assign_mission(socket, normalize(mission_params))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>Mission fuel calculator</.header>

      <.form for={@form} id="mission-form" phx-change="validate">
        <.input field={@form[:equipment_mass]} type="number" label="Equipment mass (kg)" />
        <.flight_step_row
          :for={{step, index} <- Enum.with_index(@params["flight_path"])}
          index={index}
          step={step}
          error={step_error(@result, index)}
        />
        <.button type="button" id="add-step" phx-click="add_step">Add step</.button>
      </.form>

      <.fuel_summary result={@result} />
    </Layouts.app>
    """
  end

  defp assign_mission(socket, params) do
    result = Missions.calculate(params)

    socket
    |> assign(
      params: params,
      result: result,
      form: to_form(params, as: :mission, errors: mass_errors(result))
    )
  end

  defp normalize(mission_params) do
    steps =
      mission_params
      |> Map.get("flight_path", %{})
      |> Enum.sort_by(fn {index, _step} -> String.to_integer(index) end)
      |> Enum.map(fn {_index, step} -> step end)

    Map.put(mission_params, "flight_path", steps)
  end

  defp mass_errors({:error, %{equipment_mass: message}}), do: [equipment_mass: {message, []}]
  defp mass_errors(_), do: []

  defp step_error({:error, %{flight_path: errors}}, index), do: Map.get(errors, index)
  defp step_error(_, _), do: nil
end
