import SwiftUI
import SwiftData
import VoxtralCore
import os

private let logger = Logger(subsystem: "com.meltforce.voxtralmemos", category: "MemoDetail")

struct MemoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var memo: Memo
    @StateObject private var player = AudioPlayerService()
    @Environment(\.dismiss) private var dismiss
    @State private var showTemplatePicker = false
    @State private var showDeleteConfirmation = false
    @State private var selectedTab = 0
    @State private var copyConfirmed = false
    @State private var playbackError: String?

    /// The most recently selected transformation is shown in the second tab
    private var primaryTransformation: MemoTransformation? {
        memo.transformations
            .sorted { ($0.selectedAt ?? .distantPast) > ($1.selectedAt ?? .distantPast) }
            .first
    }

    private var primaryTabName: String {
        primaryTransformation?.template?.name ?? "Summary"
    }

    private var showTabs: Bool {
        primaryTransformation != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // WhisperMemos-style horizontal tab bar
            if showTabs {
                HStack(spacing: 0) {
                    TabButton(title: "Transcript", isSelected: selectedTab == 0) {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 0 }
                    }
                    TabButton(title: primaryTabName, isSelected: selectedTab == 1) {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 1 }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)

                Divider()
            }

            // Content — switches between transcript and primary transformation
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedTab == 0 || !showTabs {
                        transcriptContent
                    } else {
                        primaryActionContent
                    }
                }
                .padding()
            }

            // Copy / Share pill buttons
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        copyContent()
                        withAnimation {
                            copyConfirmed = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                copyConfirmed = false
                            }
                        }
                    } label: {
                        Label(
                            copyConfirmed ? "Copied" : "Copy",
                            systemImage: copyConfirmed ? "checkmark" : "doc.on.doc"
                        )
                        .font(.subheadline)
                        .contentTransition(.symbolEffect(.replace))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassEffect(.regular.interactive())
                    }
                    .disabled(currentContent == nil)

                    ShareLink(item: currentContent ?? "") {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .glassEffect(.regular.interactive())
                    }
                    .disabled(currentContent == nil)
                }
            }
            .padding(.vertical, 8)

            // Playback bar with waveform
            PlaybackBarView(player: player, audioFileURL: memo.audioFileURL, playbackError: $playbackError)
        }
        .navigationTitle("Memo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if selectedTab == 1, primaryTransformation?.status == .ready {
                        Button { reprocessTransformation() } label: {
                            Label("Reprocess", systemImage: "arrow.clockwise")
                        }
                    }
                    Button { showTemplatePicker = true } label: {
                        Label("Change Prompt", systemImage: "text.badge.star")
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteConfirmation = true } label: {
                        Label("Delete Memo", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More options")
                .disabled(memo.transcript == nil)
            }
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet(memo: memo)
        }
        .confirmationDialog("Delete Memo?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) { deleteMemo() }
        }
        .onDisappear {
            player.stop()
        }
        .alert("Playback Error", isPresented: Binding(
            get: { playbackError != nil },
            set: { if !$0 { playbackError = nil } }
        )) {
            Button("OK") { playbackError = nil }
        } message: {
            Text(playbackError ?? "Could not play audio.")
        }
    }

    // MARK: - Content views

    @ViewBuilder
    private var transcriptContent: some View {
        if memo.status == .transcribing {
            HStack(spacing: 8) {
                ProgressView()
                Text("Transcribing...")
                    .foregroundStyle(.secondary)
            }
        } else if memo.status == .failed {
            VStack(alignment: .leading, spacing: 12) {
                Label("Transcription Failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)

                if let msg = memo.errorMessage {
                    Text(msg)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button("Retry Transcription", systemImage: "arrow.clockwise") {
                    retryTranscription()
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let transcript = memo.transcript {
            Text(transcript)
                .font(.body)
                .textSelection(.enabled)
        } else {
            Text("No transcript available")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var primaryActionContent: some View {
        if let transformation = primaryTransformation {
            switch transformation.status {
            case .processing, .pending:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Processing...")
                        .foregroundStyle(.secondary)
                }
            case .failed:
                Label(transformation.errorMessage ?? "Failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            case .ready:
                if let result = transformation.result {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(primaryTabName)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(LocalizedStringKey(result))
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
            }
        } else {
            Text("No result yet")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Current content for copy/share

    private var currentContent: String? {
        if selectedTab == 0 || !showTabs {
            return memo.transcript
        } else {
            return primaryTransformation?.result
        }
    }

    // MARK: - Actions

    private var hasLoadedAudio: Bool {
        player.duration > 0
    }

    private func togglePlayback() {
        if player.isPlaying {
            player.pause()
        } else if hasLoadedAudio {
            player.resume()
        } else {
            do {
                try player.play(url: memo.audioFileURL)
            } catch {
                playbackError = error.localizedDescription
            }
        }
    }

    private func retryTranscription() {
        // Wipe all cached transformations — a new transcript invalidates them
        for existing in memo.transformations {
            modelContext.delete(existing)
        }

        memo.status = .transcribing
        memo.errorMessage = nil
        modelContext.loggedSave()

        Task {
            let service = MistralDirectService()
            do {
                let result = try await service.transcribe(audioFileURL: memo.audioFileURL, language: UserDefaults.standard.string(forKey: "transcriptionLanguage"), model: MistralDirectService.resolvedTranscriptionModel)
                memo.transcript = result.text
                memo.language = result.language
                memo.status = .ready
                modelContext.loggedSave()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                memo.status = .failed
                memo.errorMessage = error.localizedDescription
                modelContext.loggedSave()
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func copyContent() {
        if let content = currentContent {
            UIPasteboard.general.string = content
        }
    }

    private func reprocessTransformation() {
        guard let transformation = primaryTransformation,
              let template = transformation.template,
              let transcript = memo.transcript else { return }

        // Delete current result and re-run with current prompt/model
        modelContext.delete(transformation)

        let model = UserDefaults.standard.string(forKey: "selectedModel") ?? "mistral-small-latest"
        let fresh = MemoTransformation(
            status: .processing,
            modelUsed: model,
            promptSnapshot: template.systemPrompt,
            selectedAt: Date(),
            memo: memo,
            template: template
        )
        modelContext.insert(fresh)
        modelContext.loggedSave()

        Task {
            let service = MistralDirectService()
            do {
                let result = try await service.runPrompt(
                    transcript: transcript,
                    systemPrompt: template.systemPrompt,
                    model: model
                )
                fresh.result = result
                fresh.status = .ready
            } catch {
                fresh.status = .failed
                fresh.errorMessage = error.localizedDescription
            }
            modelContext.loggedSave()
        }
    }

    private func deleteMemo() {
        do {
            try FileManager.default.removeItem(at: memo.audioFileURL)
        } catch {
            logger.error("Failed to delete audio file: \(error.localizedDescription)")
        }
        modelContext.delete(memo)
        modelContext.loggedSave()
        dismiss()
    }

}

// MARK: - WhisperMemos-style tab button

private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Rectangle()
                    .fill(isSelected ? Color.primary : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

private struct PlaybackBarView: View {
    @ObservedObject var player: AudioPlayerService
    let audioFileURL: URL
    @Binding var playbackError: String?

    @State private var waveformSamples: [Float] = []
    private let barCount = 60

    var body: some View {
        VStack(spacing: 8) {
            Divider()

            // Waveform scrubber
            GeometryReader { geo in
                let progress = player.duration > 0 ? player.currentTime / player.duration : 0

                ZStack(alignment: .leading) {
                    // Waveform bars
                    HStack(spacing: 1.5) {
                        ForEach(0..<barCount, id: \.self) { index in
                            let sample = index < waveformSamples.count ? waveformSamples[index] : Float(0.1)
                            let barProgress = Double(index) / Double(barCount)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(barProgress <= progress ? Color.teal : Color.secondary.opacity(0.25))
                                .frame(height: max(2, CGFloat(sample) * 32))
                        }
                    }
                    .frame(height: 32)
                }
                .frame(width: geo.size.width, height: 32)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            player.seek(to: fraction * player.duration)
                        }
                )
            }
            .frame(height: 32)
            .padding(.horizontal)

            // Transport controls
            HStack {
                Text(formatTime(player.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)

                Spacer()

                GlassEffectContainer(spacing: 20) {
                    HStack(spacing: 20) {
                        Button {
                            player.seek(to: max(0, player.currentTime - 15))
                        } label: {
                            Image(systemName: "gobackward.15")
                                .font(.body)
                        }
                        .buttonStyle(.glass)

                        Button {
                            togglePlayback()
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.glassProminent)

                        Button {
                            player.seek(to: min(player.duration, player.currentTime + 15))
                        } label: {
                            Image(systemName: "goforward.15")
                                .font(.body)
                        }
                        .buttonStyle(.glass)
                    }
                }

                Spacer()

                Text(formatTime(player.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
        .background(.ultraThinMaterial)
        .task {
            waveformSamples = await AudioWaveformExtractor.extractSamples(from: audioFileURL, count: barCount)
        }
    }

    private func togglePlayback() {
        if player.isPlaying {
            player.pause()
        } else if player.duration > 0 {
            player.resume()
        } else {
            do {
                try player.play(url: audioFileURL)
            } catch {
                playbackError = error.localizedDescription
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TemplatePickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PromptTemplate.sortOrder) private var templates: [PromptTemplate]
    let memo: Memo

    var body: some View {
        NavigationStack {
            List(templates) { template in
                Button {
                    applyTemplate(template)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: template.icon)
                            .foregroundStyle(.teal)
                            .frame(width: 30)
                        VStack(alignment: .leading) {
                            Text(template.name)
                                .font(.body)
                            Text(template.systemPrompt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Prompts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func applyTemplate(_ template: PromptTemplate) {
        guard let transcript = memo.transcript else { return }
        let model = UserDefaults.standard.string(forKey: "selectedModel") ?? "mistral-small-latest"

        // Check for a cached transformation matching this template
        if let cached = memo.transformations.first(where: { $0.template?.id == template.id }) {
            // Cache hit — just mark it as the active one
            cached.selectedAt = Date()
            modelContext.loggedSave()
            return
        }

        let transformation = MemoTransformation(
            status: .processing,
            modelUsed: model,
            promptSnapshot: template.systemPrompt,
            selectedAt: Date(),
            memo: memo,
            template: template
        )
        modelContext.insert(transformation)
        modelContext.loggedSave()

        Task {
            let service = MistralDirectService()
            do {
                let result = try await service.runPrompt(
                    transcript: transcript,
                    systemPrompt: template.systemPrompt,
                    model: model
                )
                transformation.result = result
                transformation.status = .ready
            } catch {
                transformation.status = .failed
                transformation.errorMessage = error.localizedDescription
            }
            modelContext.loggedSave()
        }
    }
}
