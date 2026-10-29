---
st_id: ST0001
title: Setup & Plan WDD structure of NASA application
status: WIP
created: 2026-10-29
completed:
---

# ST0001: Setup & Plan WDD structure of NASA application

## Objective

Take my WDD plan on paper, express it here within the project structure and validate the code against the worker bee agent the ensure implemntation validity

## Context

I used the spec here intent/st/ST0001/elixir-full-stack-challenge.md to generate a rough worker-bee driven plan of how this will be implemented in code.

I broke down the above task into the following sections (implemented with the Do Fun Things with Big Loud Worker-bees idiom):
1 - Fuel Calculation Logic (Backend)
 - Data
    - earth_gravity: 9.807
    - moon_gravity: 1.62 
    - mars_gravity: 3.711
    - launch_multiplier: 0.042
    - launch_subtractor: 33
    - land_multiplier: 0.083
    - land_subtractor: 42
    - equipment_mass: this will depend on the mission selected
    - total fuel required: the total amount of fuel that will be required to complete that mission

    - Follow the data requirements
        - Break nouns into data structures 
 - Functions (MissionCalculations)
    - calculate_launch_fuel/2: mass * gravity * <launch_multiplier> - <launch_subtractor>
    - calculate_land_fuel/2: mass * gravity * <land_multiplier> - <land_subtractor>
    
    - Follow structural requirements:
        - Organise core by purpose
        - Shape for composition/piping
        - Keep left margin skinny
- Tests
    - We need to do validation tests for all the data. Ensure that nothing but that kind of data can be accepted and only the mutable data mutable
    - We then need to test the functions to ensure that the logic is sound. Test all the calculation functions, and validate using the data provided in the spec
    - Then after the boundary is created, we then need to test the boundary api to ensure it works as expected. Call the api as a user would

    - Follow the testing requirements
        - Simplify with common setup (fixtures - provide test data with fixtures)
        - Prime tests wth named setups

- Boundary (backend)
    - To wrap the functional core in  a generic API where we treat the errors as data
    - The boundry in this case can be a Mission - here the mission will handle the calcultion of the fuel and get the result back to us
    - calculate_total_launch_fuel/2: mass of the equipment and the gravity of the mission, then recursively call MissionCalculations.calculate_launch_fuel until the result is <= 0, creating a list of numbers containing the fuel requirements for that mission. Each time the mass of the fuel calculated will be fed into the next. We can finally add them up to get the total amount of fuel needed to complete that launch mission
    - calculate_total_land_fuel/2: like the function above, mass & gravity then recursively call MissionCalculations.calculate_land_fuel using the fuel result as the next call. Cumulatively add up the result and return the total amount needed to complete that landing mission
    - Create a GenServer for persistance of the mission
        - A mission can contain multiple launches and landings
        - You can see the log of what has trainspired in the mision and how much fuel they will cost
        - Has the ability to add future features to missions

    - Double back and create boundary tests to ensure that errors and handled as expected

    - Follow the boundary requirements:
        - use 'with' for uncertain structure composition
        - build validations and have clear error sturctures/handling

- Lifecycle
    - Determine how the missions will be started and stopped
    - Determine the supervision of the missions
    - Determine the configurtion of said supervision
    - We will be starting per-user processes with a dynamic supervisor. A user can start and stop as many missions as they want to and they all need to be monitored

- Workers
    - We seprate into workers for isolation - to isolte the missions from each other
    - If there are errors or something happens in one mission, it should not affect the whole application
    - I need to determine what workers are needed for this simple application

This is the proposed structure for the backend after looking at the spec (intent/st/ST0001/elixir-full-stack-challenge.md).

2 - Phoenix Web-Interface
    The Phoenix web interface will be treated primarily as a Boundary layer from the User to the application.

    Within this application, we will need to implement the following:
    
    - Real-time LiveView updates
        - These real-time updates are to immediately show the calculated fuel requirements for a mission as the user inputs/and adjusts their flight path (Earth, Mars, Moon) and mass
        - We need to provide a dynamic UI interactions, allowint the user to add and remove steps from their flight path/mission
            - For example:
                Launch - Earth
                Land - Moon
                Launch - Moon
                Land - Earth
        - The user should be able to add and delete steps as they please for each mission

    - User experience
        - Basic form vlidations need to be implemented for the user 
            - for example, positive numeric inputs, selection validation, etc.
        - Disply calculation results clearly, showing the totl fuel required


- Tests
    - We of course will need to test the interface to ensure that the input is valid and the exerience is plesant for the user
    - Test the forms, the layout, the validation and the ability to combine the frontend with the backend correctly (i.e. the clculation results display correctly, after being validated by the backend tests)

To complete this, we will be using test driven development to work from the ground up, ensuring that everything is validated and consistent, while following worker-bee driven design to ensure maintainability and code quality

## Acceptance

Acceptance Criteria and Acceptance Tests are RENDERED into `acceptance.md`, which is a GENERATED VIEW -- a row authored there is discarded by the next sync. The contract is canon in this thread's model, and the verbs write it: `intent ac new` and `intent at new` mint a row, `intent ac edit` and `intent at edit` reword or re-cite one, and `intent ac satisfy|unsatisfy|descope|rescope|withdraw|reinstate` and `intent at green|red|na` move its state. This cover never restates them.

---

_Generated by Intent v3 from the thread canon. Do not edit this file -- it is rendered from the model, and `intent doctor` reports any hand-edit as skew._
