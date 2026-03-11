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
        // Use the shared container so CarPlay scene can access the same data
        if let shared = SharedModelContainer.shared {
            container = shared
            containerError = nil
        } else {
            container = nil
            containerError = "Failed to initialize the database."
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
            if url.scheme == "voxtral-memos" && url.host == "import" {
                Task { await pickupPendingImports() }
            } else if url.isFileURL {
                Task { await importAudioFromURL(url) }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await pickupPendingImports() }
            }
        }
    }

    private func pickupPendingImports() async {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.meltforce.voxtralmemos") else { return }
        let pendingDir = groupURL.appendingPathComponent("pendingImports", isDirectory: true)

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: pendingDir, includingPropertiesForKeys: nil) else { return }

        let manifests = files.filter { $0.pathExtension == "json" }
        for manifestURL in manifests {
            // Atomically claim this manifest to prevent double-processing
            let claimedURL = manifestURL.appendingPathExtension("processing")
            do {
                try fm.moveItem(at: manifestURL, to: claimedURL)
            } catch {
                continue // Another task already claimed this manifest
            }

            guard let data = try? Data(contentsOf: claimedURL),
                  let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let fileName = manifest["fileName"],
                  let originalName = manifest["originalName"] else {
                try? fm.removeItem(at: claimedURL)
                continue
            }

            let audioURL = pendingDir.appendingPathComponent(fileName)
            guard fm.fileExists(atPath: audioURL.path) else {
                try? fm.removeItem(at: claimedURL)
                continue
            }

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
                logger.error("Failed to import pending audio \(originalName): \(error.localizedDescription)")
            }

            try? fm.removeItem(at: audioURL)
            try? fm.removeItem(at: claimedURL)
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
