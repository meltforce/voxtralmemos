---
name: verify
description: Build VoxtralMemos, run its tests, and launch it in the iOS Simulator. Use when asked to build, run, test or smoke-test the app, or to confirm that a change compiles. Triggers — "bau das", "kompiliert das noch", "starte im simulator", "lass die tests laufen", "build the app", "run the tests", "launch in the simulator". Not for releasing or archiving — that is `release/release-checklist.md`.
---

# Verify VoxtralMemos

All paths are relative to the repo root. `VoxtralMemos.xcodeproj` is generated,
so regenerate it first whenever `project.yml` changed:

```bash
xcodegen generate
```

## Build

Primary interface is the Xcode MCP server: `BuildProject`, then `GetBuildLog`
for the error text, then `XcodeListNavigatorIssues` for the per-issue detail.

CLI fallback:

```bash
xcodebuild -project VoxtralMemos.xcodeproj -scheme VoxtralMemos \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```

## Tests

The test target is `VoxtralCoreTests`. Run it through the scheme, or directly
from the package:

```bash
cd VoxtralCore && swift test
```

## Run in the Simulator

```bash
xcodebuild -project VoxtralMemos.xcodeproj -scheme VoxtralMemos \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20

xcrun simctl boot "iPhone 16" 2>/dev/null || true
open -a Simulator

APP="$(xcodebuild -project VoxtralMemos.xcodeproj -scheme VoxtralMemos \
  -destination 'platform=iOS Simulator,name=iPhone 16' -showBuildSettings 2>/dev/null \
  | awk '/ BUILT_PRODUCTS_DIR = /{print $3}')/VoxtralMemos.app"

xcrun simctl install booted "$APP"
xcrun simctl launch booted com.meltforce.voxtralmemos
```

`BUILT_PRODUCTS_DIR` is read from `xcodebuild` rather than globbed out of
`~/Library/Developer/Xcode/DerivedData`, so the commands also work in a
worktree, where the DerivedData directory carries a different suffix.
