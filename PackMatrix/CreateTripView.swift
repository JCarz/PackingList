import SwiftUI
import SwiftData

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingItem.name) private var packingItems: [PackingItem]
    @Query(sort: \Trip.startDate, order: .reverse) private var previousTrips: [Trip]
    @Query(sort: \PackingTemplate.name) private var templates: [PackingTemplate]

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var tripType = TripType.weekend
    @State private var startingPoint = TripStartingPoint.rules
    @State private var isSaving = false
    @State private var showingDuplicateWarning = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

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
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)

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

            if !recentlyPackedItems.isEmpty {
                Section("Recently Packed") {
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

            Section {
                Button {
                    startTripCreation()
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Generate Packing List")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canCreateTrip || isSaving)
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
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
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

        do {
            try modelContext.save()
            statusMessage = "Trip created."

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
