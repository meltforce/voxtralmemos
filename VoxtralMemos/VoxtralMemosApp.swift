import SwiftUI
import SwiftData
import StoreKit
import VoxtralCore

@main
struct VoxtralMemosApp: App {
    let container: ModelContainer?
    let containerError: String?

    init() {
        do {
            let schema = Schema([
                Memo.self,
                PromptTemplate.self,
                MemoTransformation.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let c = try ModelContainer(for: schema, configurations: [config])

            PromptTemplate.seedBuiltInTemplates(in: c.mainContext)
            container = c
            containerError = nil
        } catch {
            container = nil
            containerError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    ContentView()
                        .modelContainer(container)
                } else {
                    DatabaseErrorView(errorMessage: containerError ?? "Unknown error")
                }
            }
            .task {
                for await result in Transaction.updates {
                    if let transaction = try? result.payloadValue {
                        await transaction.finish()
                    }
                }
            }
        }
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

struct DatabaseErrorView: View {
    let errorMessage: String

    var body: some View {
        ContentUnavailableView {
            Label("Database Error", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        } description: {
            Text("Failed to initialize the database. Try restarting the app or reinstalling.\n\n\(errorMessage)")
        }
    }
}
