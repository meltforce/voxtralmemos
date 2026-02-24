import SwiftUI
import SwiftData
import VoxtralCore

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let template: PromptTemplate?

    @State private var name: String = ""
    @State private var icon: String = "doc.text"
    @State private var systemPrompt: String = ""
    @State private var isAutoRun: Bool = false
    @State private var showDeleteConfirmation = false

    private let iconOptions = [
        "doc.text", "checklist", "globe", "book", "lightbulb",
        "brain", "text.quote", "list.bullet", "arrow.triangle.branch",
        "sparkles", "wand.and.stars", "text.magnifyingglass",
        "pencil.and.outline", "bubble.left.and.text.bubble.right"
    ]

    var isNewTemplate: Bool { template == nil }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Template name", text: $name)
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    ForEach(iconOptions, id: \.self) { iconName in
                        Button {
                            icon = iconName
                        } label: {
                            Image(systemName: iconName)
                                .font(.title3)
                                .frame(width: 36, height: 36)
                                .background(icon == iconName ? Color.teal.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .foregroundStyle(icon == iconName ? .teal : .primary)
                    }
                }
            }

            Section("System Prompt") {
                TextEditor(text: $systemPrompt)
                    .frame(minHeight: 120)
            }

            Section {
                Toggle("Auto-run after transcription", isOn: $isAutoRun)
            } footer: {
                Text("When enabled, this template will automatically be applied to new memos after transcription completes.")
            }

            if let template, !template.isBuiltIn {
                Section {
                    Button("Delete Template", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }

            if let template, template.isBuiltIn {
                Section {
                    Button("Reset to Default") {
                        resetToDefault(template)
                    }
                }
            }
        }
        .navigationTitle(isNewTemplate ? "New Template" : "Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.isEmpty || systemPrompt.isEmpty)
            }
        }
        .confirmationDialog("Delete Template?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let template {
                    modelContext.delete(template)
                    try? modelContext.save()
                }
                dismiss()
            }
        }
        .onAppear {
            if let template {
                name = template.name
                icon = template.icon
                systemPrompt = template.systemPrompt
                isAutoRun = template.isAutoRun
            }
        }
    }

    private func save() {
        let savedTemplate: PromptTemplate
        if let template {
            template.name = name
            template.icon = icon
            template.systemPrompt = systemPrompt
            template.isAutoRun = isAutoRun
            savedTemplate = template
        } else {
            let newTemplate = PromptTemplate(
                name: name,
                icon: icon,
                systemPrompt: systemPrompt,
                isBuiltIn: false,
                isAutoRun: isAutoRun,
                sortOrder: 100
            )
            modelContext.insert(newTemplate)
            savedTemplate = newTemplate
        }

        // Enforce single auto-run: sync isAutoRun with defaultActionTemplateId
        if isAutoRun {
            let descriptor = FetchDescriptor<PromptTemplate>()
            if let all = try? modelContext.fetch(descriptor) {
                for other in all where other.id != savedTemplate.id {
                    other.isAutoRun = false
                }
            }
            UserDefaults.standard.set(savedTemplate.id.uuidString, forKey: "defaultActionTemplateId")
        } else if UserDefaults.standard.string(forKey: "defaultActionTemplateId") == savedTemplate.id.uuidString {
            UserDefaults.standard.set("", forKey: "defaultActionTemplateId")
        }

        try? modelContext.save()
        dismiss()
    }

    private func resetToDefault(_ template: PromptTemplate) {
        if let builtin = PromptTemplate.builtInTemplates.first(where: { $0.name == template.name }) {
            template.systemPrompt = builtin.prompt
            template.icon = builtin.icon
            template.isAutoRun = builtin.autoRun
            systemPrompt = builtin.prompt
            icon = builtin.icon
            isAutoRun = builtin.autoRun
            try? modelContext.save()
        }
    }
}
