# Screenshot Specifications

## Required Devices

### iPhone (both required)

| Display | Device Reference | Resolution (portrait) |
|---------|-----------------|----------------------|
| 6.9" | iPhone 16 Pro Max | 1320 x 2868 px |
| 6.3" | iPhone 16 Pro | 1206 x 2622 px |

> Tip: You can upload 6.9" screenshots and Apple will auto-scale for 6.3".
> But for best quality, provide both.

### iPad (only if you support iPad)

The app currently supports iPad via `UISupportedInterfaceOrientations_iPad`,
so iPad screenshots may be required.

| Display | Device Reference | Resolution (portrait) |
|---------|-----------------|----------------------|
| 13" | iPad Pro (M4) | 2064 x 2752 px |

## Format Requirements

- **Format**: PNG or JPEG (no transparency)
- **Minimum**: 3 screenshots per device class
- **Maximum**: 10 screenshots per device class
- **No status bar modifications**: use actual device screenshots
- **Text overlays allowed**: recommended for context

## Recommended Screenshot Sequence

### Shot 1 — Hero / Recording
**Screen**: Recording overlay active, waveform animating
**Text overlay**: "Record your thoughts"
**Purpose**: Shows the core action — recording a voice memo

### Shot 2 — Transcription
**Screen**: Memo detail view, transcript tab selected, showing a real transcription
**Text overlay**: "Instant AI transcription"
**Purpose**: Shows the primary value — speech turned into text

### Shot 3 — Smart Summary
**Screen**: Memo detail view, summary tab selected
**Text overlay**: "Smart summaries in one tap"
**Purpose**: Shows the AI transformation capability

### Shot 4 — Memo List
**Screen**: Main memo list with several memos, different dates
**Text overlay**: "All your memos, organized"
**Purpose**: Shows the app can handle many recordings

### Shot 5 — Custom Prompts
**Screen**: Template list or template editor
**Text overlay**: "Custom AI prompts"
**Purpose**: Shows the flexibility / power-user feature

### Shot 6 (optional) — Privacy / Settings
**Screen**: Settings view showing "No tracking, no analytics"
**Text overlay**: "Privacy by design"
**Purpose**: Reinforces the privacy message

## How to Capture Screenshots

### Option A: Xcode Simulator (easiest)
1. Run the app in the simulator for each device
2. Populate with realistic demo data
3. `Cmd + S` to save screenshot from simulator
4. Screenshots saved to Desktop

### Option B: Physical Device
1. `Side button + Volume up` on the device
2. AirDrop/sync to Mac

### Option C: Fastlane Snapshot (automated)
If you want to automate: https://docs.fastlane.tools/actions/snapshot/

## Adding Text Overlays & Frames

Recommended tools:
- **RocketSim** (Mac app, great for App Store screenshots)
- **Fastlane Frameit** (CLI, free): https://docs.fastlane.tools/actions/frameit/
- **Screenshots Pro** (web): https://screenshots.pro/
- **Figma/Sketch** (manual but full control)

### Design Tips
- Use consistent font and colors across all screenshots
- App's blue accent: #0066cc (light mode) / #2997ff (dark mode)
- Keep text overlays short — 3-5 words max
- Show the app in dark mode OR light mode, not mixed (pick one)
- If using frames, use the Apple device frames for realism
