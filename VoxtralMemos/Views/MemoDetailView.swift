import SwiftUI
import SwiftData
import VoxtralCore

struct MemoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var memo: Memo
    @StateObject private var player = AudioPlayerService()
    @State private var showTemplatePicker = false
    @State private var selectedTab = 0

    /// The first transformation is shown in the second tab
    private var primaryTransformation: MemoTransformation? {
        memo.transformations
            .sorted { $0.createdAt < $1.createdAt }
            .first
    }

    /// All transformations beyond the first
    private var additionalTransformations: [MemoTransformation] {
        let sorted = memo.transformations.sorted { $0.createdAt < $1.createdAt }
        return Array(sorted.dropFirst())
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

                    // Additional transformations beyond the primary
                    if !additionalTransformations.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("More")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            ForEach(additionalTransformations) { transformation in
                                TransformationCardView(transformation: transformation) {
                                    rerunTransformation(transformation)
                                } onDelete: {
                                    modelContext.delete(transformation)
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Memo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showTemplatePicker = true
                    } label: {
                        Label("Apply Template", systemImage: "wand.and.stars")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(memo.transcript == nil)
            }

            ToolbarItemGroup(placement: .bottomBar) {
                PlaybackBarView(player: player, audioFileURL: memo.audioFileURL)

                Spacer()

                Button {
                    copyContent()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                            .font(.caption2)
                    }
                }
                .disabled(currentContent == nil)

                ShareLink(item: currentContent ?? "") {
                    VStack(spacing: 2) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                            .font(.caption2)
                    }
                }
                .disabled(currentContent == nil)
            }
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet(memo: memo)
        }
        .onDisappear {
            player.stop()
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
                print("Playback error: \(error)")
            }
        }
    }

    private func retryTranscription() {
        memo.status = .transcribing
        memo.errorMessage = nil
        try? modelContext.save()

        Task {
            let service = MistralDirectService()
            do {
                let result = try await service.transcribe(audioFileURL: memo.audioFileURL, language: UserDefaults.standard.string(forKey: "transcriptionLanguage"), model: MistralDirectService.resolvedTranscriptionModel)
                memo.transcript = result.text
                memo.language = result.language
                memo.status = .ready
                try? modelContext.save()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                memo.status = .failed
                memo.errorMessage = error.localizedDescription
                try? modelContext.save()
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func copyContent() {
        if let content = currentContent {
            UIPasteboard.general.string = content
        }
    }

    private func rerunTransformation(_ transformation: MemoTransformation) {
        guard let template = transformation.template, let transcript = memo.transcript else { return }
        transformation.status = .processing
        transformation.result = nil
        transformation.errorMessage = nil
        try? modelContext.save()

        Task {
            let service = MistralDirectService()
            let model = UserDefaults.standard.string(forKey: "selectedModel") ?? "mistral-small-latest"
            do {
                let result = try await service.runPrompt(transcript: transcript, systemPrompt: template.systemPrompt, model: model)
                transformation.result = result
                transformation.status = .ready
            } catch {
                transformation.status = .failed
                transformation.errorMessage = error.localizedDescription
            }
            try? modelContext.save()
        }
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

    var body: some View {
        HStack(spacing: 12) {
            Button {
                player.seek(to: max(0, player.currentTime - 15))
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.body)
            }

            Button {
                togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
            }

            Button {
                player.seek(to: min(player.duration, player.currentTime + 15))
            } label: {
                Image(systemName: "goforward.15")
                    .font(.body)
            }

            Text(formatTime(player.currentTime))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)

            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...(max(player.duration, 1))
            )
            .tint(.teal)

            Text(formatTime(player.duration))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .leading)
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
                print("Playback error: \(error)")
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TransformationCardView: View {
    let transformation: MemoTransformation
    var onRerun: () -> Void
    var onDelete: () -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let template = transformation.template {
                    Image(systemName: template.icon)
                        .foregroundStyle(.teal)
                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else {
                    Text("Transformation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Spacer()

                if transformation.status == .processing {
                    ProgressView()
                        .controlSize(.small)
                } else if transformation.status == .failed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }

                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isExpanded {
                if let result = transformation.result {
                    Text(LocalizedStringKey(result))
                        .font(.body)
                        .textSelection(.enabled)
                } else if transformation.status == .failed {
                    Text(transformation.errorMessage ?? "Failed")
                        .font(.callout)
                        .foregroundStyle(.red)
                } else if transformation.status == .processing {
                    Text("Processing...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            if let result = transformation.result {
                Button {
                    UIPasteboard.general.string = result
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                ShareLink(item: result) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            Button(action: onRerun) {
                Label("Re-run", systemImage: "arrow.clockwise")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
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
            .navigationTitle("Apply Template")
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

        let transformation = MemoTransformation(
            status: .processing,
            modelUsed: model,
            memo: memo,
            template: template
        )
        modelContext.insert(transformation)
        try? modelContext.save()

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
            try? modelContext.save()
        }
    }
}
