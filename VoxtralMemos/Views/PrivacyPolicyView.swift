import SwiftUI

struct PrivacyPolicyView: View {
    private static let mistralPrivacyURL = URL(string: "https://mistral.ai/terms/#privacy-policy")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Last updated: February 2025")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                policySection(
                    title: "No Account Required",
                    body: "Voxtral Memos does not require you to create an account. There are no user profiles, no sign-in, and no personal data collected by the app."
                )

                policySection(
                    title: "On-Device Storage",
                    body: "All your voice memos, transcripts, and summaries are stored locally on your device using Apple's SwiftData framework. Nothing is uploaded to any server operated by Meltforce."
                )

                policySection(
                    title: "API Key Storage",
                    body: "Your Mistral API key is stored securely in the iOS Keychain on your device. It is only used to authenticate requests to the Mistral API and is never shared with any other party."
                )

                policySection(
                    title: "Audio Data",
                    body: "When you initiate a transcription, your audio recording is sent directly to Mistral's API for processing. This transfer is encrypted in transit (HTTPS). Audio is sent only when you explicitly request transcription — never automatically in the background."
                )

                policySection(
                    title: "No Tracking or Analytics",
                    body: "Voxtral Memos contains zero third-party SDKs, no analytics, no crash reporting, and no telemetry. We do not track your usage in any way."
                )

                policySection(
                    title: "No Third-Party Services",
                    body: "The only external service the app communicates with is the Mistral AI API (api.mistral.ai), and only when you explicitly request a transcription or summarization."
                )

                policySection(
                    title: "Data Deletion",
                    body: "You can delete all your data at any time from Settings. This permanently removes all memos, audio files, and transcriptions from your device."
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mistral's Privacy Policy")
                        .font(.headline)

                    Text("Since audio data is processed by Mistral's API, their privacy policy also applies to that data.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Link("View Mistral's Privacy Policy", destination: Self.mistralPrivacyURL)
                        .font(.callout)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
