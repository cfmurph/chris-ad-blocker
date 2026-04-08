# chris-ad-blocker

Practical Safari ad blocker scaffold for macOS with expanded ABP parsing and a resilient update pipeline.

## Included architecture

- `AdBlockerHost` (SwiftUI macOS app): user-facing controls and refresh workflow
- `AdBlockerContentBlocker` (Safari extension): serves JSON rules to Safari
- `AdBlockerCore` (shared framework): parser/compiler, updater, signer, persistence, and rollback
- `RuleCompilerTests` + integration tests: parser corpus + update flow verification

## Repository layout

```text
App/                             # Host app target
Extensions/ContentBlocker/       # Safari content blocker extension target
Shared/                          # Shared core framework target
Tests/RuleCompilerTests/         # Unit tests for parser/compiler
Tests/Integration/               # Update pipeline integration tests
Tests/Fixtures/                  # ABP corpus fixture(s)
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

## Implemented functionality

### ABP parser/compiler support

- block rules and exception rules:
  - `||ads.example.com^`
  - `@@||allowed.example.com^`
- modifiers/options:
  - resource types (`script`, `image`, `stylesheet`, `font`, `media`, etc.)
  - negated resource types (`~image`, etc.)
  - party context (`third-party`, `~third-party`)
  - domain scoping (`domain=foo.com|~bar.com`)
  - case sensitivity (`match-case`)
- pattern forms:
  - domain anchors (`||`)
  - start/end anchors (`|...|`)
  - wildcard/separator tokens (`*`, `^`)
  - raw regex (`/pattern/`)
- canonicalization + deterministic dedupe
- Safari-oriented truncation policy with reserved exception slots

### Update reliability

- conditional HTTP requests with source metadata:
  - `ETag` / `If-None-Match`
  - `Last-Modified` / `If-Modified-Since`
- signature policies:
  - none
  - expected SHA256
  - remote SHA256 file
  - pin-to-first-seen
- rollback behavior if metadata persistence fails after rule write
- per-source metadata index persisted alongside rules

### Test coverage

- expanded parser tests for options, exceptions, anchors, and limits
- ABP corpus-driven parser test (`Tests/Fixtures/abp_corpus.txt`)
- integration tests for:
  - modified update path + metadata persistence
  - not-modified path using persisted rules
  - rollback on metadata write failure
