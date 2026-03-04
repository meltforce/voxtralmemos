#if DEBUG
import Foundation
import SwiftData
import VoxtralCore

enum DemoDataSeeder {
    static func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<Memo>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        // Skip onboarding for demo data
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        let templateDescriptor = FetchDescriptor<PromptTemplate>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        let templates = (try? context.fetch(templateDescriptor)) ?? []
        let summaryTemplate = templates.first { $0.icon == "doc.text" }
        let todoTemplate = templates.first { $0.icon == "checklist" }
        let journalTemplate = templates.first { $0.icon == "book" }

        let now = Date()
        let cal = Calendar.current

        var allMemos: [Memo] = []
        var allTransformations: [MemoTransformation] = []

        // MARK: - English (today, product meeting)

        let enMemo = Memo(
            createdAt: cal.date(byAdding: .hour, value: -2, to: now)!,
            duration: 847,
            audioFileName: "demo-en.m4a",
            transcript: "Alright, so let's go over the product launch timeline. We're targeting March 20th for the public release. The marketing team needs the final screenshots and App Store description by this Friday. Sarah mentioned that the press kit should include at least three key talking points: the privacy angle, the multilingual support, and the fact that we use Mistral's Voxtral model for transcription. I think we should also highlight the custom prompts feature — it's a real differentiator. On the technical side, we need to finish the StoreKit integration for the tip jar. The products are already set up in App Store Connect, we just need to wire up the purchase flow. One more thing — the onboarding flow needs a small tweak. The API key entry screen should have a link to Mistral's console so users know where to get their key. Let's sync again on Wednesday to check progress.",
            language: "en",
            status: .ready
        )
        allMemos.append(enMemo)

        allTransformations.append(MemoTransformation(
            createdAt: enMemo.createdAt,
            result: """
            - **Public release targeting March 20th** — marketing needs final screenshots and App Store description by Friday
            - **Press kit** should emphasize privacy, multilingual support, and Voxtral transcription model
            - **Custom prompts** identified as key differentiator to highlight
            - **StoreKit tip jar** integration still needs purchase flow wiring; onboarding needs link to Mistral console
            """,
            status: .ready,
            modelUsed: "mistral-small-latest",
            promptSnapshot: summaryTemplate?.systemPrompt,
            selectedAt: enMemo.createdAt,
            memo: enMemo,
            template: summaryTemplate
        ))

        // MARK: - German (yesterday, dev reflection)

        let deMemo = Memo(
            createdAt: cal.date(byAdding: .day, value: -1, to: now)!,
            duration: 312,
            audioFileName: "demo-de.m4a",
            transcript: "Heute war ein richtig produktiver Tag. Ich habe endlich das neue Feature für die mehrsprachige Transkription fertig bekommen. Das war echt knifflig, weil die Spracherkennung automatisch die richtige Sprache erkennen muss, aber gleichzeitig der User auch manuell eine Sprache auswählen können soll. Am Ende habe ich es so gelöst, dass standardmäßig Auto-Detect an ist, aber in den Einstellungen kann man eine feste Sprache einstellen. Morgen muss ich noch die Unit Tests schreiben und dann kann ich den Pull Request aufmachen. Ach ja, und ich sollte nicht vergessen, den Blogartikel über die App fertig zu schreiben. Der Entwurf liegt schon seit zwei Wochen rum.",
            language: "de",
            status: .ready
        )
        allMemos.append(deMemo)

        allTransformations.append(MemoTransformation(
            createdAt: deMemo.createdAt,
            result: """
            - **Mehrsprachige Transkription** fertiggestellt — Auto-Detect standardmäßig aktiv, manuelle Sprachauswahl in Einstellungen möglich
            - **Nächste Schritte**: Unit Tests schreiben und Pull Request erstellen
            - **Offener Punkt**: Blogartikel über die App fertigstellen (Entwurf liegt seit zwei Wochen)
            """,
            status: .ready,
            modelUsed: "mistral-small-latest",
            promptSnapshot: summaryTemplate?.systemPrompt,
            selectedAt: deMemo.createdAt,
            memo: deMemo,
            template: summaryTemplate
        ))

        // MARK: - Spanish (this week, travel planning)

        let esMemo = Memo(
            createdAt: cal.date(byAdding: .day, value: -3, to: now)!,
            duration: 195,
            audioFileName: "demo-es.m4a",
            transcript: "Bueno, estoy pensando en el viaje a Barcelona para la conferencia de desarrolladores. El vuelo sale el jueves por la mañana y llego sobre las once. El hotel está cerca de la Sagrada Familia, así que puedo ir caminando al centro de conferencias. Tengo que preparar la presentación sobre desarrollo iOS con Swift — me quedan unos tres días para terminar las diapositivas. También quiero aprovechar para visitar el mercado de La Boquería y quizás hacer una excursión al Park Güell el domingo antes de volver.",
            language: "es",
            status: .ready
        )
        allMemos.append(esMemo)

        allTransformations.append(MemoTransformation(
            createdAt: esMemo.createdAt,
            result: """
            - [ ] Reservar vuelo a Barcelona (jueves por la mañana)
            - [ ] Confirmar hotel cerca de la Sagrada Familia
            - [ ] Preparar presentación sobre desarrollo iOS con Swift
            - [ ] Terminar diapositivas (3 días restantes)
            - [ ] Planificar visita al mercado de La Boquería
            - [ ] Reservar excursión al Park Güell para el domingo
            """,
            status: .ready,
            modelUsed: "mistral-small-latest",
            promptSnapshot: todoTemplate?.systemPrompt,
            selectedAt: esMemo.createdAt,
            memo: esMemo,
            template: todoTemplate
        ))

        // MARK: - French (this week, recipe idea)

        let frMemo = Memo(
            createdAt: cal.date(byAdding: .day, value: -2, to: now)!,
            duration: 156,
            audioFileName: "demo-fr.m4a",
            transcript: "J'ai trouvé une super recette de tarte tatin aux pommes chez ma grand-mère ce week-end. Elle utilise des pommes Reinettes, pas les Golden habituelles, et elle caramélise le beurre avec un peu de fleur de sel avant de poser les pommes. Le secret c'est de cuire la pâte feuilletée séparément pendant dix minutes avant de la poser sur les pommes. Ça donne un résultat beaucoup plus croustillant. Il faut aussi laisser reposer la tarte au moins vingt minutes avant de la retourner, sinon tout le caramel coule partout.",
            language: "fr",
            status: .ready
        )
        allMemos.append(frMemo)

        allTransformations.append(MemoTransformation(
            createdAt: frMemo.createdAt,
            result: """
            - **Pommes Reinettes** au lieu des Golden classiques pour plus de saveur
            - **Caramel**: beurre caramélisé avec une pincée de **fleur de sel** avant de poser les pommes
            - **Astuce pâte**: cuire la pâte feuilletée séparément 10 min pour un résultat croustillant
            - **Repos**: laisser reposer **20 minutes minimum** avant de retourner la tarte
            """,
            status: .ready,
            modelUsed: "mistral-small-latest",
            promptSnapshot: summaryTemplate?.systemPrompt,
            selectedAt: frMemo.createdAt,
            memo: frMemo,
            template: summaryTemplate
        ))

        // MARK: - Italian (last week, architecture thoughts)

        let itMemo = Memo(
            createdAt: cal.date(byAdding: .day, value: -5, to: now)!,
            duration: 230,
            audioFileName: "demo-it.m4a",
            transcript: "Ho visitato il Duomo di Firenze oggi e devo dire che l'architettura del Brunelleschi è ancora più impressionante dal vivo. La cupola è enorme — non riesco a credere che l'hanno costruita senza impalcature moderne. La cosa che mi ha colpito di più è il gioco di luce all'interno, soprattutto nel pomeriggio quando il sole entra dalle finestre laterali. Ho fatto anche un giro al Battistero per vedere le porte del Ghiberti. Domani vorrei visitare la Galleria degli Uffizi, ma devo prenotare i biglietti online perché la coda è lunghissima.",
            language: "it",
            status: .ready
        )
        allMemos.append(itMemo)

        allTransformations.append(MemoTransformation(
            createdAt: itMemo.createdAt,
            result: """
            Oggi ho visitato il **Duomo di Firenze**, e l'architettura del Brunelleschi mi ha lasciato senza parole. La cupola, costruita senza impalcature moderne, è un capolavoro di ingegneria rinascimentale.

            L'interno mi ha colpito soprattutto per il **gioco di luce pomeridiano** che filtra dalle finestre laterali — un'esperienza quasi mistica. Ho proseguito la visita al **Battistero**, ammirando le celebri porte del Ghiberti.

            Domani ho in programma la **Galleria degli Uffizi**, ma dovrò prenotare i biglietti online per evitare le lunghe code.
            """,
            status: .ready,
            modelUsed: "mistral-small-latest",
            promptSnapshot: journalTemplate?.systemPrompt,
            selectedAt: itMemo.createdAt,
            memo: itMemo,
            template: journalTemplate
        ))

        // MARK: - Portuguese (last week, fitness notes)

        let ptMemo = Memo(
            createdAt: cal.date(byAdding: .day, value: -6, to: now)!,
            duration: 134,
            audioFileName: "demo-pt.m4a",
            transcript: "Acabei o treino de hoje e foi bem puxado. Fiz agachamento com barra, quatro séries de oito repetições com oitenta quilos. Depois supino reto, três séries de dez com sessenta quilos. Terminei com remada curvada e elevação lateral. O ombro direito ainda está um pouco dolorido do treino de terça, então peguei mais leve na elevação lateral. Preciso marcar uma consulta com o fisioterapeuta se a dor continuar. No geral, o progresso está bom — aumentei cinco quilos no agachamento em relação à semana passada.",
            language: "pt",
            status: .ready
        )
        allMemos.append(ptMemo)

        allTransformations.append(MemoTransformation(
            createdAt: ptMemo.createdAt,
            result: """
            - **Agachamento**: 4x8 com 80kg (+5kg vs semana passada)
            - **Supino reto**: 3x10 com 60kg
            - **Remada curvada** e **elevação lateral** — pegou mais leve na elevação por dor no ombro direito
            - **Atenção**: ombro direito dolorido desde terça — marcar fisioterapeuta se persistir
            - **Progresso geral**: positivo, carga aumentando no agachamento
            """,
            status: .ready,
            modelUsed: "mistral-small-latest",
            promptSnapshot: summaryTemplate?.systemPrompt,
            selectedAt: ptMemo.createdAt,
            memo: ptMemo,
            template: summaryTemplate
        ))

        // MARK: - English 2 (this week, quick idea)

        let enMemo2 = Memo(
            createdAt: cal.date(byAdding: .day, value: -4, to: now)!,
            duration: 63,
            audioFileName: "demo-en2.m4a",
            transcript: "Quick idea for the app — what if we add a widget that shows the last recorded memo with a one-tap record button? Users could start recording right from the home screen without even opening the app. I should check if WidgetKit supports audio recording in the background. Probably need an App Intent for that.",
            language: "en",
            status: .ready
        )
        allMemos.append(enMemo2)

        // MARK: - German 2 (older, grocery list)

        let deMemo2 = Memo(
            createdAt: cal.date(byAdding: .day, value: -12, to: now)!,
            duration: 45,
            audioFileName: "demo-de2.m4a",
            transcript: "Einkaufsliste für heute Abend: Ich brauche Olivenöl, Knoblauch, frische Pasta, Parmesan und Basilikum. Ach, und Tomaten nicht vergessen — die San-Marzano aus der Dose. Für den Nachtisch noch Vanilleeis und Himbeeren.",
            language: "de",
            status: .ready
        )
        allMemos.append(deMemo2)

        allTransformations.append(MemoTransformation(
            createdAt: deMemo2.createdAt,
            result: """
            - [ ] Olivenöl
            - [ ] Knoblauch
            - [ ] Frische Pasta
            - [ ] Parmesan
            - [ ] Basilikum
            - [ ] San-Marzano Tomaten (Dose)
            - [ ] Vanilleeis
            - [ ] Himbeeren
            """,
            status: .ready,
            modelUsed: "mistral-small-latest",
            promptSnapshot: todoTemplate?.systemPrompt,
            selectedAt: deMemo2.createdAt,
            memo: deMemo2,
            template: todoTemplate
        ))

        // Insert all
        for memo in allMemos {
            context.insert(memo)
        }
        for transformation in allTransformations {
            context.insert(transformation)
        }

        try? context.save()
    }
}
#endif
