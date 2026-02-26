import SwiftUI
import VoxtralCore

struct OnboardingView: View {
    private static let mistralConsoleURL = URL(string: "https://console.mistral.ai/api-keys/")!

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var validationResult: Bool?
    @State private var errorMessage: String?

    private let keychainService = KeychainService()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if let icon = UIImage(named: "AppIcon60x60") {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }

            VStack(spacing: 8) {
                Text("Voxtral Memos")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Record voice memos, get AI-powered transcriptions and summaries using Mistral's Voxtral models.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mistral API Key")
                        .font(.headline)

                    SecureField("Paste your API key here", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                }

                Link(destination: Self.mistralConsoleURL) {
                    HStack {
                        Image(systemName: "key")
                        Text("Get your API key from Mistral")
                    }
                    .font(.callout)
                }
                .buttonStyle(.glass)

                if let error = errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)

            Button {
                validateAndContinue()
            } label: {
                HStack {
                    if isValidating {
                        ProgressView()
                    }
                    Text("Continue")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(apiKey.isEmpty || isValidating)
            .padding(.horizontal)

            Spacer()
        }
    }

    private func validateAndContinue() {
        isValidating = true
        errorMessage = nil

        // Save temporarily for the validation request, revert on failure
        do {
            try keychainService.saveAPIKey(apiKey)
        } catch {
            errorMessage = "Failed to save API key securely."
            isValidating = false
            return
        }

        Task {
            let service = MistralDirectService(keychainService: keychainService)
            do {
                let valid = try await service.validateAPIKey()
                if valid {
                    hasCompletedOnboarding = true
                } else {
                    keychainService.deleteAPIKey()
                    errorMessage = "Invalid API key. Please check and try again."
                }
            } catch {
                keychainService.deleteAPIKey()
                errorMessage = error.localizedDescription
            }
            isValidating = false
        }
    }
}
