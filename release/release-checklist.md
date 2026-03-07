# Release Checklist — Voxtral Memos 1.1

## App Store Connect — Metadata
- [ ] What's New text updated for 1.1 (see `app-store-description.md`)
- [ ] Screenshots updated if needed (new import feature)

## App Review
- [ ] Review notes updated to mention audio import feature
- [ ] Temporary Mistral API key created for reviewer
- [ ] API key has credit loaded ($1+ sufficient)
- [ ] Demo instructions verified by testing yourself

## Build & Submit
- [ ] MARKETING_VERSION = 1.1.0
- [ ] CURRENT_PROJECT_VERSION incremented (must be higher than last upload)
- [ ] Archive built with Release configuration
- [ ] Archive uploaded to App Store Connect
- [ ] Internal TestFlight smoke-test passed
- [ ] Submitted for App Store Review

## Website
- [ ] FAQ roadmap updated (audio import marked as shipped)
- [ ] Any new FAQ entries for import feature

## Post-Launch
- [ ] Verify update appears on App Store
- [ ] Social media / Discord announcement (see `discord-post.md`)

---

# Release Checklist — Voxtral Memos 1.0 (completed)

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

## Build & Submit
- [x] MARKETING_VERSION = 1.0.0
- [x] CURRENT_PROJECT_VERSION incremented
- [x] Archive built with Release configuration
- [x] Archive uploaded to App Store Connect
- [x] Internal TestFlight smoke-test passed
- [x] Submitted for App Store Review

## Website
- [x] Homepage updated (beta banner removed, App Store badge added)
- [x] FAQ page live at /faq/
- [x] Privacy policy live at /privacy/
