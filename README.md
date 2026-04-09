# chris-ad-blocker

Practical starter scaffold for a Safari ad blocker on macOS.

## Included architecture

- `AdBlockerHost` (SwiftUI macOS app): user-facing controls and refresh workflow
- `AdBlockerContentBlocker` (Safari extension): serves JSON rules to Safari
- `AdBlockerCore` (shared framework): models, ABP-lite compiler, updater, and rule storage
- `RuleCompilerTests`: unit tests for parser/compiler behavior

## Repository layout

```text
App/                             # Host app target
Extensions/ContentBlocker/       # Safari content blocker extension target
Shared/                          # Shared core framework target
Tests/RuleCompilerTests/         # Unit tests for compiler
docs/architecture.md             # Practical architecture and flow
project.yml                      # XcodeGen project spec
```

## Quick start (on macOS)

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen).
2. Generate project files:

   ```bash
   xcodegen generate
   ```

3. Open `ChrisAdBlocker.xcodeproj` in Xcode.
4. Configure signing for app and extension:
   - Set your Team
   - Keep or change bundle IDs
   - Enable App Groups with: `group.com.example.chrisadblocker`
5. Build and run `AdBlockerHost`.
6. In Safari settings, enable the content blocker extension.

## Current functionality

- Fetches a remote ABP-style filter list URL.
- Compiles a focused subset (currently `||domain^` and basic token rules) into Safari content blocker JSON.
- Writes compiled JSON to shared App Group storage.
- Calls `SFContentBlockerManager.reloadContentBlocker(...)` to refresh Safari.
- Includes bundled fallback JSON rules for first-run behavior.

## Next production upgrades

- Expand ABP syntax support (`@@`, resource modifiers, domain scoping, options).
- Add update metadata (ETag / If-Modified-Since), signature checks, rollback.
- Add rule dedupe and canonicalization tuned for Safari rule limits.
- Add larger parser test corpus + integration tests.
