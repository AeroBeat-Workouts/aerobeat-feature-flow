# aerobeat-mode-flow

Current AeroBeat Flow gameplay mode package.

## Repository status

`aerobeat-mode-flow` is a retained **active/current** AeroBeat v1 gameplay mode repo.

The current product truth for this repo is:

- **official gameplay mode:** Flow
- **official gameplay input posture:** camera-first
- **official release order:** PC community first, mobile later, VR later
- **mode-scope posture:** Flow remains current; removed peer-era wording for Dance/Step should not be reintroduced here

## Architecture role

This repo owns Flow-specific gameplay logic and mode-local workbench validation. Shared reusable gameplay/runtime contracts belong in `aerobeat-mode-core`, and authored playable content contracts belong in `aerobeat-content-core` when Flow consumes them.

## Runtime package surface

- `src/flow_mode_runner.gd` implements the pure Flow v1 rule engine over mode-core `ModeRunConfig`, `ModeTickFrame`, `ModeJudgementEvent`, `ModeScoreDelta`, and `ModeRunFragment`.
- The runner consumes normalized `BodyCellInput` event rows for `left_wrist_cell_entered(cell, direction)`, `right_wrist_cell_entered(cell, direction)`, and `nose_cell_entered(cell, direction)`.
- The runner also consumes Flow `squat_enabled` and `squat_disabled` transition rows.
- Direction values follow the frozen body-cell convention: `0=up`, `1=down`, `2=right`, `3=left`, and `-1` for ambiguous or unavailable motion.
- Notes, bursts, and arcs are wrist-hit targets. Bombs and obstacles are avoidance targets; obstacle semantics use nose cell entries. Calibration session updates remain non-scoring support input.

The package stays mode-local: it does not import gameplay runner/session envelopes, clocks, fake streams, camera providers, raw landmarks, detector payloads, UI shell, or assembly code.

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

That restores this repo's current dev/test manifest into `.testbed/addons/`. The current manifest is intentionally described as a minimal bootstrap contract, not as the final long-term mode-lane dependency story.

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
godot --headless --path .testbed --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```

### Validation notes

- `.testbed/addons.jsonc` is the only committed dev/test dependency contract.
- The current manifest now carries a minimal `aerobeat-mode-core` + GUT bootstrap for shared mode/runtime contracts. Treat that as a narrow workbench dependency truth, not the canonical full long-term dependency story for an active Flow mode repo.
- Canonical live mode-lane docs and shared runtime contracts belong in `aerobeat-mode-core`, with `aerobeat-content-core` layered in when Flow consumes authored playable content.
- Repo-local unit tests live under `.testbed/tests/`; this package no longer uses a root-level `test/` directory.
- If interactive workbench scenes are added later, place them under `.testbed/scenes/`.
- The current package shape is consumed from the repo root (`subfolder: "/"`) for downstream installs.
