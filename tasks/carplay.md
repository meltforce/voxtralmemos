# CarPlay integration — spec

Spec for the `[open]` CarPlay rows in [`ROADMAP.md`](../ROADMAP.md). Delete this
file when they close, after anything reusable has moved to
[`DECISIONS.md`](../DECISIONS.md).

## Goal

Minimal CarPlay integration: **record a voice memo and transcribe it
automatically**. No playback, no summaries, no template selection in the car.
The use case is "I am in the car, I have an idea, and I want to capture it
quickly".

## Why the fit is good

- The core use case — capture an idea while on the move — is what CarPlay is for.
- Minimal interaction keeps the app inside Apple's HIG limits on driver distraction.
- `VoxtralCore` is already a separate Swift package: recording, transcription and
  the SwiftData models are UI-independent and reusable as they are.
- No external dependencies are required.

## Scope

| Feature | Description |
|---|---|
| CarPlay scene | `CPTemplateApplicationSceneDelegate` with a single `CPListTemplate` |
| Record button | One list item: "New recording" → starts and stops recording |
| Status display | Recording duration as the item's subtitle, updated live |
| Automatic transcription | Transcription starts when recording stops, as in the iPhone app |
| Background audio | `AVAudioSession` configured so recording continues in the background |

### Out of scope

- A memo list or playback in CarPlay
- Text-to-speech for transcripts
- Template selection or AI transformations in the car
- Siri integration — possible later, see *Later extensions*
- `CPNowPlayingTemplate`

## Current state

Commit `f027189` (2026-03-10) landed the plumbing. What exists:

- `VoxtralMemos/CarPlay/CarPlaySceneDelegate.swift`, 191 lines, with the
  one-tap recording flow.
- `SharedModelContainer`, so the iPhone and CarPlay scenes use one
  `ModelContainer`; `VoxtralMemosApp` uses it.
- `com.apple.developer.carplay-audio` in `VoxtralMemos/VoxtralMemos.entitlements`.
- The CarPlay scene and the background audio mode in `project.yml`
  (`UISceneDelegateClassName: "$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate"`,
  `UISceneConfigurationName: CarPlay`).

What is left: the entitlement application, testing, and the hardcoded German UI
strings in `CarPlaySceneDelegate.swift` (lines 46-47 and 174-187), which the app
does not localize anywhere else and which do not match the en-us App Store
listing.

## 1. Apply for the CarPlay entitlement

The declared entitlement does nothing until Apple grants it. The application is
**not** in App Store Connect but a separate form in the Apple Developer portal.

1. Open https://developer.apple.com/contact/carplay/
2. Sign in with the Apple Developer account. This has to be the **Account Holder
   or Agent** — admins and members cannot submit it.
3. Fill in the form:
   - **App name:** Voxtral Memos
   - **App category:** Audio
   - **App description:** suggested text —
     > "Voxtral Memos is a privacy-focused voice memo app that records spoken
     > notes and transcribes them using AI. The CarPlay integration allows
     > drivers to quickly capture voice memos hands-free while driving.
     > The interface is minimal: a single button to start/stop recording.
     > After stopping, the memo is automatically transcribed in the background."
   - Accept the **CarPlay Entitlement Addendum**.
4. Submit. Apple reviews by hand; the stated wait is **1-2 weeks** and varies. A
   refusal can be re-submitted under the "Communication" category.
5. After approval, in **Certificates, Identifiers & Profiles**: edit the app ID
   `com.meltforce.voxtralmemos`, enable the **CarPlay Audio** capability, which
   only appears once granted, create a provisioning profile that carries the
   entitlement, and reload signing in Xcode.

References:

- [Requesting CarPlay entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements)
- [CarPlay Developer Guide (PDF, 2026-02)](https://developer.apple.com/download/files/CarPlay-Developer-Guide.pdf)

## 2. Scene delegate

```swift
import CarPlay
import VoxtralCore

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    private let recorder = AudioRecorderService()
    private var isRecording = false
    private var recordingTimer: Timer?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        let template = buildListTemplate()
        interfaceController.setRootTemplate(template, animated: false)
    }

    private func buildListTemplate() -> CPListTemplate {
        let recordItem = CPListItem(
            text: "New recording",
            detailText: "Tap to start",
            image: UIImage(systemName: "mic.circle.fill")
        )
        recordItem.handler = { [weak self] _, completion in
            self?.toggleRecording(item: recordItem)
            completion()
        }

        let section = CPListSection(items: [recordItem])
        return CPListTemplate(title: "Voxtral Memos", sections: [section])
    }
}
```

Start: configure `AVAudioSession`, begin recording, run a timer that updates the
subtitle. Stop: end the recording, persist the memo in SwiftData, start
transcription, reset the item's labels.

## 3. `Info.plist`

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UISceneConfigurations</key>
    <dict>
        <!-- the existing iPhone scene stays -->
        <key>CPTemplateApplicationSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneClassName</key>
                <string>CPTemplateApplicationScene</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
                <key>UISceneConfigurationName</key>
                <string>CarPlay</string>
            </dict>
        </array>
    </dict>
</dict>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

These keys belong in `project.yml` under the target's `info.properties`, not in
a hand-edited `Info.plist` — `xcodegen generate` rewrites that file from
scratch. See [`INCIDENTS.md`](../INCIDENTS.md), 2026-03-07.

## 4. Entitlements

```xml
<key>com.apple.developer.carplay-audio</key>
<true/>
```

## 5. `project.yml`

```yaml
# under the VoxtralMemos target:
settings:
  UIBackgroundModes: [audio]

entitlements:
  com.apple.developer.carplay-audio: true

sources:
  - path: VoxtralMemos
    includes:
      - "**/*.swift"   # picks up CarPlay/ automatically
```

## 6. Audio session

`AudioRecorderService` has to keep recording while the iPhone app is in the
background, because CarPlay is a separate scene:

```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
try session.setActive(true)
```

`AudioRecorderService` already uses `.playAndRecord`; what mainly matters is that
the background audio capability is active.

## 7. SwiftData across scenes

Both scenes run in the same process and can share one `ModelContainer`. The
container from `VoxtralMemosApp.swift` is reachable as a singleton:

```swift
@MainActor
enum SharedModelContainer {
    static let shared: ModelContainer = {
        // container configuration
    }()
}
```

## Effort estimate

| Task | Effort |
|---|---|
| Apply for the CarPlay entitlement | 1-2 weeks of waiting |
| Implement `CarPlaySceneDelegate` | 1 day |
| `Info.plist`, entitlements, `project.yml` | 0.5 days |
| Audio session for background recording | 0.5 days |
| Share the SwiftData container as a singleton | 0.5 days |
| Trigger transcription when recording stops | 0.5 days |
| Test in the CarPlay simulator | 0.5 days |
| Test on real CarPlay hardware | 0.5 days |
| **Total development time** | **~4 days** |

The four rows above the testing ones landed in `f027189`; the estimate is kept
whole so a re-plan after a refusal starts from the original figure.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Apple refuses the CarPlay entitlement | Medium | Argue the use case as voice recording; re-apply under "Communication" if refused |
| Microphone access is restricted through CarPlay | Low | The iPhone microphone is used, not the car's; this is the standard path |
| No network in a tunnel | High | Recording works offline; transcription runs once the network returns |
| App Review refuses the CarPlay functionality | Low | Minimal scope means little distraction, which is what the HIG asks for |

## Later extensions

Once the base integration works:

1. Siri — "Hey Siri, start a Voxtral recording"
2. A list of the last five memos in CarPlay, title and date only
3. Playback through the car audio system
4. Reading transcripts aloud with `AVSpeechSynthesizer`
5. Live transcription — short fragments shown while recording

## Conclusion

The minimal integration is about four developer days, because `VoxtralCore`
already carries `AudioRecorderService`, `TranscriptionService` and the SwiftData
models UI-independently. The largest uncertainty is Apple's approval of the
CarPlay entitlement, which takes 1-2 weeks and is not guaranteed.
