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
    @Environment(\.scenePhase) private var scenePhase
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
            guard url.scheme == "voxtral-memos", url.host == "import" else { return }
            Task { await processPendingImports() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await processPendingImports() }
            }
        }
    }

    private func processPendingImports() async {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.meltforce.voxtralmemos") else { return }
        let pendingDir = groupURL.appendingPathComponent("pendingImports", isDirectory: true)
        guard FileManager.default.fileExists(atPath: pendingDir.path) else { return }

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: pendingDir, includingPropertiesForKeys: nil) else { return }
        let manifests = files.filter { $0.pathExtension == "json" }

        for manifestURL in manifests {
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let fileName = manifest["fileName"] else {
                try? fm.removeItem(at: manifestURL)
                continue
            }

            let audioURL = pendingDir.appendingPathComponent(fileName)
            guard fm.fileExists(atPath: audioURL.path) else {
                try? fm.removeItem(at: manifestURL)
                continue
            }

            let originalName = manifest["originalName"] ?? fileName

            do {
                let result = try await AudioImportService.validateAndPrepare(
                    url: audioURL,
                    targetDirectory: Memo.audioDirectory
                )
                let memo = Memo(
                    duration: result.duration,
                    audioFileName: result.fileName,
                    status: .transcribing,
                    source: "imported",
                    originalFileName: originalName,
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
                logger.error("Failed to import shared audio: \(error.localizedDescription)")
            }

            // Clean up pending files regardless of success/failure
            try? fm.removeItem(at: audioURL)
            try? fm.removeItem(at: manifestURL)
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
