# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter application (`me_hero`) targeting Android, iOS, macOS, Linux, Web, and Windows. Currently a starter template.

## FVM — Critical

This project uses **FVM (Flutter Version Management)**. **Always use `fvm flutter` and `fvm dart` instead of `flutter` and `dart` directly.**

- Flutter version: 3.41.5 (pinned in `.fvmrc`)
- SDK path for tooling: `.fvm/flutter_sdk`

## Common Commands

```bash
fvm flutter run                        # Run the app
fvm flutter build macos                # Build for macOS (or: apk, ios, web, linux, windows)
fvm flutter test                       # Run all tests
fvm flutter test test/widget_test.dart # Run a single test file
fvm flutter analyze                    # Run static analysis
fvm flutter pub get                    # Fetch dependencies
```

## Architecture

Currently a single-file app (`lib/main.dart`) with no state management, routing, or code generation. As the project grows, architecture decisions should be documented here.

## Linting

Uses `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`.
