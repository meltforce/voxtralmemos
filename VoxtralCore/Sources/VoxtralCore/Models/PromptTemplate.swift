import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.meltforce.voxtralmemos", category: "PromptTemplate")

@Model
public final class PromptTemplate {
    public var id: UUID
    public var name: String
    public var icon: String
    public var systemPrompt: String
    public var isBuiltIn: Bool
    public var isAutoRun: Bool
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        systemPrompt: String,
        isBuiltIn: Bool = false,
        isAutoRun: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.systemPrompt = systemPrompt
        self.isBuiltIn = isBuiltIn
        self.isAutoRun = isAutoRun
        self.sortOrder = sortOrder
    }

    public static let builtInTemplates: [(name: String, icon: String, prompt: String, autoRun: Bool)] = [
        (
            name: "Summary",
            icon: "doc.text",
            prompt: "Summarize this voice memo transcript as 2-4 concise bullet points. Bold the key phrases using Markdown. Identify the central question or decision if present.",
            autoRun: true
        ),
        (
            name: "Todo List",
            icon: "checklist",
            prompt: "Extract all action items and tasks from this transcript as a Markdown checklist. Only include tasks that are explicitly or implicitly mentioned.",
            autoRun: false
        ),
        (
            name: "Translate to English",
            icon: "globe",
            prompt: "Translate the following transcript to English. Preserve the original meaning and tone.",
            autoRun: false
        ),
        (
            name: "Journal Entry",
            icon: "book",
            prompt: "Rewrite this transcript as a structured daily journal entry. Organize by topics, clean up spoken language into clear written prose.",
            autoRun: false
        )
    ]

    public static func seedBuiltInTemplates(in context: ModelContext) {
        let descriptor = FetchDescriptor<PromptTemplate>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        for (index, template) in builtInTemplates.enumerated() {
            let t = PromptTemplate(
                name: template.name,
                icon: template.icon,
                systemPrompt: template.prompt,
                isBuiltIn: true,
                isAutoRun: template.autoRun,
                sortOrder: index
            )
            context.insert(t)
        }
        do {
            try context.save()
        } catch {
            logger.error("Failed to seed built-in templates: \(error.localizedDescription)")
        }
    }
}
