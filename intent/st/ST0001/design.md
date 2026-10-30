---
st_id: ST0001
title: Setup & Plan WDD structure of NASA application
---

# ST0001: Setup & Plan WDD structure of NASA application -- Design

A one-day delivery plan for the whole challenge (`elixir-full-stack-challenge.md`), built from the plan in `info.md`. Every decision is made here so the day is spent writing tests and code, not deciding. Total budget: about 7.5 hours.

| Block     | What                                                     | Time      |
| --------- | -------------------------------------------------------- | --------- |
| Setup     | Intent admin, WDD map, module skeleton, test fixtures    | 45 min    |
| Core      | Data structures and `MissionCalculations`                | 2 hours   |
| Boundary  | `Missions` API with validation                           | 1 hour    |
| LiveView  | Form, add/remove steps, live results, validation, tests  | 3 hours   |
| Wrap-up   | Format, test, validate, commit, close the thread         | 30 min    |

## Work package order

Work packages run in number order.

| WP        | Block    | Design tasks  |
| --------- | -------- | ------------- |
| ST0001/01 | Design   | this document |
| ST0001/02 | Design   | ACs and ATs   |
| ST0001/03 | Setup    | S1-S3         |
| ST0001/04 | Core     | C1-C6         |
| ST0001/05 | Boundary | B1-B3         |
| ST0001/06 | LiveView | L1-L6         |
| ST0001/07 | Wrap-up  | W1-W3         |

# Words to pseudo

## Layers and files

| WDD layer  | Path                                          | Modules                                              |
| ---------- | --------------------------------------------- | ---------------------------------------------------- |
| Data       | `lib/elixirator_challenge/data/`              | `Data.Planet`, `Data.FlightStep`, `Data.Mission`     |
| Functions  | `lib/elixirator_challenge/core/`              | `Core.MissionCalculations`                           |
| Boundary   | `lib/elixirator_challenge/boundary/`          | `Boundary.Missions`                                  |
| Web        | `lib/elixirator_challenge_web/live/`          | `MissionLive`, `MissionComponents`                   |
| Lifecycle  | `lib/elixirator_challenge/application.ex`     | unchanged                                            |
| Workers    | none                                          | none (each LiveView is its own isolated process)     |
| Tests      | `test/`                                       | one test file per module, plus shared fixtures       |

All module names are prefixed with `ElixiratorChallenge.` (`ElixiratorChallengeWeb.` for the web layer).

## Data

```elixir
# Data.Planet -- the planets and their gravity. Planets are atoms.
@gravity %{earth: 9.807, moon: 1.62, mars: 3.711}

gravity(:earth)   #=> 9.807
planets()         #=> [:earth, :moon, :mars]
parse("earth")    #=> {:ok, :earth}
parse("pluto")    #=> {:error, :unknown_planet}
# parse/1 looks the string up in the known planets; never String.to_atom/1 on user input

# Data.FlightStep -- one step of the flight path
@enforce_keys [:action, :planet]
defstruct [:action, :planet]          # action :: :launch | :land
parse_action("launch")  #=> {:ok, :launch}
parse_action("orbit")   #=> {:error, :unknown_action}

# Data.Mission -- what the user is planning
@enforce_keys [:equipment_mass, :flight_path]
defstruct [:equipment_mass, :flight_path]   # flight_path :: [FlightStep.t()] in flight order
```

## Functions

`Core.MissionCalculations` is pure and data-first. It trusts its input, because the boundary has already validated it.

```elixir
@launch {0.042, 33}
@land {0.033, 42}

calculate_launch_fuel(mass, gravity)  # floor(mass * gravity * 0.042 - 33)
calculate_land_fuel(mass, gravity)    # floor(mass * gravity * 0.033 - 42)

calculate_total_launch_fuel(mass, gravity):
  fuel = calculate_launch_fuel(mass, gravity)
  if fuel <= 0, do: 0, else: fuel + calculate_total_launch_fuel(fuel, gravity)

calculate_total_land_fuel(mass, gravity)   # same shape, using calculate_land_fuel

calculate_step_fuel(mass, %FlightStep{action: :launch, planet: p}) -> calculate_total_launch_fuel(mass, Planet.gravity(p))
calculate_step_fuel(mass, %FlightStep{action: :land, planet: p})   -> calculate_total_land_fuel(mass, Planet.gravity(p))

calculate_mission_fuel(%Mission{equipment_mass: mass, flight_path: path}):
  {step_fuels, total} =
    path
    |> Enum.reverse()
    |> Enum.map_reduce(0, fn step, fuel_so_far ->
      fuel = calculate_step_fuel(mass + fuel_so_far, step)
      {%{step: step, fuel: fuel}, fuel_so_far + fuel}
    end)

  %{total_fuel: total, steps: Enum.reverse(step_fuels)}
```

`floor/1` is `Kernel.floor/1`, which returns an integer. Use multiple function heads on the action for `calculate_step_fuel/2`, not an `if`.

Taking a `%Mission{}` (rather than mass and path separately) keeps `calculate_mission_fuel` at arity 1 and lets it pipe: `mission |> MissionCalculations.calculate_mission_fuel()`.

## Boundary

`Boundary.Missions` is the one place the input rules live. It takes the form's params as they arrive (strings), parses and validates them, and calls the core. The LiveView passes params straight through and shows whatever comes back.

```elixir
calculate(%{"equipment_mass" => "28801", "flight_path" => [%{"action" => "launch", "planet" => "earth"}, ...]})
#=> {:ok, %{total_fuel: 51898, steps: [%{step: %FlightStep{}, fuel: 32988}, ...]}}

calculate(%{"equipment_mass" => "-5", "flight_path" => [%{"action" => "launch", "planet" => "pluto"}]})
#=> {:error, %{equipment_mass: "must be a positive number", flight_path: %{0 => "unknown planet"}}}

calculate(params):
  mass_result = parse_mass(params["equipment_mass"])
  path_result = parse_flight_path(params["flight_path"] || [])

  with {:ok, mass} <- mass_result,
       {:ok, path} <- path_result do
    {:ok, MissionCalculations.calculate_mission_fuel(%Mission{equipment_mass: mass, flight_path: path})}
  else
    _ -> {:error, collect_errors(mass_result, path_result)}
  end
```

- **Mass:** parsed with `Float.parse/1`, so `"28801"` and `"28801.5"` both work. Text, empty input, zero or a negative number gives `"must be a positive number"`.
- **Each step:** the action through `FlightStep.parse_action/1`, the planet through `Planet.parse/1`. Errors are keyed by the step's position.
- **Empty flight path:** valid, with a total of 0.
- **Errors are collected for every field,** not just the first one, so the form can show all of them at once. That's why both results are computed before the `with`.

## Web

- **Route:** `live "/", MissionLive` replaces `get "/", PageController, :home` (delete the page controller, its template and its test).
- **`MissionLive` state:**
  - `:equipment_mass` (string)
  - `:flight_path`, a list of `%{"action" => _, "planet" => _}` maps
  - `:result`, either `{:ok, map}` or `{:error, errors}`
- **`mount/3`:** starts with the Apollo 11 path and mass already filled in, so the page shows a real result on first load. No `connected?` work is needed, because nothing is subscribed or started.
- **Events.** Every handler updates the state, then calls one private `recalculate/1`, which does `Missions.calculate/1` and assigns `:result`.
  - `"validate"` (`phx-change` on the form): reads the mass and the steps from the params. A form submits the steps as a map keyed `"0"`, `"1"` and so on, so sort them by index into a list.
  - `"add_step"`: appends `%{"action" => "launch", "planet" => "earth"}`.
  - `"remove_step"` with `%{"index" => i}`: deletes that step.
- **`MissionComponents` function components (each with typed `attr`):**
  - `flight_step_row/1`: the action select, planet select and remove button for one step, plus that step's error.
  - `fuel_summary/1`: the total fuel in large text, and a table of each step with its fuel. When the input is invalid, it shows "Fix the errors above to see the fuel required" instead.
- **Form:** `to_form/2` over a plain map, using `<.input>` from `core_components.ex` with `type="number"` for the mass and `type="select"` for the action and planet. DaisyUI classes come with the generated components.

## Tests

- **Fixtures:** `test/support/fixtures/mission_fixtures.ex` holds the three spec missions as both `%Mission{}` structs and form params, with their expected totals. Load them in tests with named setups (`setup :apollo_11`).

| Fixture          | Flight path                                                              | Mass  | Total  |
| ---------------- | ------------------------------------------------------------------------ | ----- | ------ |
| `apollo_11`      | launch earth, land moon, launch moon, land earth                         | 28801 | 51898  |
| `mars`           | launch earth, land mars, launch mars, land earth                         | 14606 | 33388  |
| `passenger_ship` | launch earth, land moon, launch moon, land mars, launch mars, land earth | 75432 | 212161 |

- **Unit values from the spec's formulas** (mass 28801 on Earth):

| Function                                      | Expected |
| --------------------------------------------- | -------- |
| `calculate_launch_fuel(28801, 9.807)`         | 11829    |
| `calculate_land_fuel(28801, 9.807)`           | 9278     |
| `calculate_total_launch_fuel(28801, 9.807)`   | 19772    |
| `calculate_total_land_fuel(28801, 9.807)`     | 13447    |
| `calculate_total_land_fuel(100, 1.62)`        | 0 (first result is already negative) |

# Pseudo to tasks

Each task is test-first: write the failing test, make it pass, tick it off. Times are targets; if a task runs well over, take the simplest version that passes and move on.

## Setup (45 min)

| #  | Task                                                                                         | Time   |
| -- | -------------------------------------------------------------------------------------------- | ------ |
| S1 | Intent admin (Claude): retitle ST0001, add the build WPs, add the spec ACs                   | 10 min |
| S2 | `.wdd_project_map.yaml` (Claude drafts) and empty modules with `@moduledoc` for each layer (you) | 20 min |
| S3 | `MissionFixtures` with the three spec missions and named setups                              | 15 min |

## Core (2 hours)

| #  | Task                                                                                     | Test against                                   | Time   |
| -- | ---------------------------------------------------------------------------------------- | ---------------------------------------------- | ------ |
| C1 | `Planet.gravity/1`, `planets/0`, `parse/1`                                               | the gravity table; `"pluto"` rejected          | 20 min |
| C2 | `FlightStep` struct and `parse_action/1`; `Mission` struct                               | `"orbit"` rejected; missing keys raise         | 20 min |
| C3 | `calculate_launch_fuel/2`, `calculate_land_fuel/2`                                       | 11829, 9278                                    | 15 min |
| C4 | `calculate_total_launch_fuel/2`, `calculate_total_land_fuel/2`                           | 19772, 13447, and 0 for mass 100 on the Moon   | 25 min |
| C5 | `calculate_step_fuel/2`                                                                  | launch earth 28801 is 19772                    | 10 min |
| C6 | `calculate_mission_fuel/1`                                                               | 51898, 33388, 212161; empty path is 0; step order in `steps` | 30 min |

## Boundary (1 hour)

| #  | Task                                                                          | Test against                                       | Time   |
| -- | ----------------------------------------------------------------------------- | -------------------------------------------------- | ------ |
| B1 | `Missions.calculate/1` happy path from form params                            | the three fixtures' params give their totals        | 20 min |
| B2 | Mass validation                                                               | `"0"`, `"-5"`, `"abc"`, `""` give the mass error    | 15 min |
| B3 | Step validation and collecting all errors                                     | unknown planet at index 1; bad mass and bad step together | 25 min |

## LiveView (3 hours)

| #  | Task                                                                              | Time   |
| -- | --------------------------------------------------------------------------------- | ------ |
| L1 | Route, `MissionLive` mount with Apollo 11 defaults, delete the page controller    | 30 min |
| L2 | `flight_step_row/1` and the form with mass input                                  | 30 min |
| L3 | `"add_step"` and `"remove_step"` events                                           | 25 min |
| L4 | `"validate"` event and `recalculate/1`                                            | 25 min |
| L5 | `fuel_summary/1`: total, per-step table, invalid-input message; field errors      | 30 min |
| L6 | LiveView tests: Apollo 11 total on load; enter the Mars mission and see 33388; add and remove a step changes the total; invalid mass shows the error and hides the total | 40 min |

## Wrap-up (30 min)

| #  | Task                                                                                              | Time   |
| -- | ------------------------------------------------------------------------------------------------- | ------ |
| W1 | `mix format`, `mix compile --warnings-as-errors`, `mix test`                                      | 10 min |
| W2 | `mix wdd.validate` and fix anything it flags in the mapped layers                                  | 10 min |
| W3 | Short README section (how to run, where each layer lives), satisfy the ACs, commit, `intent st done` | 10 min |

## Skip if short on time

None of these are required by the spec:

- The per-step table in `fuel_summary/1` (keep the total).
- Starting with the Apollo 11 defaults (start with one empty step instead).
- Extra styling beyond the generated DaisyUI components.
- The README section (the commit history and this design cover it).

# Task checklist

- [ ] S1 Intent admin
- [ ] S2 WDD map and skeleton
- [ ] S3 Mission fixtures
- [ ] C1 `Planet`
- [ ] C2 `FlightStep` and `Mission`
- [ ] C3 Single-application fuel functions
- [ ] C4 Total fuel per launch and landing
- [ ] C5 `calculate_step_fuel/2`
- [ ] C6 `calculate_mission_fuel/1`
- [ ] B1 `Missions.calculate/1` happy path
- [ ] B2 Mass validation
- [ ] B3 Step validation and error collection
- [ ] L1 Route and mount
- [ ] L2 Step rows and form
- [ ] L3 Add and remove steps
- [ ] L4 Live recalculation
- [ ] L5 Results and errors
- [ ] L6 LiveView tests
- [ ] W1 Format, compile, test
- [ ] W2 Worker-bee validation
- [ ] W3 README, ACs, commit, close

# Changes from info.md to review

These refine `info.md` to keep the day short. Say if you disagree with any of them.

1. **The boundary parses the form strings too, not only the LiveView.** `info.md` says the LiveView turns strings into numbers and the boundary holds the rules. But its boundary tests include "text instead of a number", which only works if the boundary sees the raw text. Having the boundary do both keeps all the input rules in one module and makes the LiveView thinner.
2. **`calculate_mission_fuel` takes a `%Mission{}` (arity 1), not `/2`.** The struct already holds the mass and the path, and this makes the function pipe-friendly.
3. **The page starts with the Apollo 11 mission filled in,** so there's a real result on first load. This is skippable.
