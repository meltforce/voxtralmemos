#if canImport(CarPlay)
import CarPlay
import SwiftData
import VoxtralCore
import os

/// Minimal CarPlay integration: one-tap voice memo recording with auto-transcription.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private let logger = Logger(subsystem: "com.meltforce.voxtralmemos", category: "CarPlay")

    private var interfaceController: CPInterfaceController?
    private let recorder = AudioRecorderService()
    private var recordingFileURL: URL?
    private var recordingTimer: Timer?
    private var recordItem: CPListItem?

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        interfaceController.setRootTemplate(buildRootTemplate(), animated: false)
        logger.info("CarPlay connected")
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        // If still recording when CarPlay disconnects, stop gracefully
        if recorder.isRecording {
            finishRecording()
        }
        self.interfaceController = nil
        logger.info("CarPlay disconnected")
    }

    // MARK: - UI

    private func buildRootTemplate() -> CPListTemplate {
        let item = CPListItem(
            text: "Neue Aufnahme",
            detailText: "Tippen zum Starten",
            image: UIImage(systemName: "mic.circle.fill")
        )
        item.handler = { [weak self] _, completion in
            self?.toggleRecording()
            completion()
        }
        self.recordItem = item

        let section = CPListSection(items: [item])
        let template = CPListTemplate(title: "Voxtral Memos", sections: [section])
        return template
    }

    // MARK: - Recording

    private func toggleRecording() {
        if recorder.isRecording {
            finishRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let fileName = "\(UUID().uuidString).m4a"
        let fileURL = Memo.audioDirectory.appendingPathComponent(fileName)

        // Ensure audio directory exists
        try? FileManager.default.createDirectory(
            at: Memo.audioDirectory,
            withIntermediateDirectories: true
        )

        do {
            try recorder.startRecording(to: fileURL)
            recordingFileURL = fileURL
            updateItemForRecording()
            startDurationTimer()
            logger.info("CarPlay recording started")
        } catch {
            logger.error("CarPlay recording failed to start: \(error.localizedDescription)")
        }
    }

    private func finishRecording() {
        let duration = recorder.stopRecording()
        stopDurationTimer()

        guard let fileURL = recordingFileURL, duration > 0.5 else {
            // Discard very short recordings
            if let fileURL = recordingFileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }
            updateItemForIdle()
            return
        }

        let fileName = fileURL.lastPathComponent
        recordingFileURL = nil
        updateItemForIdle()

        logger.info("CarPlay recording stopped, duration: \(duration, format: .fixed(precision: 1))s")

        // Save memo and auto-transcribe
        Task {
            await saveMemoAndTranscribe(fileName: fileName, duration: duration)
        }
    }

    private func saveMemoAndTranscribe(fileName: String, duration: TimeInterval) async {
        guard let container = SharedModelContainer.shared else {
            logger.error("No ModelContainer available for CarPlay memo")
            return
        }

        let context = ModelContext(container)
        let memo = Memo(
            duration: duration,
            audioFileName: fileName,
            status: .transcribing,
            source: "carplay"
        )
        context.insert(memo)
        try? context.save()

        // Auto-transcribe
        let service = MistralDirectService()
        do {
            let transcription = try await service.transcribe(
                audioFileURL: memo.audioFileURL,
                language: UserDefaults.standard.string(forKey: "transcriptionLanguage"),
                model: MistralDirectService.resolvedTranscriptionModel,
                mimeType: "audio/mp4"
            )
            memo.transcript = transcription.text
            memo.language = transcription.language
            memo.status = .ready
            try? context.save()
            logger.info("CarPlay memo transcribed successfully")
        } catch {
            memo.status = .failed
            memo.errorMessage = error.localizedDescription
            try? context.save()
            logger.error("CarPlay transcription failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Timer & UI Updates

    private func startDurationTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingDuration()
            }
        }
    }

    private func stopDurationTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func updateRecordingDuration() {
        let elapsed = recorder.elapsedTime
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        let timeString = String(format: "%02d:%02d", minutes, seconds)
        recordItem?.setText("Aufnahme läuft...")
        recordItem?.setDetailText("\(timeString) – Tippen zum Stoppen")
    }

    private func updateItemForRecording() {
        recordItem?.setText("Aufnahme läuft...")
        recordItem?.setDetailText("00:00 – Tippen zum Stoppen")
        recordItem?.setImage(UIImage(systemName: "stop.circle.fill"))
    }

    private func updateItemForIdle() {
        recordItem?.setText("Neue Aufnahme")
        recordItem?.setDetailText("Tippen zum Starten")
        recordItem?.setImage(UIImage(systemName: "mic.circle.fill"))
    }
}
#endif
