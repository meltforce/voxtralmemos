# App Review Notes

Paste this into the "Notes" field under "App Review Information" in App Store Connect.

---

Voxtral Memos requires a Mistral AI API key to function. The app uses this key to call Mistral's transcription and chat APIs.

To test the app:

1. Open the app — the onboarding screen will ask for an API key.
2. Enter the following demo API key: [PASTE YOUR TEMPORARY KEY HERE]
3. Tap "Continue" — the key will be validated automatically.
4. Record a voice memo by tapping the blue microphone button.
5. The memo will be transcribed automatically after recording stops.
6. Tap on the memo to see the transcript and apply summary transformations.

If you need a fresh API key, you can create one for free at https://console.mistral.ai/

The app makes network requests only to:
- api.mistral.ai (Mistral AI API — transcription and chat completions)

No other network requests are made. The app contains no analytics, no tracking, and no third-party SDKs.

---

## IMPORTANT: Before submitting

- [ ] Create a temporary Mistral API key at https://console.mistral.ai/
- [ ] Add some credit to the key (even $1 is enough for review)
- [ ] Replace [PASTE YOUR TEMPORARY KEY HERE] above with the actual key
- [ ] Verify the key works by testing the app yourself
