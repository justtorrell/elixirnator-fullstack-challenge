---
st_id: ST0001
title: NASA fuel calculator: plan and build (one-day delivery)
status: WIP
created: 2026-10-29
completed:
---

# ST0001: NASA fuel calculator: plan and build (one-day delivery)

## Objective

Take my WDD plan on paper, express it here within the project structure and validate the code against the worker bee agent the ensure implemntation validity

## Context

I used the spec here intent/st/ST0001/elixir-full-stack-challenge.md to generate a rough worker-bee driven plan of how this will be implemented in code.

I broke down the above task into the following sections (implemented with the Do Fun Things with Big Loud Worker-bees idiom):
1 - Fuel Calculation Logic (Backend)
 - Data
    - Follow the data requirements
        - Break nouns into data structures
    - The nouns in the spec are:
        - Planet: a planet we can launch from or land on, and its gravity
            - Earth: 9.807
            - Moon: 1.62
            - Mars: 3.711
        - FlightStep: a single step in the flight path, made up of an action (:launch or :land) and a planet
        - Mission: the equipment mass (entered by the user) and the flight path (a list of FlightSteps in flight order)
    - The formula numbers (launch: 0.042 and 33, land: 0.033 and 42) are not nouns, so they live in MissionCalculations as module attributes
    - The total fuel required is not input data - it is the result we calculate from a Mission
 - Functions (MissionCalculations)
    - calculate_launch_fuel/2: mass * gravity * 0.042 - 33 (rounded down)
    - calculate_land_fuel/2: mass * gravity * 0.033 - 42 (rounded down)
    - calculate_total_launch_fuel/2: mass and gravity, then recursively call calculate_launch_fuel, feeding each fuel result in as the next mass, until the result is <= 0. Add the results up to get the total fuel for that launch (including the fuel needed to carry its own fuel)
    - calculate_total_land_fuel/2: like the function above, but recursively calling calculate_land_fuel. Returns the total fuel for that landing
    - calculate_step_fuel/2: takes a mass and a FlightStep, looks up the planet's gravity and calls calculate_total_launch_fuel or calculate_total_land_fuel depending on the action. This is what links a step to the right calculation
    - calculate_mission_fuel/2: calculates the fuel for the entire mission from start to finish. There is no refuelling, so when the ship launches it is carrying the fuel for every step, and at the last step it carries only the equipment plus the fuel for that final step. Each step depends on how much fuel the later steps need, and the last step is the only one we can calculate straight away, so we start there and work backwards:
        - Reverse the flight path and start with fuel_so_far = 0
        - For each step, the mass is equipment_mass + fuel_so_far. Call calculate_step_fuel with that mass and add the result to fuel_so_far
        - After the first step of the flight (the last one we process), fuel_so_far is the total fuel for the mission
        - It also returns the fuel for each step in flight order, so we can show a per-step breakdown
        - Summing each step on its own with just the equipment mass gives the wrong answer (Apollo 11: 36778 instead of 51898)
    - These are pure functions, so they live in the functional core, not the boundary. The core trusts its input - validation happens in the boundary

    - Follow structural requirements:
        - Organise core by purpose
        - Shape for composition/piping
        - Keep left margin skinny
- Tests
    - Data tests: the structures have the right shape (required keys), and planet names parse into known planets only (e.g. "earth" becomes :earth, "pluto" is rejected)
    - Function tests: test all the calculation functions against the numbers in the spec
        - calculate_land_fuel(28801, 9.807) is 9278
        - calculate_total_land_fuel(28801, 9.807) is 13447 (9278 + 2960 + 915 + 254 + 40)
        - calculate_mission_fuel for the three spec missions: Apollo 11 is 51898, Mars is 33388, Passenger Ship is 212161
        - Edge cases: an empty flight path is 0, a single step mission, and a mass so small that the first result is already <= 0
    - Boundary tests: call the api as a user would and check the errors come back as data - zero or negative mass, text instead of a number, an unknown planet, an unknown action

    - Follow the testing requirements
        - Simplify with common setup (fixtures - provide the three spec missions as test data with fixtures)
        - Prime tests with named setups

- Boundary (backend)
    - To wrap the functional core in a generic API where we treat the errors as data
    - The boundary is an API module (Missions). Mission is a data structure, so it does not do any calculating itself
    - Missions validates the input (positive equipment mass, known actions and planets) and delegates the calculation to MissionCalculations.calculate_mission_fuel/2, returning {:ok, result} or {:error, reason}
    - The result holds the total fuel and the fuel for each step (the mission log), so the UI can show both
    - This is the only place the rules for valid input live, so the web layer shows these errors instead of checking the same rules again

    - Double back and create boundary tests to ensure that errors are handled as expected

    - Follow the boundary requirements:
        - use 'with' for uncertain structure composition
        - build validations and have clear error structures/handling

- Lifecycle
    - The spec only needs us to calculate one flight path live, with no database, so we don't need to start or supervise any processes of our own
    - Each user's LiveView is its own process, started and supervised by Phoenix, and it holds that user's mission (mass and flight path) in its assigns
    - The application supervision tree stays as Phoenix generated it

- Workers
    - No custom workers are needed. Isolation comes from LiveView: every user session is a separate process, so if something goes wrong in one user's mission it does not affect anyone else or the rest of the application
    - The calculation is quick and pure, so there is nothing to move into a background worker
    - If we later need missions that outlive a session (saving them, or several missions per user), a GenServer per mission under a DynamicSupervisor is where this would go

This is the proposed structure for the backend after looking at the spec (intent/st/ST0001/elixir-full-stack-challenge.md).

2 - Phoenix Web-Interface
    The Phoenix web interface will be treated primarily as a Boundary layer from the User to the application.

    Within this application, we will need to implement the following:

    - Real-time LiveView updates
        - These real-time updates are to immediately show the calculated fuel requirements for a mission as the user inputs/adjusts their flight path (Earth, Mars, Moon) and mass
        - We need to provide dynamic UI interactions, allowing the user to add and remove steps from their flight path/mission
            - For example:
                Launch - Earth
                Land - Moon
                Launch - Moon
                Land - Earth
        - The user should be able to add and delete steps as they please for each mission
        - Every change recalculates through the Missions boundary, so the LiveView itself stays thin: parse the form, call the boundary, show the result

    - User experience
        - Basic form validations need to be implemented for the user
            - for example, positive numeric inputs, selection validation, etc.
            - The LiveView only turns the form strings into numbers and planets/actions. The rules themselves live in the Missions boundary, and the LiveView shows the errors it returns next to the right field
            - There is no Ecto in the project, so the form uses to_form/2 with plain maps
        - Display calculation results clearly, showing the total fuel required and the fuel for each step

    - LiveView structure
        - Use function components for the repeated parts: a flight step row (action, planet, remove button) and the results panel
        - Keep the mission in the LiveView's assigns, as the flight path is a short list edited inside one form

- Tests
    - We of course will need to test the interface to ensure that the input is valid and the experience is pleasant for the user
    - Test the forms, the validation messages, adding and removing steps, and that the frontend and backend combine correctly (i.e. the three spec missions show the right totals in the UI, after being validated by the backend tests)

To complete this, we will be using test driven development to work from the ground up, ensuring that everything is validated and consistent, while following worker-bee driven design to ensure maintainability and code quality

## Work Packages

| WP    | Title                                                               | Size | Status      |
| ----- | ------------------------------------------------------------------- | ---- | ----------- |
| WP-01 | Design breakdown (design.md: words to pseudo to tasks to checklist) | S    | Done        |
| WP-02 | Acceptance contract (ACs and ATs)                                   | S    | Done        |
| WP-03 | WDD project map and module skeleton                                 | S    | Done        |
| WP-04 | Core: data structures and MissionCalculations                       | S    | Not Started |
| WP-05 | Boundary: Missions API with validation                              | S    | Not Started |
| WP-06 | LiveView: mission form, live results and tests                      | S    | Not Started |
| WP-07 | Wrap-up: worker-bee and critic checks on the finished code          | S    | Not Started |

## Acceptance

Acceptance Criteria and Acceptance Tests are RENDERED into `acceptance.md`, which is a GENERATED VIEW -- a row authored there is discarded by the next sync. The contract is canon in this thread's model, and the verbs write it: `intent ac new` and `intent at new` mint a row, `intent ac edit` and `intent at edit` reword or re-cite one, and `intent ac satisfy|unsatisfy|descope|rescope|withdraw|reinstate` and `intent at green|red|na` move its state. This cover never restates them.

---

_Generated by Intent v3 from the thread canon. Do not edit this file -- it is rendered from the model, and `intent doctor` reports any hand-edit as skew._
