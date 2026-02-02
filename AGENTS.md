# AGENTS.md — iOS (Codex)

## Prime directive
Make the smallest correct change that matches existing patterns and keeps the build/tests green.

## Before coding
- Read `README.md` + any of: `DEVELOPING.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md`.
- Identify the repo’s standards and reuse them:
  - SwiftUI vs UIKit
  - SPM vs CocoaPods vs Carthage
  - Networking/persistence layers
  - Architecture (MVVM/TCA/etc.)

## Working loop
1. Reproduce/confirm current behavior.
2. Write a brief plan (3–8 bullets) if non-trivial.
3. Implement in small, reviewable diffs.
4. Verify with the closest available check (tests/build/lint).
5. Report: what changed, files touched, commands run + results, follow-ups.

## Safety & hygiene
- Do **not** change signing, bundle IDs, CI, or release settings unless explicitly asked.
- Do **not** add secrets/certs/profiles.
- Avoid drive-by refactors or repo-wide formatting.
- Don’t commit: `DerivedData/`, `.xcuserdata/`, build artifacts, `.DS_Store`.

## iOS standards
- Prefer modern Swift (`async/await`, `Codable`, value types). Avoid `try!` / force unwraps outside tests.
- UI updates on main thread (`@MainActor` for UI state).
- Keep views/controllers thin; move logic into testable units (VM/services).
- Use protocol-based DI; avoid new DI frameworks unless requested.

## Networking & data
- Centralize request/decoding; handle non-2xx, decoding errors, cancellation.
- Use existing persistence tech; consider migrations if schemas change.

## Testing expectations
- Add/adjust tests for logic and regressions where practical.
- Cover error paths and edge cases for networking/parsing/concurrency.

## Preferred commands (follow repo docs if present)
- Xcode build/test: use `xcodebuild` (workspace/scheme + iOS Simulator destination).
- SPM modules: `swift test` / `swift build`.
