# AeroBeat Feature Template

This is the official template for creating a **Feature** repository within the AeroBeat ecosystem.

A **Feature** contains the pure gameplay logic for a specific mode (e.g., Boxing, Flow, Step). It is designed to be modular and plugged into an **Assembly**.

## 📋 Repository Details

*   **Type:** Feature (Gameplay Logic)
*   **License:** **GNU GPLv3** (Strict Copyleft)
*   **Dependencies:**
    *   `aerobeat-core` (Required)
    *   `aerobeat-vendor-*` (Allowed)

## 🚀 Getting Started

1.  **Clone your new repo:**
    ```bash
    git clone https://github.com/YourOrg/aerobeat-feature-custom.git
    ```
2.  **Run Setup:**
    Initialize the testbed environment.
    ```bash
    python setup_dev.py
    ```
3.  **Open in Godot:**
    Import the `project.godot` file located inside the `.testbed/` folder.

> **Note:** Features are libraries, not standalone games. We use a "Testbed" project (a minimal Godot project in a hidden folder) to run and debug the feature in isolation.

## 🧪 Testing & CI/CD

This template comes pre-configured with **GUT (Godot Unit Test)** workflows.

*   **Local Testing:** Run tests via the "GUT" panel in the Godot Editor (inside the Testbed).
*   **CI/CD:** A GitHub Action (`.github/workflows/gut_ci.yml`) runs automatically on every push to `main`.
*   **Requirement:** 100% Code Coverage is enforced.

## 📂 Structure

*   `src/` - The actual feature logic (GDScript). This is what gets distributed.
*   `test/` - Unit tests.
*   `.testbed/` - A local-only Godot project used to run/debug the feature.