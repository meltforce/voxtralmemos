import SwiftUI
import SwiftData
import StoreKit
import VoxtralCore
import os

@main
struct VoxtralMemosApp: App {
    let container: ModelContainer?
    let containerError: String?

    init() {
        do {
            let schema = Schema([
                Memo.self,
                PromptTemplate.self,
                MemoTransformation.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let c = try ModelContainer(for: schema, configurations: [config])

            PromptTemplate.seedBuiltInTemplates(in: c.mainContext)
            // Demo data disabled for release — uncomment for screenshots only
            // #if DEBUG
            // DemoDataSeeder.seedIfNeeded(in: c.mainContext)
            // #endif
            container = c
            containerError = nil
        } catch {
            container = nil
            containerError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    ContentView()
                        .modelContainer(container)
                } else {
                    DatabaseErrorView(errorMessage: containerError ?? "Unknown error")
                }
            }
            .task {
                for await result in Transaction.updates {
                    if let transaction = try? result.payloadValue {
                        await transaction.finish()
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let logger = Logger(subsystem: "com.meltforce.voxtralmemos", category: "ImportPickup")

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MemoListView()
            } else {
                OnboardingView()
            }
        }
        .onOpenURL { url in
            guard url.isFileURL else { return }
            Task { await importAudioFromURL(url) }
        }
    }

    private func importAudioFromURL(_ url: URL) async {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let result = try await AudioImportService.validateAndPrepare(
                url: url,
                targetDirectory: Memo.audioDirectory
            )
            let memo = Memo(
                duration: result.duration,
                audioFileName: result.fileName,
                status: .transcribing,
                source: "imported",
                originalFileName: url.lastPathComponent,
                audioMimeType: result.mimeType
            )
            modelContext.insert(memo)
            try? modelContext.save()

            let service = MistralDirectService()
            let transcription = try await service.transcribe(
                audioFileURL: memo.audioFileURL,
                language: UserDefaults.standard.string(forKey: "transcriptionLanguage"),
                model: MistralDirectService.resolvedTranscriptionModel,
                mimeType: memo.audioMimeType
            )
            memo.transcript = transcription.text
            memo.language = transcription.language
            memo.status = .ready
            try? modelContext.save()
        } catch {
            logger.error("Failed to import audio from URL: \(error.localizedDescription)")
        }
    }
}

struct DatabaseErrorView: View {
    let errorMessage: String

    var body: some View {
        ContentUnavailableView {
            Label("Database Error", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        } description: {
            Text("Failed to initialize the database. Try restarting the app or reinstalling.\n\n\(errorMessage)")
        }
    }
}
