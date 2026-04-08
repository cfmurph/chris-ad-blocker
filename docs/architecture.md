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

## Current compiler and updater scope

Implemented ABP-oriented scope:

- Block and exception rules:
  - `||ads.example.com^` -> Safari `block`
  - `@@||allowed.example.com^` -> Safari `ignore-previous-rules`
- Pattern translation:
  - host-anchor `||`, start/end anchors `|...|`, wildcard `*`, separator `^`, `/regex/`
- Options:
  - resource modifiers (`script`, `image`, `stylesheet`, `font`, etc.)
  - negated resource modifiers (`~image`) with resolved resource type expansion
  - party scope (`third-party`, `~third-party`)
  - domain scoping (`domain=foo.com|~bar.com`)
  - case sensitivity (`match-case`)
- Canonicalization + dedupe:
  - deterministic lowercasing/sorting for domains and tokens
  - canonical rule keys for stable deduplication
- Safari rule-limit strategy:
  - configurable max rule count
  - reserved slots for exception rules
  - deterministic truncation order

Implemented updater reliability scope:

- Conditional requests with persisted metadata (`ETag`, `Last-Modified`)
- Signature policies:
  - expected SHA256
  - remote checksum file SHA256
  - pin-to-first-seen SHA256
- Rollback behavior:
  - rules file rollback if metadata persistence fails after write
  - source metadata persisted by source URL key

