import SwiftData
import VoxtralCore

/// Shared ModelContainer accessible from both the iPhone scene and the CarPlay scene.
/// Both scenes run in the same process, so they can share a single container.
@MainActor
enum SharedModelContainer {
    static let shared: ModelContainer? = {
        do {
            let schema = Schema([
                Memo.self,
                PromptTemplate.self,
                MemoTransformation.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            PromptTemplate.seedBuiltInTemplates(in: container.mainContext)
            return container
        } catch {
            return nil
        }
    }()
}
