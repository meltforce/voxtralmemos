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

## Transcription keyboard

| Status | Item | Where | Trigger | Notes |
|---|---|---|---|---|
| `[open]` | Spike: prove microphone recording inside a keyboard extension | [`tasks/keyboard.md`](tasks/keyboard.md) § 0 | | Apple's documentation names no microphone API for custom keyboards. The path via `RequestsOpenAccess` and `hasDictationKey` comes from an Apple reply in the developer forums whose thread carries an open bug report, `FB16791704`, April 2025. Half a day, and it gates every other row here. |
| `[open]` | Share the API key through a keychain access group | `VoxtralCore/Sources/VoxtralCore/Services/KeychainService.swift` | Spike passes | The queries carry no access group since [`INCIDENTS.md`](INCIDENTS.md), 2026-03-07, so an extension cannot read the key. The fix is a `keychain-access-groups` entitlement, which is a different entitlement from the app group that caused that incident. Spec § 3. |
| `[open]` | Move the transcription settings into the app group defaults suite | `VoxtralCore/Sources/VoxtralCore/Services/MistralDirectService.swift`, `VoxtralMemos/Views/SettingsView.swift` | Spike passes | `resolvedTranscriptionModel` reads `UserDefaults.standard`, which in an extension is the extension's own domain, so the model and language chosen in the app would not reach the keyboard. Spec § 4. |
| `[open]` | Build the transcription keyboard | `VoxtralMemosKeyboard/` | Spike passes | Recording, transcription and insertion at the cursor, plus the typing layer that App Review guideline 4.4.1 requires. Estimated at 8.5 developer days; spec in [`tasks/keyboard.md`](tasks/keyboard.md). |

## Infrastructure

| Status | Item | Where | Trigger | Notes |
|---|---|---|---|---|
| `[open]` | Add an Uptime Kuma monitor for `voxtralmemos.meltforce.org` | homelab, `configuration/uptimekuma/group_vars/all.yml` | | The homepage is the support URL filed with App Review, and an outage is currently not reported. homelab `STANDARDS.md` § *Monitoring coverage* requires the monitor. |
| `[open]` | Decide the permission policy for `.claude/settings.json` | `.claude/settings.json` | | The settings block requires `allow` and `deny` together. Writing them is a permission grant and belongs in its own decision, not in a structural alignment. |

## Product

| Status | Item | Where | Trigger | Notes |
|---|---|---|---|---|
| `[open]` | Translate the default prompt templates | `VoxtralCore/Sources/VoxtralCore/Models/PromptTemplate.swift` | | All three built-in templates are German, lines 58-67 — the names shown in the UI (`Zusammenfassung`, `Aufgabenliste`, `Tagebucheintrag`) and the prompt text sent to the model. The App Store listing is en-us and the app localizes nothing, so every user gets German defaults regardless of device language. |
