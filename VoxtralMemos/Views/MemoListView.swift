import SwiftUI
import SwiftData
import VoxtralCore

struct MemoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Memo.createdAt, order: .reverse) private var memos: [Memo]
    @StateObject private var recorder = AudioRecorderService()
    @State private var showSettings = false
    @State private var permissionGranted = false
    @State private var currentRecordingFileName: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    ForEach(groupedMemos, id: \.0) { section in
                        Section(section.0) {
                            ForEach(section.1) { memo in
                                NavigationLink(value: memo.id) {
                                    MemoRowView(memo: memo)
                                }
                            }
                            .onDelete { indexSet in
                                deleteMemos(from: section.1, at: indexSet)
                            }
                        }
                    }

                    // Bottom spacer so list content isn't hidden behind recording bar
                    Color.clear.frame(height: 80)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .navigationTitle("Memos")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .navigationDestination(for: UUID.self) { memoId in
                    if let memo = memos.first(where: { $0.id == memoId }) {
                        MemoDetailView(memo: memo)
                    }
                }

                // Recording bar
                RecordingBarView(recorder: recorder) {
                    startRecording()
                } onStop: {
                    stopRecording()
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                permissionGranted = await AudioRecorderService.requestPermission()
            }
        }
    }

    private var groupedMemos: [(String, [Memo])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: memos) { memo -> String in
            if calendar.isDateInToday(memo.createdAt) {
                return "Today"
            } else if calendar.isDateInYesterday(memo.createdAt) {
                return "Yesterday"
            } else if calendar.isDate(memo.createdAt, equalTo: Date(), toGranularity: .weekOfYear) {
                return "This Week"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: memo.createdAt)
            }
        }
        // Sort sections: most recent first
        return grouped.sorted { a, b in
            let aDate = a.value.first?.createdAt ?? .distantPast
            let bDate = b.value.first?.createdAt ?? .distantPast
            return aDate > bDate
        }
    }

    private func startRecording() {
        let fileName = "\(UUID().uuidString).m4a"
        currentRecordingFileName = fileName
        let fileURL = Memo.audioDirectory.appendingPathComponent(fileName)
        do {
            try recorder.startRecording(to: fileURL)
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func stopRecording() {
        guard let fileName = currentRecordingFileName else { return }
        let duration = recorder.stopRecording()
        currentRecordingFileName = nil

        let memo = Memo(
            duration: duration,
            audioFileName: fileName,
            status: .transcribing
        )
        modelContext.insert(memo)
        try? modelContext.save()

        // Start transcription
        Task {
            await transcribeMemo(memo)
        }
    }

    private func transcribeMemo(_ memo: Memo) async {
        let service = MistralDirectService()
        do {
            let transcriptionModel = UserDefaults.standard.string(forKey: "transcriptionModel") ?? "voxtral-mini-latest"
            let result = try await service.transcribe(audioFileURL: memo.audioFileURL, language: UserDefaults.standard.string(forKey: "transcriptionLanguage"), model: transcriptionModel)
            memo.transcript = result.text
            memo.language = result.language
            memo.status = .ready
            try? modelContext.save()

            // Auto-run templates
            await runDefaultAction(for: memo)
        } catch {
            memo.status = .failed
            memo.errorMessage = error.localizedDescription
            try? modelContext.save()
        }
    }

    private func runDefaultAction(for memo: Memo) async {
        let defaultId = UserDefaults.standard.string(forKey: "defaultActionTemplateId") ?? ""
        guard !defaultId.isEmpty, let uuid = UUID(uuidString: defaultId) else { return }

        let descriptor = FetchDescriptor<PromptTemplate>()
        guard let templates = try? modelContext.fetch(descriptor),
              let template = templates.first(where: { $0.id == uuid }) else { return }

        let service = MistralDirectService()
        let model = UserDefaults.standard.string(forKey: "selectedModel") ?? "mistral-small-latest"

        let transformation = MemoTransformation(
            status: .processing,
            modelUsed: model,
            memo: memo,
            template: template
        )
        modelContext.insert(transformation)
        try? modelContext.save()

        do {
            let result = try await service.runPrompt(
                transcript: memo.transcript ?? "",
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

    private func deleteMemos(from sectionMemos: [Memo], at offsets: IndexSet) {
        for index in offsets {
            let memo = sectionMemos[index]
            // Delete audio file
            try? FileManager.default.removeItem(at: memo.audioFileURL)
            modelContext.delete(memo)
        }
        try? modelContext.save()
    }
}

struct MemoRowView: View {
    let memo: Memo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(memo.displayTitle)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(2)

            HStack {
                Text(memo.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(memo.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if memo.status == .transcribing {
                    ProgressView()
                        .controlSize(.small)
                } else if memo.status == .failed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct RecordingBarView: View {
    @ObservedObject var recorder: AudioRecorderService
    var onRecord: () -> Void
    var onStop: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                if recorder.isRecording {
                    // Pause placeholder (not implemented in V1)
                    Button(action: {}) {
                        Image(systemName: "pause.fill")
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                    .disabled(true)
                    .opacity(0.3)

                    Button(action: onStop) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.red)
                                .frame(width: 12, height: 12)
                            Text("Stop")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.red.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .foregroundStyle(.red)

                    Text(formatTime(recorder.elapsedTime))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Spacer()
                    Button(action: onRecord) {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                            Text("Record")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.teal)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
