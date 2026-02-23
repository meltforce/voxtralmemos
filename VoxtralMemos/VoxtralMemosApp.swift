import SwiftUI
import SwiftData
import VoxtralCore

@main
struct VoxtralMemosApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                Memo.self,
                PromptTemplate.self,
                MemoTransformation.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])

            PromptTemplate.seedBuiltInTemplates(in: container.mainContext)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            MemoListView()
        } else {
            OnboardingView()
        }
    }
}
