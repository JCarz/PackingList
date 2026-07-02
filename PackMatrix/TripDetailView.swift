import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingItem.name) private var allPackingItems: [PackingItem]
    @Query(sort: \PackingTemplate.name) private var templates: [PackingTemplate]

    @Bindable var trip: Trip
    @State private var showingAddItems = false
    @State private var showingEditTrip = false
    @State private var showingDuplicateTrip = false
    @State private var showingSaveTemplate = false
    @State private var hidePackedItems = false
    @State private var toastMessage: String?

    private var packedCount: Int {
        trip.checklistItems.filter(\.isPacked).count
    }

    private var totalCount: Int {
        trip.checklistItems.count
    }

    private var groupedChecklistItems: [(PackingCategory, [TripPackingItem])] {
        ListGrouping.checklistByCategory(from: trip.checklistItems)
    }

    private var remainingItems: [TripPackingItem] {
        trip.checklistItems
            .filter { !$0.isPacked }
            .sorted {
                ($0.packingItem?.name ?? "").localizedStandardCompare($1.packingItem?.name ?? "") == .orderedAscending
            }
    }

    private var hasVisibleChecklistItems: Bool {
        groupedChecklistItems.contains { !$0.1.isEmpty }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    TripSummaryCard(trip: trip, totalCount: totalCount, packedCount: packedCount)
                    Toggle("Hide packed items", isOn: $hidePackedItems)
                }
                .padding(.vertical, 4)
            }

            Section("Still To Pack (\(remainingItems.count))") {
                if remainingItems.isEmpty {
                    Text("All packed")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(remainingItems) { checklistItem in
                        Text(checklistItem.packingItem?.name ?? "Deleted item")
                    }
                }
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
                    showingEditTrip = true
                } label: {
                    Label("Edit Trip", systemImage: "pencil")
                }

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

                Button {
                    showingDuplicateTrip = true
                } label: {
                    Label("Duplicate Trip", systemImage: "plus.square.on.square")
                }

                Button {
                    showingSaveTemplate = true
                } label: {
                    Label("Save as Template", systemImage: "doc.badge.plus")
                }

                Button {
                    toggleArchiveStatus()
                } label: {
                    Label(trip.isArchived ? "Restore Trip" : "Archive Trip", systemImage: trip.isArchived ? "tray.and.arrow.up" : "archivebox")
                }
            }
        }
        .sheet(isPresented: $showingAddItems) {
            NavigationStack {
                AddTripItemsView(trip: trip, items: addableItems)
            }
        }
        .sheet(isPresented: $showingEditTrip) {
            NavigationStack {
                EditTripView(trip: trip) {
                    toastMessage = "Trip saved"
                }
            }
        }
        .sheet(isPresented: $showingDuplicateTrip) {
            NavigationStack {
                DuplicateTripView(sourceTrip: trip) {
                    toastMessage = "Trip duplicated"
                }
            }
        }
        .sheet(isPresented: $showingSaveTemplate) {
            NavigationStack {
                SaveTemplateView(trip: trip, existingTemplates: templates) {
                    toastMessage = "Template saved"
                }
            }
        }
        .overlay {
            if !hasVisibleChecklistItems {
                ContentUnavailableView {
                    Label("No items added to this trip yet", systemImage: "checklist")
                } description: {
                    Text("Add items manually or regenerate from the trip rules.")
                } actions: {
                    Button("Add Item") {
                        showingAddItems = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .toast(message: $toastMessage)
    }

    private var addableItems: [PackingItem] {
        allPackingItems.filter { item in
            !trip.checklistItems.contains { $0.packingItem?.id == item.id }
        }
    }

    private func removeItems(at offsets: IndexSet, from items: [TripPackingItem]) {
        var didRemoveItem = false

        for offset in offsets {
            guard items.indices.contains(offset) else {
                continue
            }

            let item = items[offset]
            trip.checklistItems.removeAll { $0.id == item.id }
            modelContext.delete(item)
            didRemoveItem = true
        }

        try? modelContext.save()
        if didRemoveItem {
            toastMessage = "Item removed"
        }
    }

    private func regenerateChecklist() {
        PackingListGenerator.generateChecklist(for: trip, from: allPackingItems, in: modelContext)
        try? modelContext.save()
    }

    private func toggleArchiveStatus() {
        trip.isArchived.toggle()

        do {
            try modelContext.save()
            toastMessage = trip.isArchived ? "Trip archived" : "Trip restored"
        } catch {
            modelContext.rollback()
            toastMessage = "Could not update trip"
        }
    }
}

private struct DuplicateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let sourceTrip: Trip
    var onDuplicated: () -> Void = { }

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var tripType = TripType.weekend
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: TripFormField?

    var body: some View {
        Form {
            Section("Trip") {
                TextField("Trip Name", text: $name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .destination
                    }

                TextField("Destination", text: $destination)
                    .focused($focusedField, equals: .destination)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }

                Picker("Trip Type", selection: $tripType) {
                    ForEach(TripType.allCases) { tripType in
                        Text(tripType.displayName).tag(tripType)
                    }
                }
            }

            Section("Dates") {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
            }

            Section("Checklist") {
                LabeledContent("Items", value: "\(sourceTrip.checklistItems.count)")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Duplicate Trip")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    focusedField = nil
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    focusedField = nil
                    duplicateTrip()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(!canSave || isSaving)
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .onAppear {
            name = sourceTrip.name
            destination = sourceTrip.destination
            startDate = sourceTrip.startDate
            endDate = max(sourceTrip.endDate, sourceTrip.startDate)
            tripType = sourceTrip.selectedTripType
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate >= startDate
    }

    private func duplicateTrip() {
        guard canSave, !isSaving else {
            return
        }

        isSaving = true
        errorMessage = nil

        let newTrip = Trip(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: endDate,
            tripType: tripType
        )

        modelContext.insert(newTrip)
        PackingListGenerator.copyChecklist(from: sourceTrip, to: newTrip, in: modelContext)

        do {
            try modelContext.save()
            dismiss()
            onDuplicated()
        } catch {
            modelContext.delete(newTrip)
            errorMessage = "Could not duplicate trip. Please try again."
            isSaving = false
        }
    }
}

private struct SaveTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let trip: Trip
    let existingTemplates: [PackingTemplate]
    var onSaved: () -> Void = { }

    @State private var templateName = ""
    @State private var errorMessage: String?
    @FocusState private var isTemplateNameFocused: Bool

    var body: some View {
        Form {
            Section("Template") {
                TextField("Template Name", text: $templateName)
                    .focused($isTemplateNameFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        isTemplateNameFocused = false
                    }

                if templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Template name is required.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Items") {
                LabeledContent("Included Items", value: "\(uniqueChecklistItems.count)")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Save Template")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isTemplateNameFocused = false
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    isTemplateNameFocused = false
                    saveTemplate()
                }
                .disabled(!canSave)
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    isTemplateNameFocused = false
                }
            }
        }
        .onAppear {
            templateName = trip.name
        }
    }

    private var uniqueChecklistItems: [TripPackingItem] {
        var seenPackingItemIDs = Set<UUID>()

        return trip.checklistItems.filter { checklistItem in
            guard let packingItemID = checklistItem.packingItem?.id,
                  !seenPackingItemIDs.contains(packingItemID) else {
                return false
            }

            seenPackingItemIDs.insert(packingItemID)
            return true
        }
    }

    private var canSave: Bool {
        !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !uniqueChecklistItems.isEmpty
    }

    private func saveTemplate() {
        guard canSave else {
            return
        }

        let trimmedName = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchingTemplate = existingTemplates.first {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
        let template: PackingTemplate

        if let matchingTemplate {
            template = matchingTemplate
        } else {
            template = PackingTemplate(name: trimmedName)
            modelContext.insert(template)
        }

        template.name = trimmedName

        for item in template.items {
            modelContext.delete(item)
        }
        template.items.removeAll()

        for checklistItem in uniqueChecklistItems {
            guard let packingItem = checklistItem.packingItem else {
                continue
            }

            let templateItem = PackingTemplateItem(
                template: template,
                packingItem: packingItem,
                quantity: checklistItem.quantity,
                notes: checklistItem.notes
            )
            modelContext.insert(templateItem)
            template.items.append(templateItem)
        }

        do {
            try modelContext.save()
            dismiss()
            onSaved()
        } catch {
            errorMessage = "Could not save template. Please try again."
        }
    }
}

private enum TripFormField: Hashable {
    case name
    case destination
}

private struct EditTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var trip: Trip
    var onSaved: () -> Void = { }

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var tripType = TripType.weekend
    @FocusState private var focusedField: TripFormField?

    var body: some View {
        Form {
            Section("Trip") {
                TextField("Trip Name", text: $name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .destination
                    }

                TextField("Destination", text: $destination)
                    .focused($focusedField, equals: .destination)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }

                Picker("Trip Type", selection: $tripType) {
                    ForEach(TripType.allCases) { tripType in
                        Text(tripType.displayName).tag(tripType)
                    }
                }
            }

            Section("Dates") {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
            }
        }
        .navigationTitle("Edit Trip")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    focusedField = nil
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    focusedField = nil
                    save()
                }
                .disabled(!canSave)
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .onAppear {
            name = trip.name
            destination = trip.destination
            startDate = trip.startDate
            endDate = max(trip.endDate, trip.startDate)
            tripType = trip.selectedTripType
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate >= startDate
    }

    private func save() {
        guard canSave else {
            return
        }

        trip.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.startDate = startDate
        trip.endDate = endDate
        trip.selectedTripType = tripType

        try? modelContext.save()
        dismiss()
        onSaved()
    }
}

private struct TripSummaryCard: View {
    let trip: Trip
    let totalCount: Int
    let packedCount: Int

    private var progress: Double {
        guard totalCount > 0 else {
            return 0
        }

        return Double(packedCount) / Double(totalCount)
    }

    private var percentage: Int {
        Int((progress * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.title3.weight(.semibold))

                Text(trip.destination)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("\(formattedDate(trip.startDate)) - \(formattedDate(trip.endDate))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)

            HStack {
                SummaryMetric(value: "\(totalCount)", label: "Items")
                Spacer()
                SummaryMetric(value: "\(packedCount)", label: "Packed")
                Spacer()
                SummaryMetric(value: "\(percentage)%", label: "Complete")
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}

private struct SummaryMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ChecklistRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var checklistItem: TripPackingItem

    var body: some View {
        Button {
            togglePacked()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: checklistItem.isPacked ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(checklistItem.isPacked ? .green : .secondary)
                    .frame(width: 44, height: 44)

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

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    private func togglePacked() {
        checklistItem.isPacked.toggle()
        try? modelContext.save()
    }
}

private struct AddTripItemsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let trip: Trip
    let items: [PackingItem]
    @State private var addedItemIDs: Set<UUID> = []
    @State private var toastMessage: String?

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
                            toastMessage = "Item added"
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
        .toast(message: $toastMessage)
    }
}
