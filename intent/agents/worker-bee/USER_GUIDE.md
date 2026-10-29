# Using the worker-bee agent

The worker-bee setup has two parts that work together:

- **The `elixir-worker-bee` subagent** is a Claude Code agent. It reviews a project against Worker-Bee Driven Design (WDD), proposes structure and scaffolds code.
- **The worker-bee toolkit** is a Mix project in `agents/worker-bee/`. It provides `mix wdd.validate`, `mix wdd.scaffold` and `mix wdd.remap`, plus the rule modules in `validation/` that define what "compliant" means.

The agent relies on the toolkit for checks you can repeat, so set up both.

## 1. Add the toolkit to your project

Copy `agents/worker-bee/` into your project. The examples below use `intent/agents/worker-bee/`. Then check that it builds on its own:

```bash
cd intent/agents/worker-bee
mix deps.get
mix test
```

## 2. Make the `mix wdd.*` tasks available in your app

In your app's `mix.exs`, add the toolkit as a dev-only path dependency. The path is relative to the app's `mix.exs`:

```elixir
defp deps do
  [
    # ...
    {:worker_bee, path: "../intent/agents/worker-bee", only: :dev, runtime: false}
  ]
end
```

Then, from the app's directory:

```bash
mix deps.get
mix help | grep wdd
```

The last command should list `mix wdd.remap`, `mix wdd.scaffold` and `mix wdd.validate`.

Don't add the toolkit's directories to `elixirc_paths` instead. Mix rejects relative paths outside the project, and the toolkit's dependencies (`yaml_elixir`, `jason`) wouldn't be loaded.

## 3. Point the agent at the toolkit

`intent claude subagents install` installs `elixir-worker-bee` globally at `~/.claude/agents/elixir-worker-bee.md`. Don't edit that file: Intent tracks it by checksum, and `sync` will hold or overwrite local edits.

Instead, create a project-level copy. In this project, it takes precedence over the global agent with the same name:

```bash
mkdir -p .claude/agents
cp ~/.claude/agents/elixir-worker-bee.md .claude/agents/elixir-worker-bee.md
```

Add this section to the copy, below "Your Expertise", and adjust the paths for your project:

```markdown
## Local Toolkit (this project)

Your supporting files live in this repo at `intent/agents/worker-bee/` (paths relative to the repo root). Read them before validating or scaffolding:

- `config/wdd_patterns.yaml` -- the WDD layer patterns and conventions.
- `validation/*_rules.ex` -- the single source of the rules for each layer (`FunctionalCoreRules`, `BoundaryRules`, `DataRules`, `TestingRules`, `LifecycleRules`); `WddValidator` routes each file to one of them by layer. Read these to know exactly what `mix wdd.validate` checks.
- `templates/*.ex.eex` -- the templates to follow when scaffolding.
- `README.md`, `USER_GUIDE.md` -- usage reference.

The toolkit is its own Mix project (`intent/agents/worker-bee/mix.exs`, with its own tests: run `mix test` there). The Elixir app lives in `<app_dir>/` and depends on it as a dev-only path dependency, so `mix wdd.validate`, `mix wdd.scaffold` and `mix wdd.remap` are available when run from inside `<app_dir>/`. The project map `.wdd_project_map.yaml` belongs in `<app_dir>/`.

Discovery (`mix wdd.validate` with no map, `mix wdd.remap`) prompts on stdin, which you cannot answer. Do not run it. Propose the layer mapping to the user instead, and once they approve it, write `.wdd_project_map.yaml` in the format `ProjectMapper.save_project_map/2` produces. Unknown `project_type` values or layer names are rejected on load. `mix wdd.validate` exits non-zero when it finds errors.
```

Start a new Claude Code session so it picks up the project agent.

## 4. Create the project map

Validation needs a `.wdd_project_map.yaml` in the app's root that says where each WDD layer lives. You can create it in either of two ways:

- **Interactively:** run `mix wdd.remap` yourself in a terminal and answer the prompts. Its suggested paths are generic placeholders such as `lib/my_app/types`, so replace them with your real ones.
- **Through the agent (recommended):** ask it to propose a map. It can't answer the interactive prompts itself.

  > Use the elixir-worker-bee agent. Read-only: scan `<app_dir>/` and propose a WDD layer map with your reasoning, plus any open questions. Do not write any files.

  Review its proposal, then ask it to write the file.

The map's format:

```yaml
project_name: "shop"
project_type: phoenix_web
wdd_layers:
  data: "lib/shop/types"
  functions: "lib/shop/core"
  boundaries: "lib/shop_web"
  lifecycles: "lib/shop/application.ex"
  workers: "lib/shop/workers"
  tests: "test"
naming_conventions:
  module_prefix: "Shop"
framework_considerations:
  - "Phoenix contexts as boundary layers"
```

Rules for the map:

- **`project_type`** must be one of `phoenix_web`, `phoenix_api`, `otp_application`, `library`, `nerves`, `umbrella`, `poncho` or `livebook`.
- **`wdd_layers` keys** must be `data`, `functions`, `boundaries`, `lifecycles`, `workers` or `tests`. Leave a layer out, or set it to `""`, if the project doesn't have it.
- **Paths** are relative to the app root. A layer can be a directory or a single file, such as `application.ex`. Matching uses whole path segments, and when layers overlap the most specific path wins, so `lib/shop_web/core` can sit inside `lib/shop_web`.
- **`root_path`** is optional. If you leave it out, paths are resolved from the directory you run `mix wdd.validate` in, which keeps the map portable.
- Files outside every mapped layer aren't checked. If there are many of them, validation suggests re-mapping.

An unknown project type or layer name, or malformed YAML, makes `mix wdd.validate` fail with a message saying what's wrong.

## 5. Validate

Run these from the app's directory:

```bash
mix wdd.validate                                      # whole project
mix wdd.validate --layer functions                    # one layer
mix wdd.validate --file lib/shop/core/pricing.ex      # one file
mix wdd.validate --output json                        # machine-readable output
mix wdd.validate --strict                             # fail on warnings too
mix wdd.validate --min-score 80.0                     # fail below a compliance score
```

Exit codes: `0` when the run passes, and `1` when there's an error-severity violation, any warning under `--strict`, or a score below `--min-score`.

## 6. Work with the agent

Name the agent in your request and describe the job. These prompts work well:

- **Review:**
  > Use the elixir-worker-bee agent to run `mix wdd.validate` in `<app_dir>/`, explain each error and warning against the rules in `validation/`, and propose fixes. Don't edit files.
- **Placement:**
  > Use the elixir-worker-bee agent: where should a new pricing calculation live in this project's WDD map, and why?
- **Scaffolding:**
  > Use the elixir-worker-bee agent to scaffold a `functional` module named `Pricing` with `mix wdd.scaffold functional Pricing --dry-run`, show me the result, then generate it if I approve.

`mix wdd.scaffold` types are `functional`, `boundary`, `data`, `worker`, `supervisor` and `component`. A `component` gets all layers. Use `--dry-run` to preview and `--force` to overwrite existing files.

The agent has Write and Edit access. Say "read-only" or "don't edit files" in your request whenever you only want analysis.

## 7. Keep it working

- **After changing the toolkit,** run `mix test` and `mix compile --warnings-as-errors` in `intent/agents/worker-bee/`.
- **After the app's structure changes,** update `.wdd_project_map.yaml`. Validation suggests this when it sees unmapped files or new `lib/` directories.
- **After `intent claude subagents sync` changes the global agent,** compare it with your project copy and carry the update over by hand.
- **Commit** `.claude/agents/elixir-worker-bee.md`, the toolkit, and `.wdd_project_map.yaml`. The toolkit's `.gitignore` already excludes `_build/`, `deps/` and the test `tmp/` directory.

## Known limitations

- Most checks are regex heuristics over source text, so treat `info` findings as suggestions.
- Interactive discovery crashes when nothing is attached to stdin, which is why the agent writes the map instead.
- `yamerl` prints deprecation warnings when it compiles on OTP 29 or later. These come from the library and don't affect results.