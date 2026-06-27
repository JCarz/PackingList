import SwiftUI
import SwiftData

struct MasterListView: View {
    @Query(sort: \PackingItem.name) private var items: [PackingItem]
    @State private var showingAddItem = false
    @State private var showingQuickAdd = false
    @State private var toastMessage: String?

    var body: some View {
        List {
            ForEach(ListGrouping.categoriesWithItems(from: items), id: \.0.id) { category, items in
                Section(category.name) {
                    ForEach(items) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            ItemRow(item: item)
                        }
                    }
                }
            }
        }
        .navigationTitle("Master List")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showingAddItem = true
                } label: {
                    Label("Add Item", systemImage: "plus")
                }

                Button {
                    showingQuickAdd = true
                } label: {
                    Label("Quick Add", systemImage: "text.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            NavigationStack {
                AddItemView {
                    toastMessage = "Item added"
                }
            }
        }
        .sheet(isPresented: $showingQuickAdd) {
            NavigationStack {
                QuickAddItemsView { addedCount in
                    toastMessage = "Added \(addedCount) items"
                }
            }
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("No packing items yet", systemImage: "suitcase.cart")
                } description: {
                    Text("Add items to build your reusable master packing list.")
                } actions: {
                    Button("Add Item") {
                        showingAddItem = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .toast(message: $toastMessage)
    }
}

private struct ItemRow: View {
    let item: PackingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name)
                    .font(.headline)

                if item.quantity > 1 {
                    Text("x\(item.quantity)")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if item.isOptional {
                    Text("Optional")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(ruleSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var ruleSummary: String {
        if item.isAlwaysPacked {
            return "Always packed"
        }

        var parts: [String] = []
        if !item.selectedTripTypes.isEmpty {
            parts.append("Trips: \(item.selectedTripTypes.displayText)")
        }
        if !item.destinations.isEmpty {
            parts.append("Destinations: \(item.destinations.displayText)")
        }
        return parts.isEmpty ? "Manual only" : parts.joined(separator: " • ")
    }
}
