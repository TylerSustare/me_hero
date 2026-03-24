# AGENTS.md

This file provides foundational mandates and guidance for Gemini CLI, Antigravity, and other AI agents working in this repository.

## Core Mandate: FVM (Flutter Version Management)

**CRITICAL:** This project uses **FVM**. All Flutter and Dart commands **MUST** be prefixed with `fvm`. Never run `flutter` or `dart` directly.

- **Pinned Version:** 3.41.5 (see `.fvmrc`)
- **SDK Path:** `.fvm/flutter_sdk`

## Common Commands

Always use these via `run_shell_command`:

- **Run:** `fvm flutter run`
- **Build (macOS):** `fvm flutter build macos`
- **Test All:** `fvm flutter test`
- **Test Single:** `fvm flutter test <path_to_test>`
- **Analyze:** `fvm flutter analyze`
- **Get Dependencies:** `fvm flutter pub get`

## Project Architecture

- **Status:** Initial starter template.
- **Entry Point:** `lib/main.dart`
- **Linting:** Standard `flutter_lints` via `analysis_options.yaml`.

## Development Workflow

1. **Research:** Use `grep_search` to find widget definitions and business logic.
2. **Execution:** Always verify changes by running `fvm flutter analyze` and relevant tests.
3. **Validation:** If adding new features, add corresponding widget or unit tests in the `test/` directory.
