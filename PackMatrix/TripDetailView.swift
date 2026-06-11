import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingItem.name) private var allPackingItems: [PackingItem]

    @Bindable var trip: Trip
    @State private var showingAddItems = false
    @State private var hidePackedItems = false

    private var packedCount: Int {
        trip.checklistItems.filter(\.isPacked).count
    }

    private var groupedChecklistItems: [(PackingCategory, [TripPackingItem])] {
        ListGrouping.checklistByCategory(from: trip.checklistItems)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(trip.destination)
                        .font(.headline)
                    Text("\(trip.selectedTripType.displayName) • \(trip.startDate.formatted(date: .abbreviated, time: .omitted)) - \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(packedCount), total: Double(max(trip.checklistItems.count, 1))) {
                        Text("\(packedCount) of \(trip.checklistItems.count) packed")
                    }

                    Toggle("Hide packed items", isOn: $hidePackedItems)
                }
                .padding(.vertical, 4)
            }

            ForEach(groupedChecklistItems, id: \.0.id) { category, checklistItems in
                let visibleItems = hidePackedItems ? checklistItems.filter { !$0.isPacked } : checklistItems

                if !visibleItems.isEmpty {
                    Section {
                        ForEach(visibleItems) { checklistItem in
                            ChecklistRow(checklistItem: checklistItem)
                        }
                        .onDelete { offsets in
                            removeItems(at: offsets, from: visibleItems)
                        }
                    } header: {
                        HStack {
                            Text(category.name)
                            Spacer()
                            Text("\(checklistItems.filter(\.isPacked).count) / \(checklistItems.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(trip.name)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    regenerateChecklist()
                } label: {
                    Label("Regenerate", systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    showingAddItems = true
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddItems) {
            NavigationStack {
                AddTripItemsView(trip: trip, items: addableItems)
            }
        }
        .overlay {
            if trip.checklistItems.isEmpty {
                ContentUnavailableView(
                    "Empty Checklist",
                    systemImage: "checklist",
                    description: Text("Add items manually or regenerate from the trip rules.")
                )
            }
        }
    }

    private var addableItems: [PackingItem] {
        allPackingItems.filter { item in
            !trip.checklistItems.contains { $0.packingItem?.id == item.id }
        }
    }

    private func removeItems(at offsets: IndexSet, from items: [TripPackingItem]) {
        for offset in offsets {
            let item = items[offset]
            trip.checklistItems.removeAll { $0.id == item.id }
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    private func regenerateChecklist() {
        PackingListGenerator.generateChecklist(for: trip, from: allPackingItems, in: modelContext)
        try? modelContext.save()
    }
}

private struct ChecklistRow: View {
    @Bindable var checklistItem: TripPackingItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                checklistItem.isPacked.toggle()
            } label: {
                Image(systemName: checklistItem.isPacked ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .foregroundStyle(checklistItem.isPacked ? .green : .secondary)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(checklistItem.packingItem?.name ?? "Deleted item")
                        .strikethrough(checklistItem.isPacked)

                    if checklistItem.quantity > 1 {
                        Text("x\(checklistItem.quantity)")
                            .foregroundStyle(.secondary)
                    }
                }

                if !checklistItem.notes.isEmpty {
                    Text(checklistItem.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if checklistItem.wasManuallyAdded {
                    Text("Manually added")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct AddTripItemsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let trip: Trip
    let items: [PackingItem]
    @State private var addedItemIDs: Set<UUID> = []

    private var visibleItems: [PackingItem] {
        items.filter { !addedItemIDs.contains($0.id) }
    }

    var body: some View {
        List {
            ForEach(ListGrouping.categoriesWithItems(from: visibleItems), id: \.0.id) { category, items in
                Section(category.name) {
                    ForEach(items) { item in
                        Button {
                            PackingListGenerator.manuallyAdd(item, to: trip, in: modelContext)
                            addedItemIDs.insert(item.id)
                            try? modelContext.save()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                    Text(item.isAlwaysPacked ? "Always packed" : item.selectedTripTypes.displayText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                                Image(systemName: "plus.circle")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Items")
        .onAppear {
            addedItemIDs = Set(trip.checklistItems.compactMap { $0.packingItem?.id })
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .overlay {
            if visibleItems.isEmpty {
                ContentUnavailableView("All Items Added", systemImage: "checkmark.circle")
            }
        }
    }
}
