# Repository Guidelines

## Project Structure & Module Organization

The root QML files implement the Omarchy QuickShell UI: `BarWidget.qml` provides the bar entry, `Panel.qml` owns the popup and processes, and `Model.js` contains shared presentation helpers. `manifest.json` describes the Omarchy plugin. The local bridge lives in `bin/`: `thunderbird-mail-checker` is the Python implementation and `native-host` is its shell launcher. Thunderbird extension sources, locales, and the built XPI are under `thunderbird/`. Protocol integration tests are in `tests/protocol-test.sh`; `preview.png` is the marketplace image.

## Build, Test, and Development Commands

- `make check` validates both manifests, checks JavaScript and Python syntax, checks shell syntax, and runs the protocol tests. Run it before every submission.
- `make test` is an alias for the full check suite.
- `make xpi` rebuilds `thunderbird/thunderbird-mail-checker.xpi` from the extension manifest, background script, and locales. Commit the rebuilt XPI when those sources change.
- `bin/thunderbird-mail-checker status` prints the bridge's current JSON status and is useful for local diagnostics.

The project uses Python 3's standard library; no dependency-install step is required. Building the XPI requires `zip`.

## Coding Style & Naming Conventions

Follow the surrounding style: two-space indentation in QML and JavaScript, four spaces in Python, and tabs in Make recipes. Use `camelCase` for QML/JavaScript functions and properties, `snake_case` for Python functions, and uppercase names for Python constants. Keep shell scripts in Bash with `set -euo pipefail`. Preserve compact JSON formatting in manifests and use stable plugin IDs rather than duplicating identifier strings.

## Testing Guidelines

Add protocol-level regressions to `tests/protocol-test.sh`. Tests must use temporary `XDG_STATE_HOME` and `XDG_RUNTIME_DIR` locations and must not touch a developer's live Thunderbird state. There is no coverage threshold; new behavior should exercise success and unavailable-bridge paths where relevant.

## Commit & Pull Request Guidelines

Recent commits use short, imperative, sentence-case subjects, such as `Fix mail preview tap handling` and `Respect Omarchy notification silence`. Keep each commit focused. Pull requests should explain user-visible behavior, include `make check` results, link related issues, and attach a screenshot when QML or `preview.png` changes. For releases, update `CHANGELOG.md` and the appropriate version: the plugin version in `manifest.json` and the independently maintained extension version in `thunderbird/manifest.webextension.json`.

## Security & Privacy

Never add credentials, message bodies, or remote telemetry. Keep cached state and sockets user-only, render mailbox metadata as plain text, and do not queue actions across Thunderbird restarts.
