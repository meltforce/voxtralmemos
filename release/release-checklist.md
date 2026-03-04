# Release Checklist — Voxtral Memos 1.0

## App Store Connect — Metadata
- [x] App name "Voxtral Memos" registered in App Store Connect
- [x] Subtitle: "AI Transcription & Summaries"
- [x] Description uploaded (see `app-store-description.md`)
- [x] Promotional text set
- [x] Keywords set (see `app-store-metadata.md`)
- [x] Categories: Productivity + Utilities
- [x] Support URL: https://voxtralmemos.meltforce.org/faq/
- [x] Marketing URL: https://voxtralmemos.meltforce.org/
- [x] Privacy Policy URL: https://voxtralmemos.meltforce.org/privacy/
- [x] Copyright: "2026 Linus Schmelzer"

## Screenshots
- [x] iPhone 6.9" screenshots (min 3, see `screenshot-specs.md`)
- [x] iPhone 6.3" screenshots (auto-scaled from 6.9")
- [x] iPad 13" screenshots — N/A, app is iPhone-only
- [ ] Optional: App Preview video (max 30 sec)

## App Review
- [x] Review notes written (see `review-notes.md`)
- [x] Temporary Mistral API key created for reviewer
- [x] API key has credit loaded ($1+ sufficient)
- [x] Demo instructions verified by testing yourself

## Privacy & Compliance
- [x] Privacy labels configured in App Store Connect (see `privacy-labels.md`)
- [x] PrivacyInfo.xcprivacy added to project
- [x] Export compliance answered (HTTPS exemption)
- [x] IDFA declaration: No
- [x] Privacy policy live at https://voxtralmemos.meltforce.org/privacy/

## In-App Purchases
- [ ] Tip Jar products created in App Store Connect (post-launch)
  - [ ] com.meltforce.voxtralmemos.tip.small ($0.99)
  - [ ] com.meltforce.voxtralmemos.tip.medium ($4.99)
  - [ ] com.meltforce.voxtralmemos.tip.large ($9.99)
- [ ] Products approved / "Ready to Submit"

## Website
- [x] Homepage updated (beta banner removed, App Store badge added)
- [x] FAQ page live at /faq/
- [x] Privacy policy live at /privacy/
- [ ] Beta page removed or redirected

## Build & Submit
- [x] MARKETING_VERSION = 1.0.0
- [x] CURRENT_PROJECT_VERSION incremented
- [x] Archive built with Release configuration
- [x] Archive uploaded to App Store Connect
- [x] Internal TestFlight smoke-test passed
- [x] Submitted for App Store Review

## Blockers before submission
- [x] Restrict build to iPhone-only (remove iPad support in project.yml, TARGETED_DEVICE_FAMILY = 1)
- [x] Answer age rating questions in App-Informationen (4+)
- [x] Set pricing (Free) under "Preis"
- [x] Set content rights in App-Informationen (no third-party content)
- [x] Re-archive and upload after iPhone-only fix

## Post-Launch
- [ ] Verify app appears on App Store
- [ ] Update App Store badge link on website with actual URL
- [ ] Social media announcement
- [ ] Remove/archive beta testing materials
