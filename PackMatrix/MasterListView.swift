import SwiftUI
import SwiftData

struct MasterListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingItem.name) private var items: [PackingItem]
    @Query private var checklistItems: [TripPackingItem]
    @State private var showingAddItem = false
    @State private var showingQuickAdd = false
    @State private var itemPendingDeletion: PackingItem?
    @State private var showingDeleteConfirmation = false
    @State private var toastMessage: String?

    var body: some View {
        List {
            ForEach(ListGrouping.categoriesWithItems(from: items), id: \.0.id) { category, categoryItems in
                Section(category.name) {
                    ForEach(categoryItems) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            ItemRow(item: item)
                        }
                    }
                    .onDelete { offsets in
                        requestDeleteItems(at: offsets, from: categoryItems)
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
                    showToast("Item added")
                }
            }
        }
        .sheet(isPresented: $showingQuickAdd) {
            NavigationStack {
                QuickAddItemsView { addedCount, skippedDuplicateCount in
                    showToast(QuickAddFeedback.message(addedCount: addedCount, skippedDuplicateCount: skippedDuplicateCount))
                }
            }
        }
        .alert("Delete Item?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                itemPendingDeletion = nil
            }

            Button("Delete", role: .destructive) {
                deletePendingItem()
            }
        } message: {
            Text("This will remove the item from the master list and any trip checklists.")
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

    private func requestDeleteItems(at offsets: IndexSet, from items: [PackingItem]) {
        itemPendingDeletion = offsets.compactMap { offset in
            items.indices.contains(offset) ? items[offset] : nil
        }
        .first

        if itemPendingDeletion != nil {
            showingDeleteConfirmation = true
        }
    }

    private func deletePendingItem() {
        guard let item = itemPendingDeletion else {
            return
        }

        let itemID = item.id
        let relatedChecklistItems = checklistItems.filter { $0.packingItem?.id == itemID }

        for checklistItem in relatedChecklistItems {
            checklistItem.trip?.checklistItems.removeAll { $0.id == checklistItem.id }
            modelContext.delete(checklistItem)
        }

        item.category?.items.removeAll { $0.id == itemID }
        modelContext.delete(item)

        do {
            try modelContext.save()
            itemPendingDeletion = nil
            showToast("Item deleted")
        } catch {
            modelContext.rollback()
            itemPendingDeletion = nil
            showToast("Could not delete item")
        }
    }

    private func showToast(_ message: String) {
        toastMessage = nil

        DispatchQueue.main.async {
            toastMessage = message
        }
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
