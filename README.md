# aerobeat-feature-flow

Current AeroBeat Flow gameplay feature package.

## Repository status

`aerobeat-feature-flow` is a retained **active/current** AeroBeat v1 gameplay repo.

The current product truth for this repo is:

- **official gameplay feature:** Flow
- **official gameplay input posture:** camera-first
- **official release order:** PC community first, mobile later, VR later
- **feature-scope posture:** Flow remains current; removed peer-era wording for Dance/Step should not be reintroduced here

## Architecture role

This repo owns Flow-specific gameplay logic and feature-local workbench validation. Shared reusable gameplay/runtime contracts belong in `aerobeat-feature-core`, and authored playable content contracts belong in `aerobeat-content-core` when Flow consumes them.

## GodotEnv development flow

This repo uses the AeroBeat Phase 2 GodotEnv package convention.

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- GodotEnv cache: `.testbed/.addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local unit tests: `.testbed/tests/`
- Optional interactive/workbench scenes: `.testbed/scenes/`

The repo root is treated as the package/published boundary for downstream consumers. Day-to-day development, debugging, and validation happen from the hidden `.testbed/` workbench using the pinned OpenClaw toolchain: Godot `4.6.2 stable standard`.

### Restore dev/test dependencies

From the repo root:

```bash
cd .testbed
godotenv addons install
```

That restores this repo's current dev/test manifest into `.testbed/addons/`. The current manifest is intentionally described as a minimal bootstrap contract, not as the final long-term feature-lane dependency story.

### Open the workbench

From the repo root:

```bash
godot --editor --path .testbed
```

Use this `.testbed/` project as the canonical direct-development and flow bugfinding surface.

### Import smoke check

From the repo root:

```bash
godot --headless --path .testbed --import
```

### Run unit tests

From the repo root:

```bash
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```

### Validation notes

- `.testbed/addons.jsonc` is the only committed dev/test dependency contract.
- The current manifest now carries a minimal `aerobeat-feature-core` + GUT bootstrap for shared feature/runtime contracts. Treat that as a narrow workbench dependency truth, not the canonical full long-term dependency story for an active Flow feature repo.
- Canonical live feature-lane docs and shared runtime contracts belong in `aerobeat-feature-core`, with `aerobeat-content-core` layered in when Flow consumes authored playable content.
- Repo-local unit tests live under `.testbed/tests/`; this package no longer uses a root-level `test/` directory.
- If interactive workbench scenes are added later, place them under `.testbed/scenes/`.
- The current package shape is consumed from the repo root (`subfolder: "/"`) for downstream installs.
