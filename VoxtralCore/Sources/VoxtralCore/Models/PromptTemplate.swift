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

    // MARK: - Translate to English (never localized)

    private static let translateToEnglish = (
        name: "Translate to English",
        icon: "globe",
        prompt: "Translate the following transcript to English. Preserve the original meaning and tone. Output only the translated text, nothing else.",
        autoRun: false
    )

    // MARK: - Localized Templates

    private static let localizedTemplates: [String: [(name: String, icon: String, prompt: String, autoRun: Bool)]] = [
        "en": [
            (name: "Summary", icon: "doc.text",
             prompt: "Summarize this voice memo transcript as 2-4 concise bullet points. Bold the key phrases using Markdown. Identify the central question or decision if present.",
             autoRun: true),
            (name: "Todo List", icon: "checklist",
             prompt: "Extract all action items and tasks from this transcript as a Markdown checklist. Only include tasks that are explicitly or implicitly mentioned.",
             autoRun: false),
            (name: "Journal Entry", icon: "book",
             prompt: "Rewrite this transcript as a structured daily journal entry. Organize by topics, clean up spoken language into clear written prose.",
             autoRun: false),
        ],
        "de": [
            (name: "Zusammenfassung", icon: "doc.text",
             prompt: "Fasse dieses Sprachmemo als 2–4 prägnante Stichpunkte zusammen. Hebe die Schlüsselbegriffe mit Markdown fett hervor. Identifiziere die zentrale Frage oder Entscheidung, falls vorhanden.",
             autoRun: true),
            (name: "Aufgabenliste", icon: "checklist",
             prompt: "Extrahiere alle Aufgaben und To-dos aus diesem Transkript als Markdown-Checkliste. Nimm nur Aufgaben auf, die explizit oder implizit erwähnt werden.",
             autoRun: false),
            (name: "Tagebucheintrag", icon: "book",
             prompt: "Schreibe dieses Transkript als strukturierten Tagebucheintrag um. Gliedere nach Themen und formuliere die gesprochene Sprache in klare Schriftsprache um.",
             autoRun: false),
        ],
        "fr": [
            (name: "Résumé", icon: "doc.text",
             prompt: "Résume ce mémo vocal en 2 à 4 points concis. Mets les termes clés en gras avec Markdown. Identifie la question ou décision centrale si elle est présente.",
             autoRun: true),
            (name: "Liste de tâches", icon: "checklist",
             prompt: "Extrais toutes les actions et tâches de ce transcript sous forme de checklist Markdown. N'inclus que les tâches explicitement ou implicitement mentionnées.",
             autoRun: false),
            (name: "Journal intime", icon: "book",
             prompt: "Réécris ce transcript sous forme d'entrée de journal structurée. Organise par thèmes et reformule le langage parlé en prose écrite claire.",
             autoRun: false),
        ],
        "es": [
            (name: "Resumen", icon: "doc.text",
             prompt: "Resume esta nota de voz en 2-4 puntos concisos. Resalta las frases clave en negrita con Markdown. Identifica la pregunta o decisión central si está presente.",
             autoRun: true),
            (name: "Lista de tareas", icon: "checklist",
             prompt: "Extrae todas las tareas y acciones de esta transcripción como una lista de verificación en Markdown. Solo incluye tareas mencionadas explícita o implícitamente.",
             autoRun: false),
            (name: "Entrada de diario", icon: "book",
             prompt: "Reescribe esta transcripción como una entrada de diario estructurada. Organiza por temas y convierte el lenguaje hablado en prosa escrita clara.",
             autoRun: false),
        ],
        "it": [
            (name: "Riepilogo", icon: "doc.text",
             prompt: "Riassumi questo memo vocale in 2-4 punti concisi. Evidenzia le frasi chiave in grassetto con Markdown. Identifica la domanda o decisione centrale se presente.",
             autoRun: true),
            (name: "Lista attività", icon: "checklist",
             prompt: "Estrai tutte le azioni e attività da questa trascrizione come checklist Markdown. Includi solo le attività menzionate esplicitamente o implicitamente.",
             autoRun: false),
            (name: "Voce di diario", icon: "book",
             prompt: "Riscrivi questa trascrizione come voce di diario strutturata. Organizza per argomenti e riformula il linguaggio parlato in prosa scritta chiara.",
             autoRun: false),
        ],
        "pt": [
            (name: "Resumo", icon: "doc.text",
             prompt: "Resuma este memo de voz em 2-4 pontos concisos. Destaque as frases-chave em negrito com Markdown. Identifique a questão ou decisão central, se presente.",
             autoRun: true),
            (name: "Lista de tarefas", icon: "checklist",
             prompt: "Extraia todas as ações e tarefas desta transcrição como uma checklist Markdown. Inclua apenas tarefas mencionadas explícita ou implicitamente.",
             autoRun: false),
            (name: "Entrada de diário", icon: "book",
             prompt: "Reescreva esta transcrição como uma entrada de diário estruturada. Organize por temas e reformule a linguagem falada em prosa escrita clara.",
             autoRun: false),
        ],
        "pl": [
            (name: "Podsumowanie", icon: "doc.text",
             prompt: "Podsumuj tę notatkę głosową w 2–4 zwięzłych punktach. Wyróżnij kluczowe frazy pogrubieniem w Markdown. Zidentyfikuj główne pytanie lub decyzję, jeśli są obecne.",
             autoRun: true),
            (name: "Lista zadań", icon: "checklist",
             prompt: "Wyodrębnij wszystkie zadania i działania z tego transkryptu jako listę kontrolną Markdown. Uwzględnij tylko zadania wymienione wprost lub pośrednio.",
             autoRun: false),
            (name: "Wpis do dziennika", icon: "book",
             prompt: "Przepisz ten transkrypt jako uporządkowany wpis do dziennika. Pogrupuj według tematów i przekształć mowę potoczną w czytelną prozę pisaną.",
             autoRun: false),
        ],
        "ru": [
            (name: "Резюме", icon: "doc.text",
             prompt: "Кратко изложи эту голосовую заметку в 2–4 тезисах. Выдели ключевые фразы жирным шрифтом в Markdown. Определи главный вопрос или решение, если они есть.",
             autoRun: true),
            (name: "Список задач", icon: "checklist",
             prompt: "Извлеки все задачи и действия из этой транскрипции в виде чек-листа Markdown. Включай только задачи, упомянутые прямо или косвенно.",
             autoRun: false),
            (name: "Запись в дневнике", icon: "book",
             prompt: "Перепиши эту транскрипцию как структурированную запись в дневнике. Организуй по темам и преврати разговорную речь в чёткую письменную прозу.",
             autoRun: false),
        ],
    ]

    public static func builtInTemplates(for languageCode: String) -> [(name: String, icon: String, prompt: String, autoRun: Bool)] {
        let templates = localizedTemplates[languageCode] ?? localizedTemplates["en"]!
        // Insert "Translate to English" at index 2 (after Summary and Todo List, before Journal Entry)
        return [templates[0], templates[1], translateToEnglish, templates[2]]
    }

    public static var builtInTemplates: [(name: String, icon: String, prompt: String, autoRun: Bool)] {
        builtInTemplates(for: "en")
    }

    public static func seedBuiltInTemplates(in context: ModelContext) {
        let descriptor = FetchDescriptor<PromptTemplate>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let deviceLanguage = String(Locale.preferredLanguages.first?.prefix(2) ?? "en")
        logger.info("Seeding templates for device language: \(deviceLanguage) (preferredLanguages: \(Locale.preferredLanguages))")
        let templates = builtInTemplates(for: deviceLanguage)

        for (index, template) in templates.enumerated() {
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
