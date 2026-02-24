import SwiftUI
import SwiftData
import VoxtralCore

struct MemoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Memo.createdAt, order: .reverse) private var memos: [Memo]
    @StateObject private var recorder = AudioRecorderService()
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var permissionGranted = false
    @State private var currentRecordingFileName: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if memos.isEmpty {
                    ContentUnavailableView {
                        Label("No Memos Yet", systemImage: "mic.badge.plus")
                            .foregroundStyle(.teal)
                    } description: {
                        Text("Tap Record to capture your first voice memo.")
                    }
                } else if filteredMemos.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(groupedMemos, id: \.0) { section in
                            Section(section.0) {
                                ForEach(section.1) { memo in
                                    NavigationLink(value: memo.id) {
                                        MemoRowView(memo: memo)
                                    }
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                                    .swipeActions(edge: .leading) {
                                        if memo.status == .failed {
                                            Button {
                                                retryMemo(memo)
                                            } label: {
                                                Label("Retry", systemImage: "arrow.clockwise")
                                            }
                                            .tint(.teal)
                                        }
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
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: memos.map(\.id))
                }

                // Recording overlay
                RecordingOverlayView(recorder: recorder) {
                    startRecording()
                } onStop: {
                    stopRecording()
                }
            }
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
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .searchable(text: $searchText, prompt: "Search memos")
            .task {
                permissionGranted = await AudioRecorderService.requestPermission()
            }
        }
    }

    private var filteredMemos: [Memo] {
        guard !searchText.isEmpty else { return memos }
        return memos.filter {
            $0.transcript?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    private var groupedMemos: [(String, [Memo])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredMemos) { memo -> String in
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
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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

    private func retryMemo(_ memo: Memo) {
        memo.status = .transcribing
        memo.errorMessage = nil
        try? modelContext.save()
        Task {
            await transcribeMemo(memo)
        }
    }

    private func transcribeMemo(_ memo: Memo) async {
        let service = MistralDirectService()
        do {
            let result = try await service.transcribe(audioFileURL: memo.audioFileURL, language: UserDefaults.standard.string(forKey: "transcriptionLanguage"), model: MistralDirectService.resolvedTranscriptionModel)
            memo.transcript = result.text
            memo.language = result.language
            memo.status = .ready
            try? modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Auto-run templates
            await runDefaultAction(for: memo)
        } catch {
            memo.status = .failed
            memo.errorMessage = error.localizedDescription
            try? modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func runDefaultAction(for memo: Memo) async {
        let defaultId = UserDefaults.standard.string(forKey: "defaultActionTemplateId") ?? ""
        guard !defaultId.isEmpty, let uuid = UUID(uuidString: defaultId) else { return }

        let descriptor = FetchDescriptor<PromptTemplate>()
        guard let templates = try? modelContext.fetch(descriptor),
              let template = templates.first(where: { $0.id == uuid }) else { return }

        let model = UserDefaults.standard.string(forKey: "selectedModel") ?? "mistral-small-latest"

        // Check for a cached transformation matching this template
        if let cached = memo.transformations.first(where: { $0.template?.id == template.id }) {
            // Cache hit — just mark it as the active one
            cached.selectedAt = Date()
            try? modelContext.save()
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
        try? modelContext.save()

        let service = MistralDirectService()
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
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.3), value: memo.displayTitle)

            HStack {
                Text(memo.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(memo.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if memo.status == .transcribing {
                    StatusBadgeView(memo: memo)
                } else if memo.status == .failed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            if memo.status == .failed, let msg = memo.errorMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            if memo.status == .failed {
                Text("Swipe right to retry")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

struct StatusBadgeView: View {
    let memo: Memo
    @State private var phase = 0
    @State private var timer: Timer?

    private var label: String {
        switch phase {
        case 0: "Uploading"
        case 1: "Waiting"
        default: "Processing"
        }
    }

    private var icon: String {
        switch phase {
        case 0: "arrow.up.circle"
        case 1: "hourglass"
        default: "gear"
        }
    }

    private var tint: Color {
        switch phase {
        case 0: .blue
        case 1: .orange
        default: .purple
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(tint)
        .contentTransition(.interpolate)
        .animation(.easeInOut(duration: 0.3), value: phase)
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private func startTimer() {
        phase = 0
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            Task { @MainActor in
                if phase < 2 { phase += 1 }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
