# App Privacy Labels — App Store Connect

## Overview

When filling out the App Privacy section in App Store Connect, you'll be asked
a series of questions about data collection. Here's exactly what to answer.

## Step 1: Data Collection

**"Does your app collect any data?"**

Answer: **Yes**

> Even though the app stores everything locally, audio is sent to Mistral's API
> for processing, which counts as "collection" in Apple's definition.

## Step 2: Data Types

Select the following data type:

### Audio Data
- **Category**: Audio Data
- **Purpose**: App Functionality
- **Linked to identity**: No
- **Used for tracking**: No

> This covers the audio sent to Mistral for transcription.

## Step 3: All Other Categories

For ALL other data categories, answer **No / Not collected**:

- [ ] Contact Info — Not collected
- [ ] Health & Fitness — Not collected
- [ ] Financial Info — Not collected
- [ ] Location — Not collected
- [ ] Sensitive Info — Not collected
- [ ] Contacts — Not collected
- [ ] User Content (other than audio) — Not collected
- [ ] Browsing History — Not collected
- [ ] Search History — Not collected
- [ ] Identifiers — Not collected
- [ ] Usage Data — Not collected
- [ ] Diagnostics — Not collected
- [ ] Purchases — Not collected (StoreKit handles this, not your app)

## Step 4: Tracking Declaration

**"Does your app track users?"**

Answer: **No**

## Summary

The privacy label on the App Store will show:

```
Data Used to Track You: None
Data Linked to You: None
Data Not Linked to You: Audio
```

## Notes

- Apple considers "collection" as data leaving the device, even to a third-party API
- The Mistral API key itself is NOT user data in Apple's definition (it's a developer credential)
- SwiftData/local storage does not count as "collection"
- StoreKit purchases are handled by Apple and don't need to be declared by you
