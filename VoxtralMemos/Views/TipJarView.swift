import SwiftUI
import StoreKit

struct TipJarView: View {
    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var showThankYou = false
    @State private var purchaseError: String?

    private static let productIDs: [String] = [
        "com.meltforce.voxtralmemos.tip.small",
        "com.meltforce.voxtralmemos.tip.medium",
        "com.meltforce.voxtralmemos.tip.large"
    ]

    private static let tipEmojis: [String: String] = [
        "com.meltforce.voxtralmemos.tip.small": "☕️",
        "com.meltforce.voxtralmemos.tip.medium": "🍕",
        "com.meltforce.voxtralmemos.tip.large": "🎉"
    ]

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Text("Support the Developer")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Voxtral Memos is free to use. If you find it useful, a tip helps support continued development.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)
            }

            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }
            } else if products.isEmpty {
                Section {
                    Text("Tips are not available right now.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                Section {
                    ForEach(products.sorted(by: { $0.price < $1.price })) { product in
                        Button {
                            Task { await purchase(product) }
                        } label: {
                            HStack {
                                Text(Self.tipEmojis[product.id] ?? "💝")
                                    .font(.title2)

                                VStack(alignment: .leading) {
                                    Text(product.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                }

                                Spacer()

                                Text(product.displayPrice)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.teal)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Tip Jar")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProducts()
        }
        .alert("Thank You!", isPresented: $showThankYou) {
            Button("OK") {}
        } message: {
            Text("Your support means a lot and helps keep Voxtral Memos free for everyone.")
        }
        .alert("Purchase Error", isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button("OK") { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "Something went wrong.")
        }
    }

    private func loadProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: Self.productIDs)
        } catch {
            products = []
        }
        isLoading = false
    }

    private func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verification.payloadValue
                await transaction.finish()
                showThankYou = true
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}
