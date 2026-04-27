# AeroBeat Flow Feature

This is the official codebase for AeroBeats Flow gameplay style.

A **Feature** contains the pure gameplay logic for a specific mode (e.g., Boxing, Flow, Step). It is designed to be modular and plugged into an **Assembly**.

## 📋 Repository Details

*   **Type:** Feature (Gameplay Logic)
*   **License:** **GNU GPLv3** (Strict Copyleft)
*   **Dependencies:**
    *   `aerobeat-feature-core` (Canonical gameplay/runtime contract)
    *   `aerobeat-content-core` (Required when the feature consumes authored Songs, Charts, Sets, or Workouts)
    *   `aerobeat-vendor-*` (Allowed)

## GodotEnv development flow

This repo uses the AeroBeat GodotEnv package convention.

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- GodotEnv cache: `.testbed/.addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local unit tests: `.testbed/tests/`

The repo root remains the package/published boundary for downstream consumers. Day-to-day development, debugging, and validation happen from the hidden `.testbed/` workbench using the pinned OpenClaw toolchain: Godot `4.6.2 stable standard`.

### Restore dev/test dependencies

From the repo root:

```bash
cd .testbed
godotenv addons install
```

That restores this repo's current dev/test manifest into `.testbed/addons/`. In the long-term lane model, Feature repos should describe themselves in terms of `aerobeat-feature-core` plus any adjacent contracts they actually consume, especially `aerobeat-content-core` for playable authored content.

### Open the workbench

From the repo root:

```bash
godot --editor --path .testbed
```

Use this `.testbed/` project as the canonical direct-development and bugfinding surface for feature work.

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

- `.testbed/addons.jsonc` is the committed dev/test dependency contract.
- The current manifest still pins the transition-era `aerobeat-core` package key to `v0.1.0` alongside GUT `main`. Treat that as bootstrap-state drift, not the canonical long-term repo-boundary story.
- Canonical lane ownership for live docs is `aerobeat-feature-core`, plus `aerobeat-content-core` when the feature consumes authored playable content.
- Repo-local unit tests live under `.testbed/tests/`; this repo's current package payload is rooted at `/`, so the workbench does not ship a `.testbed/src` bridge for this subset.
- The current package shape is consumed from the repo root (`subfolder: "/"`) for downstream installs.
