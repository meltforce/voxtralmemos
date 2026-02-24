import SwiftUI
import SwiftData
import VoxtralCore

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PromptTemplate.sortOrder) private var templates: [PromptTemplate]
    @State private var editingTemplate: PromptTemplate?
    @State private var showNewTemplate = false

    var body: some View {
        List {
            ForEach(templates) { template in
                Button {
                    editingTemplate = template
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

                        Spacer()

                        if template.isAutoRun {
                            Text("Auto")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.teal.opacity(0.15))
                                .foregroundStyle(.teal)
                                .clipShape(Capsule())
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .onDelete(perform: deleteTemplates)
        }
        .navigationTitle("Prompts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewTemplate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editingTemplate) { template in
            NavigationStack {
                TemplateEditorView(template: template)
            }
        }
        .sheet(isPresented: $showNewTemplate) {
            NavigationStack {
                TemplateEditorView(template: nil)
            }
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            let template = templates[index]
            if !template.isBuiltIn {
                modelContext.delete(template)
            }
        }
        modelContext.loggedSave()
    }
}
