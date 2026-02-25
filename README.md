# Voxtral Memos

> **Work in Progress** — This app is under active development and not yet feature-complete. Expect breaking changes.

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

## License

[MIT](LICENSE)
