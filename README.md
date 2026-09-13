# Voxtral Memos

[![Download on the App Store](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83)](https://apps.apple.com/us/app/voxtral-memos/id6759565503)

A free privacy-focused iOS voice memo app that uses [Mistral's Voxtral](https://mistral.ai/) models for transcription and AI-powered summarization. Bring your own API key — no data leaves your device except for direct Mistral API calls.

## Features

- Record voice memos with a native iOS audio experience
- Transcribe recordings using Mistral's Voxtral speech models
- Summarize and transform transcriptions with customizable prompt templates
- All API keys stored securely in the iOS Keychain
- No third-party dependencies — pure SwiftUI + SwiftData
- Tip jar via StoreKit for optional support

## Requirements

- iOS 26.0+ / Xcode 26+
- Swift 6.2
- A [Mistral API key](https://console.mistral.ai/)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)

## Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/meltforce/voxtralmemos.git
   cd voxtralmemos
   ```

2. **Generate the Xcode project**
   ```bash
   xcodegen generate
   ```

3. **Open in Xcode and run** on a simulator or device.

4. **Enter your Mistral API key** in the app's settings to enable transcription and summarization.

## Project Structure

```
VoxtralMemos/
├── VoxtralCore/          # Local Swift Package (models + services)
│   └── Sources/VoxtralCore/
│       ├── Models/        # Memo, PromptTemplate, MemoTransformation
│       └── Services/      # Audio, transcription, API, keychain
├── VoxtralMemos/          # iOS app target (UI layer)
│   ├── Views/             # SwiftUI views
│   └── Extensions/
└── project.yml            # XcodeGen spec
```

## What runs outside this checkout

- **The App Store build.** Submission and review are driven from
  `release/`; `release/release-checklist.md` is the running checklist.
- **The homepage** at https://voxtralmemos.meltforce.org/ is served by GitHub
  Pages from `docs/`. The DNS record pointing the hostname at
  `meltforce.github.io` lives in the homelab repo, not here — see
  [`CLAUDE.md`](CLAUDE.md) § Gotchas.

## Documents

| File | Holds |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Conventions and gotchas for working in this repo. |
| [`ROADMAP.md`](ROADMAP.md) | Open work. |
| [`DECISIONS.md`](DECISIONS.md) | Decisions taken, with reasoning. |
| [`INCIDENTS.md`](INCIDENTS.md) | Postmortems. |
| [`tasks/`](tasks/) | Full specs for open roadmap items. |

## License

[MIT](LICENSE)
