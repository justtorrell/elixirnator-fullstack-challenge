# NASA Fuel Calculator

Take-home task for the Elixirator Full-stack engineer application: https://hi-elixirator.notion.site/elixir-challenge

A Phoenix LiveView app that calculates the fuel a spacecraft needs for a flight path of launches and landings on Earth, the Moon and Mars. You enter the equipment mass, build the flight path step by step, and the total fuel updates as you type.

## Running it

Requires Elixir and Erlang/OTP (built with Elixir 1.20.4 on OTP 29; `mix.exs` needs Elixir ~> 1.17). No database is needed.

```bash
cd elixirator_challenge
mix setup        # fetch deps, install and build assets
mix phx.server   # then open http://localhost:4000
```

The page opens with the Apollo 11 mission loaded, showing 51898 kg.

## Running the tests

```bash
cd elixirator_challenge
mix test
```

42 tests cover:

- **Data**: planet gravity and parsing, flight step and mission structs.
- **Core**: the fuel formulas, the spec's worked examples (9278 and 13447 kg for landing Apollo 11 on Earth) and all three example missions.
- **Boundary**: turning form input into a mission, and rejecting bad input with a message per field or step.
- **LiveView**: the page loads with a total, steps can be added and removed, every change recalculates, and invalid input shows errors instead of a total.

Code quality checks, all clean: `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix credo --strict`.

## Example missions

| Mission | Flight path | Equipment mass | Total fuel |
| --- | --- | --- | --- |
| Apollo 11 | launch Earth, land Moon, launch Moon, land Earth | 28801 kg | 51898 kg |
| Mars | launch Earth, land Mars, launch Mars, land Earth | 14606 kg | 33388 kg |
| Passenger Ship | launch Earth, land Moon, launch Moon, land Mars, launch Mars, land Earth | 75432 kg | 212161 kg |

All three are covered by tests. To try one by hand, set the mass and the steps on the page.

## How the fuel is calculated

Each step uses the formula from the brief, rounded down:

- **Launch:** `mass * gravity * 0.042 - 33`
- **Land:** `mass * gravity * 0.033 - 42`

The fuel itself has weight, so each step's fuel is recalculated on the fuel until the extra amount is zero or negative.

A mission is calculated **in reverse**. Fuel for a later step has to be carried through every step before it, so the last step is calculated first, on the equipment mass alone. Each earlier step is then calculated on the equipment mass plus all the fuel needed after it. This is one pass, using `Enum.map_reduce/3` over the reversed flight path.

## How the code is organised

The app follows Worker-Bee Driven Design (WDD): plain data, pure functions, and a boundary that is the only way in. The layers are declared in `elixirator_challenge/.wdd_project_map.yaml`, and `mix wdd.validate` passes.

| Layer | Where | What |
| --- | --- | --- |
| Data | `lib/elixirator_challenge/data/` | `Planet` (gravity, supported planets, parsing), `FlightStep` and `Mission` structs |
| Core | `lib/elixirator_challenge/core/mission_calculations.ex` | Pure fuel calculations: per step, per mission, with the per-step breakdown |
| Boundary | `lib/elixirator_challenge/boundary/missions.ex` | `Missions.calculate/1`: takes form params as strings, validates them, calls the core, returns `{:ok, result}` or `{:error, errors}` |
| Web | `lib/elixirator_challenge_web/live/mission_live.ex`, `components/mission_components.ex` | The LiveView and its function components |
| Tests | `test/` | Mirrors the `lib/` layout, with shared mission fixtures in `test/support/fixtures/` |

## Design decisions

- **No database.** Nothing needs to be stored, which the brief allows.
- **Validation lives in one place.** The boundary checks the mass and every step, and returns errors keyed by field and by step index. The LiveView only reshapes the form data and shows what the boundary returns, so the rules are never duplicated.
- **The LiveView is thin.** Every event updates the form params, then calls one helper that recalculates and assigns the result.
- **The planet list is defined once.** The dropdown is built from `Planet.planets/0`, so adding a planet to the gravity table adds it to the UI.
- **An empty flight path is valid** and needs 0 kg of fuel.
- **No LiveView streams.** The flight path is a handful of rows rebuilt from the params on every change, and the calculation needs the full list each time, so a stream would add complexity without saving anything.
- **No two-phase mount.** There is nothing to subscribe to or start once the socket connects.
- **No GenServer or other process.** Each LiveView already runs in its own process and holds its own state, and the calculation is a pure function.

## How the work was planned

The work was planned and tracked with [Intent](https://github.com/matthewsinclair/intent) as one steel thread, `ST0001`, in `intent/st/ST0001/`:

- `info.md`: the goal and context
- `design.md`: the one-day plan, from words to pseudocode to tasks
- `acceptance.md`: six acceptance criteria and the three acceptance test files that prove them
- `WP/`: seven work packages, from design through core, boundary and LiveView to wrap-up

Commit messages reference the thread and work package, e.g. `ST0001/04: C3-C6 MissionCalculations`.
