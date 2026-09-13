# Roadmap

**This file contains open work only.** Every row carries the status token
`[open]`. Closed work is not struck through here — it is removed and lives in
[`DECISIONS.md`](DECISIONS.md) (decisions, with their reasoning) or
[`INCIDENTS.md`](INCIDENTS.md) (postmortems).

Columns: **Status** is always `[open]`. **Where** names the artifact the work
touches. **Trigger** carries the condition for items that are deliberately
deferred, and is empty for items that are simply pending. **Notes** carries the
reasoning.

Before closing an item, check its entry for residual work, dates or triggers —
each becomes its own `[open]` row before the entry is moved out.

## Release

| Status | Item | Where | Trigger | Notes |
|---|---|---|---|---|
| `[open]` | Ship 1.1.0 to the App Store | `release/release-checklist.md` | | Audio import via action extension is the headline change. The checklist still carries the completed 1.0 section below the 1.1 one; remove it when 1.1 ships. |

## CarPlay

| Status | Item | Where | Trigger | Notes |
|---|---|---|---|---|
| `[open]` | Apply for the `com.apple.developer.carplay-audio` entitlement | https://developer.apple.com/contact/carplay/ | | Apple's approval is 1-2 weeks and gates everything else. The entitlement is already declared in `VoxtralMemos/VoxtralMemos.entitlements`, which does nothing until the application is granted. |
| `[open]` | Complete the CarPlay recording UI | `VoxtralMemos/CarPlay/` | Entitlement granted | `CarPlaySceneDelegate` carries a one-tap recording stub. Spec in [`tasks/carplay.md`](tasks/carplay.md). |
| `[open]` | Replace the hardcoded German UI strings in the CarPlay scene | `VoxtralMemos/CarPlay/CarPlaySceneDelegate.swift` | | Lines 46-47 and 174-187 carry German labels. The App Store listing is en-us and the app localizes nothing else, so a CarPlay user sees German in an otherwise English app. |

## Infrastructure

| Status | Item | Where | Trigger | Notes |
|---|---|---|---|---|
| `[open]` | Add an Uptime Kuma monitor for `voxtralmemos.meltforce.org` | homelab, `configuration/uptimekuma/group_vars/all.yml` | | The homepage is the support URL filed with App Review, and an outage is currently not reported. homelab `STANDARDS.md` § *Monitoring coverage* requires the monitor. |
| `[open]` | Decide the permission policy for `.claude/settings.json` | `.claude/settings.json` | | The settings block requires `allow` and `deny` together. Writing them is a permission grant and belongs in its own decision, not in a structural alignment. |
| `[open]` | Add `*.swift` to the language sweep in the standards repo | `claude-project-standards`, `tools/check-docs.sh` | | The sweep's `find` list covers md, sh, py, go, ts, js, rs, yml, yaml, j2, Dockerfile and json — not Swift. In this repo that means the check reports green while three Swift files carry German. Fix belongs in the standards repo, because the script is copied between projects unchanged. |

## Product

| Status | Item | Where | Trigger | Notes |
|---|---|---|---|---|
| `[open]` | Translate the default prompt templates | `VoxtralCore/Sources/VoxtralCore/Models/PromptTemplate.swift` | | The built-in templates ship German prompt text (lines 60 and 63) in an app whose App Store listing is en-us. Every user gets German defaults regardless of device language. |
