import SwiftUI
import SwiftData

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingItem.name) private var packingItems: [PackingItem]
    @Query(sort: \PackingCategory.sortOrder) private var categories: [PackingCategory]
    @Query(sort: \Trip.startDate, order: .reverse) private var previousTrips: [Trip]
    @Query(sort: \PackingTemplate.name) private var templates: [PackingTemplate]

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var tripType = TripType.weekend
    @State private var startingPoint = TripStartingPoint.rules
    @State private var isSaving = false
    @State private var isRecentlyPackedExpanded = false
    @State private var showingQuickAddExtraItems = false
    @State private var showingDuplicateWarning = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var toastMessage: String?
    @State private var extraItems: [TripExtraItem] = []

    var onTripCreated: (Trip) -> Void = { _ in }

    var body: some View {
        Form {
            Section("Trip") {
                TextField("Trip Name", text: $name)
                TextField("Destination", text: $destination)

                if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Trip name is required.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Picker("Trip Type", selection: $tripType) {
                    ForEach(TripType.allCases) { tripType in
                        Text(tripType.displayName).tag(tripType)
                    }
                }
            }

            Section("Dates") {
                VStack(alignment: .leading, spacing: 6) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)

                    Text("Selected: \(formattedDate(startDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)

                    Text("Selected: \(formattedDate(endDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if endDate < startDate {
                    Text("End date cannot be before start date.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Packing List") {
                Picker("Start With", selection: $startingPoint) {
                    Text("Generate from rules").tag(TripStartingPoint.rules)

                    if !templates.isEmpty {
                        Section("Templates") {
                            ForEach(templates) { template in
                                Text(template.name).tag(TripStartingPoint.template(template.id))
                            }
                        }
                    }

                    if !previousTrips.isEmpty {
                        Section("Previous Trips") {
                            ForEach(previousTrips) { trip in
                                Text(trip.name).tag(TripStartingPoint.trip(trip.id))
                            }
                        }
                    }
                }
            }

            Section("Extra Items") {
                if extraItems.isEmpty {
                    Text("No extra items added.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(extraItems) { item in
                        HStack {
                            Text(item.name)

                            Spacer()

                            Text(categoryName(for: item.categoryID))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: removeExtraItems)
                }

                Button {
                    showingQuickAddExtraItems = true
                } label: {
                    Label("Quick Add", systemImage: "plus")
                }
            }

            if !recentlyPackedItems.isEmpty {
                Section {
                    DisclosureGroup("Recently Packed", isExpanded: $isRecentlyPackedExpanded) {
                        ForEach(recentlyPackedItems) { suggestion in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(suggestion.item.name)

                                    if let categoryName = suggestion.item.category?.name {
                                        Text(categoryName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text("\(suggestion.useCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Create Trip")
        .sheet(isPresented: $showingQuickAddExtraItems) {
            NavigationStack {
                TripExtraItemsQuickAddView(existingExtraItems: extraItems) { addedItems, skippedCount in
                    extraItems.append(contentsOf: addedItems)
                    showToast(QuickAddFeedback.message(addedCount: addedItems.count, skippedDuplicateCount: skippedCount))
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    startTripCreation()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(!canCreateTrip || isSaving)
            }
        }
        .confirmationDialog("Possible Duplicate Trip", isPresented: $showingDuplicateWarning) {
            Button("Create Anyway") {
                createTrip()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("A trip with the same name, destination, start date, and end date already exists.")
        }
        .toast(message: $toastMessage)
    }

    private func startTripCreation() {
        guard !isSaving, canCreateTrip else {
            return
        }

        errorMessage = nil
        statusMessage = nil

        if matchingTripExists {
            showingDuplicateWarning = true
        } else {
            createTrip()
        }
    }

    private func createTrip() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSaving, canCreateTrip else {
            return
        }

        isSaving = true

        let validEndDate = endDate < startDate ? startDate : endDate
        let trip = Trip(
            name: trimmedName,
            destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: validEndDate,
            tripType: tripType
        )

        modelContext.insert(trip)

        if let sourceTemplate {
            PackingListGenerator.applyTemplate(sourceTemplate, to: trip, in: modelContext)
        } else if let sourceTrip {
            PackingListGenerator.duplicateChecklist(from: sourceTrip, to: trip, in: modelContext)
        } else {
            PackingListGenerator.generateChecklist(for: trip, from: packingItems, in: modelContext)
        }
        addExtraItems(to: trip)

        do {
            try modelContext.save()
            statusMessage = "Trip created."
            toastMessage = "Trip created"

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                dismiss()
                onTripCreated(trip)
            }
        } catch {
            modelContext.delete(trip)
            errorMessage = "Could not create trip. Please try again."
            isSaving = false
        }
    }

    private func addExtraItems(to trip: Trip) {
        var knownItemsByName: [String: PackingItem] = [:]
        for item in packingItems {
            knownItemsByName[item.name.normalizedPackingItemName] = item
        }

        var handledExtraNames: Set<String> = []

        for extraItem in extraItems {
            let trimmedName = extraItem.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = trimmedName.normalizedPackingItemName

            guard !trimmedName.isEmpty, !handledExtraNames.contains(normalizedName) else {
                continue
            }

            let packingItem: PackingItem
            if let existingItem = knownItemsByName[normalizedName] {
                packingItem = existingItem
            } else if let category = categories.first(where: { $0.id == extraItem.categoryID }) {
                let newItem = PackingItem(name: trimmedName, category: category)
                modelContext.insert(newItem)
                category.items.append(newItem)
                knownItemsByName[normalizedName] = newItem
                packingItem = newItem
            } else {
                continue
            }

            PackingListGenerator.manuallyAdd(packingItem, to: trip, in: modelContext)
            handledExtraNames.insert(normalizedName)
        }
    }

    private var sourceTrip: Trip? {
        guard case .trip(let tripID) = startingPoint else {
            return nil
        }

        return previousTrips.first { $0.id == tripID }
    }

    private var sourceTemplate: PackingTemplate? {
        guard case .template(let templateID) = startingPoint else {
            return nil
        }

        return templates.first { $0.id == templateID }
    }

    private var recentlyPackedItems: [RecentlyPackedItem] {
        let checklistItems = previousTrips.flatMap(\.checklistItems)
        var itemsByID: [UUID: PackingItem] = [:]
        var useCountsByID: [UUID: Int] = [:]

        for checklistItem in checklistItems {
            guard let packingItem = checklistItem.packingItem else {
                continue
            }

            itemsByID[packingItem.id] = packingItem
            useCountsByID[packingItem.id, default: 0] += 1
        }

        return useCountsByID.compactMap { itemID, useCount in
            guard let item = itemsByID[itemID] else {
                return nil
            }

            return RecentlyPackedItem(item: item, useCount: useCount)
        }
        .sorted {
            if $0.useCount == $1.useCount {
                return $0.item.name.localizedStandardCompare($1.item.name) == .orderedAscending
            }

            return $0.useCount > $1.useCount
        }
        .prefix(10)
        .map { $0 }
    }

    private var canCreateTrip: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate >= startDate
    }

    private var matchingTripExists: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)

        return previousTrips.contains { trip in
            trip.name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(trimmedName) == .orderedSame &&
            trip.destination.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(trimmedDestination) == .orderedSame &&
            Calendar.current.isDate(trip.startDate, inSameDayAs: startDate) &&
            Calendar.current.isDate(trip.endDate, inSameDayAs: endDate)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private func categoryName(for categoryID: UUID) -> String {
        categories.first { $0.id == categoryID }?.name ?? "Category"
    }

    private func removeExtraItems(at offsets: IndexSet) {
        extraItems.remove(atOffsets: offsets)
    }

    private func showToast(_ message: String) {
        toastMessage = nil

        DispatchQueue.main.async {
            toastMessage = message
        }
    }
}

private enum TripStartingPoint: Hashable {
    case rules
    case template(UUID)
    case trip(UUID)
}

private struct RecentlyPackedItem: Identifiable {
    let item: PackingItem
    let useCount: Int

    var id: UUID {
        item.id
    }
}

private struct TripExtraItem: Identifiable {
    let id = UUID()
    let name: String
    let categoryID: UUID
}

private struct TripExtraItemsQuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PackingCategory.sortOrder) private var categories: [PackingCategory]

    let existingExtraItems: [TripExtraItem]
    var onAdd: ([TripExtraItem], Int) -> Void

    @State private var selectedCategoryID: UUID?
    @State private var itemNames = ""

    var body: some View {
        Form {
            Section("Category") {
                Picker("Category", selection: $selectedCategoryID) {
                    Text("Select Category").tag(nil as UUID?)
                    ForEach(categories) { category in
                        Text(category.name).tag(category.id as UUID?)
                    }
                }
            }

            Section("Items") {
                TextEditor(text: $itemNames)
                    .frame(minHeight: 160)

                Text("Use one item per line or separate items with commas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Quick Add")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addItems()
                }
                .disabled(selectedCategoryID == nil || parsedItemNames.isEmpty)
            }
        }
        .onAppear {
            selectedCategoryID = selectedCategoryID ?? categories.first?.id
        }
    }

    private var parsedItemNames: [String] {
        itemNames
            .split { character in
                character.isNewline || character == ","
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func addItems() {
        guard let selectedCategoryID else {
            return
        }

        var seenNames = Set(existingExtraItems.map { $0.name.normalizedPackingItemName })
        var addedItems: [TripExtraItem] = []
        var skippedCount = 0

        for name in parsedItemNames {
            let normalizedName = name.normalizedPackingItemName

            guard !seenNames.contains(normalizedName) else {
                skippedCount += 1
                continue
            }

            addedItems.append(TripExtraItem(name: name, categoryID: selectedCategoryID))
            seenNames.insert(normalizedName)
        }

        onAdd(addedItems, skippedCount)
        dismiss()
    }
}
