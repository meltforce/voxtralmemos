# Transcription keyboard — spec

Spec for the `[open]` keyboard rows in [`ROADMAP.md`](../ROADMAP.md). Delete this
file when they close, after anything reusable has moved to
[`DECISIONS.md`](../DECISIONS.md).

## Goal

A custom keyboard that records speech, sends it to the Mistral transcription
endpoint and inserts the returned text at the cursor of whatever app the user is
typing in. No app switch, no copy and paste.

## Shape decided by App Review

Guideline 4.4.1 constrains the design before any code is written. A keyboard
extension **must**:

- provide keyboard input functionality, meaning typed characters;
- provide a method for progressing to the next keyboard;
- remain functional without full network access and without full access;
- collect user activity only to enhance the keyboard on the device.

and **must not** launch other apps besides Settings.

Three consequences:

1. A microphone-only keyboard does not satisfy the first requirement. A typing
   layer is part of the minimum scope, not a later addition.
2. The typing layer is also the answer to the third requirement: without full
   access the keyboard has no network and no microphone, and what remains has to
   be useful on its own.
3. The alternative design — the keyboard opens the containing app, the app
   records, the keyboard reads the result from the app group — is ruled out by
   the prohibition on launching other apps. See [`DECISIONS.md`](../DECISIONS.md),
   2026-09-13.

## Scope

| Feature | Description |
|---|---|
| Typing layer | Compact QWERTY: letters, shift, a numbers and punctuation layer, delete, space, return, next-keyboard key |
| Recording | Microphone button, elapsed time, input level, cancel |
| Transcription | `MistralDirectService.transcribe`, model and language from the shared settings |
| Insertion | `textDocumentProxy.insertText`, plus one undo step for the inserted text |
| Degraded states | No full access, microphone permission missing, no network, API key missing, API error |

### Out of scope

- Summaries, prompt templates and transformations inside the keyboard
- Live or streaming transcription while recording
- Storing keyboard dictations as memos in the app
- iPad layout — `TARGETED_DEVICE_FAMILY` is `1`
- Localization, which the app does not do anywhere

## 0. Spike: microphone inside a keyboard extension

This step gates every other one and is done first.

A custom keyboard runs in a sandbox that disallows network access and writing to
the containing app's shared group container; reading is permitted. Open access
lifts both restrictions. For the microphone, Apple's documentation names no API;
an Apple engineer's reply in the developer forums states the requirements as
`RequestsOpenAccess` set to `true`, `hasDictationKey` overridden to `true`, and
the keyboard enabled in system settings. In the same thread the reporter
continues to see `AVAudioEngine` failing with error `561145187` and has a bug
report open, `FB16791704`, dated April 2025.

Build to answer the question, not to keep:

```swift
class KeyboardViewController: UIInputViewController {
    override var hasDictationKey: Bool {
        get { true }
        set {}
    }
}
```

Acceptance criteria, all on a physical device, not the simulator:

1. `AVAudioRecorder` starts and produces a file larger than zero bytes.
2. The file contains audible speech after 5 seconds of recording.
3. `URLSession` reaches `https://api.mistral.ai` from the extension.
4. Both hold with the keyboard enabled and full access granted in Settings.

If the microphone stays unavailable, the feature is dropped rather than
redesigned — the trigger variant is closed by 4.4.1, see above.

## 1. Target

New target `VoxtralMemosKeyboard`, bundle identifier
`com.meltforce.voxtralmemos.keyboard`.

```yaml
  VoxtralMemosKeyboard:
    type: app-extension
    platform: iOS
    sources:
      - path: VoxtralMemosKeyboard
        excludes:
          - Info.plist
    dependencies:
      - package: VoxtralCore
    settings:
      base:
        MARKETING_VERSION: "1.1.0"
        CURRENT_PROJECT_VERSION: "1"
        PRODUCT_BUNDLE_IDENTIFIER: com.meltforce.voxtralmemos.keyboard
        CODE_SIGN_ENTITLEMENTS: VoxtralMemosKeyboard/VoxtralMemosKeyboard.entitlements
        TARGETED_DEVICE_FAMILY: "1"
        INFOPLIST_FILE: VoxtralMemosKeyboard/Info.plist
```

The app target gains `- target: VoxtralMemosKeyboard` with `embed: true`, and
the scheme gains the target under `build.targets`.

`MARKETING_VERSION` has to match the app target's value. iOS refuses to load an
extension whose version differs from the parent app; see
[`INCIDENTS.md`](../INCIDENTS.md), 2026-03-07.

`VoxtralCore` compiles into an extension unchanged: no source file references
`UIApplication`, and `AudioRecorderService` depends only on `AVAudioSession`.

## 2. `Info.plist`

Written as a file because the target sets `INFOPLIST_FILE`, following the share
extension. Targets that use `info.properties` instead have their `Info.plist`
rewritten by `xcodegen generate`.

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.keyboard-service</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).KeyboardViewController</string>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>IsASCIICapable</key>
        <false/>
        <key>PrefersRightToLeft</key>
        <false/>
        <key>PrimaryLanguage</key>
        <string>en-US</string>
        <key>RequestsOpenAccess</key>
        <true/>
    </dict>
</dict>
```

## 3. Entitlements and the keychain access group

The keyboard needs the API key, and `KeychainService` currently stores it with no
access group, so an extension cannot read it.

**This is not a return to the 2026-03-07 state.** That incident used the *app
group* identifier as a keychain access group, which is only valid while the
`com.apple.security.application-groups` entitlement is on the target; when the
entitlement left, every query named a group the app did not have. The group used
here is a keychain access group declared through `keychain-access-groups` on both
targets, which is a different entitlement and does not move with the app group.

Both entitlement files gain:

```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.meltforce.voxtralmemos.shared</string>
</array>
```

`KeychainService` gains an optional access group, used on every query of the
shared item:

```swift
public init(accessGroup: String? = nil)
```

Migration, three items to keep apart:

1. Items written before 2026-03-07 carry the app group as access group. The
   existing reverse migration in `migrateFromAccessGroup()` handles them and
   stays.
2. Items written since then carry no access group and therefore live in the
   app's default group, `<TeamID>com.meltforce.voxtralmemos`. A search without
   `kSecAttrAccessGroup` spans every entitled group, so the app still finds
   them; the keyboard does not, because it does not hold that group.
3. The forward migration therefore runs **in the app**: read without a group,
   write with the shared group named explicitly, delete the original.

Adding `keychain-access-groups` also changes the default group for new items to
the first entry in the list. Every query in the shared path names its group
explicitly rather than relying on that default, so the behaviour does not depend
on list order.

`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` stays: a keyboard runs only
after the first unlock.

`KeychainServiceTests` gains cases for the shared group and for the forward
migration.

## 4. Shared settings

`MistralDirectService.resolvedTranscriptionModel` reads
`UserDefaults.standard`, which in an extension is the extension's own domain and
not the app's. The keys the keyboard needs — `transcriptionModel`,
`transcriptionLanguage` — move to `UserDefaults(suiteName:
"group.com.meltforce.voxtralmemos")`, with a one-time copy from
`UserDefaults.standard` for existing installations.

`SettingsView` writes the same keys in seven places and is changed with them.

## 5. Keyboard UI and states

`KeyboardViewController: UIInputViewController` hosts a SwiftUI view through
`UIHostingController`. The keyboard has no intrinsic height; the height is set by
a constraint on the input view with priority 999.

States:

| State | Condition | Display |
|---|---|---|
| Typing | Default, and whenever full access is absent | QWERTY layer with a microphone button |
| No full access | `hasFullAccess == false` | Microphone button disabled, one line of text, a button that opens Settings |
| No microphone permission | `AVAudioApplication.shared.recordPermission != .granted` | One line pointing at the containing app; the keyboard cannot request the permission itself |
| Recording | | Elapsed time, input level, stop, cancel |
| Transcribing | Upload running | Progress, cancel |
| Failed | API or network error | Message from `MistralError`, retry |

The next-keyboard key calls `advanceToNextInputMode()` on tap and
`handleInputModeList(from:with:)` on long press.

## 6. Recording and upload

`AudioRecorderService` is reused as it is. Two changes are confined to the
keyboard:

- **Duration cap of 2 minutes**, against the extension memory budget. Apple
  documents no figure for keyboards; developer reports put it well below the
  budget of other extensions, and the process is terminated on exceeding it
  without a message to the user.
- **Streamed upload.** `MistralDirectService.transcribe` reads the file with
  `Data(contentsOf:)` and copies it into the multipart body, so the audio is
  held twice. At 2 minutes of AAC that is under 4 MB and acceptable; either the
  cap holds or the method moves to `uploadTask(withStreamedRequest:)`. Decide on
  the measured figure from the spike, not in advance.

The audio file is written to `keyboardRecordings/` inside the app group
container, which open access makes writable. A file left behind by a terminated
extension is picked up by the app on next launch, reusing the `pendingImports`
path of the share extension.

## 7. Insertion and undo

```swift
textDocumentProxy.insertText(text)
```

Undo deletes exactly the number of characters inserted, through
`deleteBackward()` in a loop, and is available until the next keystroke. The
inserted text is kept in memory for that purpose and not persisted.

## 8. Containing app

- Onboarding gains a keyboard section: enable the keyboard in Settings, grant
  full access, grant microphone permission in the app.
- The microphone permission is requested by the app, not by the keyboard.
  `NSMicrophoneUsageDescription` is already declared on the app target.
- Settings gains a row showing whether the keyboard is enabled and has full
  access.

## 9. Privacy

Open access carries documented obligations, and the app sends audio to Mistral.
Before submission:

- `VoxtralMemos/Views/PrivacyPolicyView.swift` and the page under `docs/` state
  what the keyboard sends, to whom, and that keystrokes from the typing layer
  leave the device at no point.
- The App Store privacy declaration is extended for the keyboard.
- The review note explains why full access is requested.

## 10. Testing

- Host apps with different input traits: Messages, Safari address bar, Notes, a
  secure text field. A keyboard is disabled in secure fields; the state has to be
  handled rather than assumed.
- Full access off and on, microphone permission denied and granted.
- Memory under a 2-minute recording plus upload, measured with Instruments.
- Flight mode during the upload.

## Effort estimate

| Task | Effort |
|---|---|
| Spike: microphone inside the keyboard | 0.5 days |
| Target, `project.yml`, `Info.plist`, entitlements | 0.5 days |
| Keychain access group, migration, tests | 1 day |
| Shared settings suite and migration | 0.5 days |
| Typing layer | 2 days |
| Recording UI and state machine | 1 day |
| Upload path, duration cap, memory measurement | 0.5 days |
| Insertion, undo, error states | 0.5 days |
| Onboarding and settings in the containing app | 0.5 days |
| Privacy policy and App Store declaration | 0.5 days |
| Testing on device | 1 day |
| **Total development time** | **~8.5 days** |

The typing layer accounts for 2 of those days and is required by 4.4.1, not by
the transcription feature.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| The microphone stays unavailable in the extension | Medium | The spike answers it in 0.5 days, before anything else is built |
| App Review refuses the keyboard over the input requirement | Low with the typing layer, high without | Ship the typing layer as part of the minimum scope |
| App Review questions full access | Medium | Review note plus a privacy policy naming the data path |
| The extension is terminated on the memory budget | Medium | 2-minute cap, streamed upload, measurement with Instruments |
| The keychain migration loses the API key of an existing installation | Low | Delete the original only after a verified read from the shared group; covered by tests |
| Transcription latency makes the keyboard feel slow | Medium | Progress display and cancel; a 2-minute recording transcribes in a few seconds |

## Later extensions

1. Keyboard dictations stored as memos in the app, opt-in
2. A prompt template applied to the dictated text before insertion
3. Replacing a selected passage instead of inserting at the cursor
4. iPad layout
