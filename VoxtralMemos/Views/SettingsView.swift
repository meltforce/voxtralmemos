import SwiftUI
import SwiftData
import VoxtralCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var apiKey: String = ""
    @State private var isKeyVisible = false
    @State private var isValidating = false
    @State private var validationResult: Bool?
    @State private var selectedModel: String = UserDefaults.standard.string(forKey: "selectedModel") ?? "mistral-small-latest"
    @State private var selectedTranscriptionModel: String = MistralDirectService.resolvedTranscriptionModel
    @State private var selectedLanguage: String = UserDefaults.standard.string(forKey: "transcriptionLanguage") ?? "auto"
    @State private var availableModels: [MistralModel] = []
    @State private var availableTranscriptionModels: [MistralModel] = []
    @State private var isLoadingModels = false
    @State private var showDeleteConfirmation = false
    @State private var showTemplates = false
    @State private var storageInfo: (fileCount: Int, totalSize: String) = (0, "0 MB")
    @State private var defaultActionTemplateId: String = UserDefaults.standard.string(forKey: "defaultActionTemplateId") ?? ""
    @Query(sort: \PromptTemplate.sortOrder) private var allTemplates: [PromptTemplate]

    private let keychainService = KeychainService()

    private let languages: [(code: String, name: String)] = [
        ("auto", "Auto-detect"),
        ("en", "English"),
        ("de", "German"),
        ("fr", "French"),
        ("es", "Spanish"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("nl", "Dutch"),
        ("ja", "Japanese"),
        ("zh", "Chinese"),
        ("ko", "Korean"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                // API Key
                Section("API Key") {
                    HStack {
                        if isKeyVisible {
                            TextField("Mistral API Key", text: $apiKey)
                                .textContentType(.password)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Mistral API Key", text: $apiKey)
                        }
                        Button {
                            isKeyVisible.toggle()
                        } label: {
                            Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                        }
                    }
                    .onChange(of: apiKey) { _, newValue in
                        keychainService.saveAPIKey(newValue)
                        validationResult = nil
                    }

                    Button {
                        validateKey()
                    } label: {
                        HStack {
                            Text("Test API Key")
                            Spacer()
                            if isValidating {
                                ProgressView()
                                    .controlSize(.small)
                            } else if let result = validationResult {
                                Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result ? .green : .red)
                            }
                        }
                    }
                    .disabled(apiKey.isEmpty || isValidating)
                }

                // Transcription Model
                Section {
                    if availableTranscriptionModels.count > 1 {
                        Picker("Model", selection: $selectedTranscriptionModel) {
                            ForEach(availableTranscriptionModels) { model in
                                Text(model.displayName).tag(model.id)
                            }
                        }
                        .onChange(of: selectedTranscriptionModel) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "transcriptionModel")
                        }
                    } else {
                        HStack {
                            Text("Model")
                            Spacer()
                            let display = availableTranscriptionModels.first?.displayName
                                ?? MistralModel(id: selectedTranscriptionModel, name: "", capabilities: []).displayName
                            Text(display)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        Task { await refreshModels() }
                    } label: {
                        HStack {
                            Text("Refresh Models")
                            Spacer()
                            if isLoadingModels {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isLoadingModels || apiKey.isEmpty)
                } header: {
                    Text("Transcription")
                } footer: {
                    Text("Speech-to-text · $0.003/min")
                }

                // Summarization Model
                Section {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(availableModels) { model in
                            Text(model.displayName).tag(model.id)
                        }
                        if availableModels.isEmpty {
                            Text(MistralModel(id: selectedModel, name: "", capabilities: []).displayName)
                                .tag(selectedModel)
                        }
                    }
                    .onChange(of: selectedModel) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "selectedModel")
                    }
                } header: {
                    Text("Summarization")
                } footer: {
                    Text("Used for summaries, translations, and other transformations.")
                }

                // Language
                Section("Transcription Language") {
                    Picker("Language", selection: $selectedLanguage) {
                        ForEach(languages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .onChange(of: selectedLanguage) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "transcriptionLanguage")
                    }
                }

                // Default Action
                Section {
                    Picker("Default Action", selection: $defaultActionTemplateId) {
                        Text("None").tag("")
                        ForEach(allTemplates) { template in
                            Label(template.name, systemImage: template.icon).tag(template.id.uuidString)
                        }
                    }
                    .onChange(of: defaultActionTemplateId) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "defaultActionTemplateId")
                        // Sync isAutoRun flags on templates
                        for template in allTemplates {
                            template.isAutoRun = (template.id.uuidString == newValue)
                        }
                        try? modelContext.save()
                    }
                } header: {
                    Text("After Transcription")
                } footer: {
                    Text("Automatically run this action on new memos after transcription.")
                }

                // Templates
                Section("Prompts") {
                    NavigationLink("Manage Prompts") {
                        TemplateListView()
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Audio Files")
                        Spacer()
                        Text("\(storageInfo.fileCount)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Storage Used")
                        Spacer()
                        Text(storageInfo.totalSize)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    Link("Mistral Pricing", destination: URL(string: "https://mistral.ai/pricing")!)
                }

                // Danger Zone
                Section {
                    Button("Delete All Data", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete All Data?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all memos, audio files, and transformations. This cannot be undone.")
            }
            .task {
                apiKey = keychainService.getAPIKey() ?? ""
                await loadModels()
                calculateStorage()
            }
        }
    }

    private func validateKey() {
        isValidating = true
        validationResult = nil
        Task {
            let service = MistralDirectService(keychainService: keychainService)
            do {
                let valid = try await service.validateAPIKey()
                validationResult = valid
            } catch {
                validationResult = false
            }
            isValidating = false
        }
    }

    private func loadModels() async {
        isLoadingModels = true
        defer { isLoadingModels = false }
        let service = MistralDirectService(keychainService: keychainService)
        do {
            async let chat = service.listModels()
            async let transcription = service.listTranscriptionModels()
            availableModels = try await chat
            availableTranscriptionModels = try await transcription
        } catch {
            // Keep empty, user can still use defaults
        }
    }

    private func refreshModels() async {
        await loadModels()
    }

    private func calculateStorage() {
        let audioDir = Memo.audioDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return
        }
        var totalBytes: Int64 = 0
        for file in files {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            totalBytes += Int64(size)
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        storageInfo = (files.count, formatter.string(fromByteCount: totalBytes))
    }

    private func deleteAllData() {
        // Delete audio files
        let audioDir = Memo.audioDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
        // Delete all memos
        do {
            try modelContext.delete(model: Memo.self)
            try modelContext.delete(model: MemoTransformation.self)
            try modelContext.save()
        } catch {
            print("Failed to delete data: \(error)")
        }
        calculateStorage()
    }
}
