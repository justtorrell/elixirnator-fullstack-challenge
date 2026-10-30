defmodule ElixiratorChallengeWeb.MissionComponents do
  @moduledoc "Function components for the mission fuel calculator page."
  use Phoenix.Component

  import ElixiratorChallengeWeb.CoreComponents

  alias ElixiratorChallenge.Data.Planet

  attr :index, :integer, required: true
  attr :step, :map, required: true
  attr :error, :string, default: nil

  def flight_step_row(assigns) do
    ~H"""
    <div id={"step-#{@index}"} class="flex gap-2 items-end">
      <.input
        type="select"
        id={"step-#{@index}-action"}
        name={"mission[flight_path][#{@index}][action]"}
        value={@step["action"]}
        options={action_options()}
      />
      <.input
        type="select"
        id={"step-#{@index}-planet"}
        name={"mission[flight_path][#{@index}][planet]"}
        value={@step["planet"]}
        options={planet_options()}
      />
      <.button
        type="button"
        id={"remove-step-#{@index}"}
        phx-click="remove_step"
        phx-value-index={@index}
      >
        Remove
      </.button>
      <p :if={@error} class="text-error text-sm">{@error}</p>
    </div>
    """
  end

  attr :result, :any, required: true

  def fuel_summary(%{result: {:ok, %{total_fuel: total, steps: steps}}} = assigns) do
    assigns = assign(assigns, total: total, steps: steps)

    ~H"""
    <div id="fuel-summary" class="mt-6">
      <p id="total-fuel" class="text-2xl font-bold">{@total} kg</p>

      <table class="table">
        <thead>
          <tr>
            <th>Step</th>
            <th>Action</th>
            <th>Planet</th>
            <th>Fuel</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={{%{step: step, fuel: fuel}, index} <- Enum.with_index(@steps)}>
            <td>{index + 1}</td>
            <td>{step.action}</td>
            <td>{step.planet}</td>
            <td id={"step-fuel-#{index}"}>{fuel} kg</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  def fuel_summary(%{result: {:error, _errors}} = assigns) do
    ~H"""
    <p id="fuel-invalid" class="mt-6 text-error">
      Fix the errors above to see the fuel required
    </p>
    """
  end

  defp action_options, do: [{"Launch", "launch"}, {"Land", "land"}]

  defp planet_options do
    planets = Planet.planets()

    Enum.map(planets, fn planet ->
      value = Atom.to_string(planet)
      {String.capitalize(value), value}
    end)
  end
end
