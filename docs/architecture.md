# Practical Architecture

This project follows Safari's high-performance content blocker approach and keeps
all business logic inside a reusable core module.

## Components

- **AdBlockerHost (macOS SwiftUI app)**
  - Presents controls for refresh and local sample compilation.
  - Calls `SFContentBlockerManager.reloadContentBlocker(...)` after rule updates.
- **AdBlockerContentBlocker (Safari content blocker extension)**
  - Implements `NSExtensionRequestHandling`.
  - Returns the current `blockerList.json` file to Safari.
- **AdBlockerCore (shared framework)**
  - Rule models (`SafariContentBlockerRule`, `Trigger`, `Action`).
  - `RuleCompiler` for ABP-lite to Safari JSON conversion.
  - `RuleListUpdater` for remote list fetching.
  - `RulesStore` for App Group-backed persistence.
- **RuleCompilerTests**
  - Verifies parser behavior and output encoding for key cases.

## Data flow

1. Host app fetches filter list text (or loads a bundled sample list).
2. `RuleCompiler` transforms text into `[SafariContentBlockerRule]`.
3. `RulesStore` writes JSON to the shared App Group container.
4. Host app requests Safari reload for the extension identifier.
5. Extension serves the shared JSON file during content blocker requests.

## Storage model

- App Group identifier: `group.com.example.chrisadblocker`
- Shared rules file: `blockerList.json` at App Group root.
- Extension fallback: bundled `Extensions/ContentBlocker/Resources/blockerList.json`.

## Current compiler scope

Implemented subset (starter-safe):

- Block rules: `||ads.example.com^`
- Simple token lines: `adserver.example`
- Ignore comments/meta: `!`, `[`
- Ignore unsupported syntax for now: `@@`, `##`, `#@#`

## Recommended next upgrades

- Add explicit allowlist (`@@`) support.
- Map ABP options to Safari trigger fields (`resource-type`, `if-domain`).
- Add list checksum/signature handling for safe updates.
- Add large-list performance benchmarks and limits per update.

