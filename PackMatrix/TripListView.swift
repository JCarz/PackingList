import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]
    @State private var showingCreateTrip = false
    @State private var createdTripToOpen: Trip?
    @State private var selectedSection = TripListSection.active
    @State private var toastMessage: String?
    @State private var tripsPendingDeletion: [Trip] = []
    @State private var recentlyDeletedTrips: [DeletedTripSnapshot] = []
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            ForEach(visibleTrips) { trip in
                NavigationLink {
                    TripDetailView(trip: trip)
                } label: {
                    TripRow(trip: trip)
                }
                .swipeActions(edge: .leading) {
                    if trip.isArchived {
                        Button {
                            restoreTrip(trip)
                        } label: {
                            Label("Restore", systemImage: "tray.and.arrow.up")
                        }
                        .tint(.green)
                    } else {
                        Button {
                            archiveTrip(trip)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(.orange)
                    }
                }
            }
            .onDelete(perform: deleteTrips)
        }
        .navigationTitle("Trips")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Trips", selection: $selectedSection) {
                    ForEach(TripListSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateTrip = true
                } label: {
                    Label("Create Trip", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateTrip) {
            NavigationStack {
                CreateTripView { trip in
                    createdTripToOpen = trip
                    recentlyDeletedTrips = []
                    toastMessage = "Trip created"
                }
            }
        }
        .navigationDestination(item: $createdTripToOpen) { trip in
            TripDetailView(trip: trip)
        }
        .confirmationDialog("Delete Trip?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deletePendingTrips()
            }

            Button("Cancel", role: .cancel) {
                tripsPendingDeletion = []
            }
        } message: {
            Text("This will remove the trip and its checklist items.")
        }
        .overlay {
            if visibleTrips.isEmpty {
                ContentUnavailableView {
                    Label(emptyStateTitle, systemImage: emptyStateImage)
                } description: {
                    Text(emptyStateDescription)
                } actions: {
                    if selectedSection == .active {
                        Button("Create Trip") {
                            showingCreateTrip = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .toast(
            message: $toastMessage,
            actionTitle: toastActionTitle,
            duration: toastDuration,
            action: restoreDeletedTrips
        )
        .onChange(of: toastMessage) { _, newValue in
            if newValue == nil {
                recentlyDeletedTrips = []
            }
        }
    }

    private var visibleTrips: [Trip] {
        trips.filter { trip in
            selectedSection == .archive ? trip.isArchived : !trip.isArchived
        }
    }

    private var emptyStateTitle: String {
        selectedSection == .archive ? "No archived trips" : "No trips yet"
    }

    private var emptyStateImage: String {
        selectedSection == .archive ? "archivebox" : "suitcase"
    }

    private var emptyStateDescription: String {
        selectedSection == .archive ? "Archived trips will appear here." : "Create a trip to generate a checklist from your packing rules."
    }

    private var toastActionTitle: String? {
        recentlyDeletedTrips.isEmpty ? nil : "Undo"
    }

    private var toastDuration: TimeInterval {
        recentlyDeletedTrips.isEmpty ? 2 : 5
    }

    private func deleteTrips(at offsets: IndexSet) {
        tripsPendingDeletion = offsets.compactMap { offset in
            visibleTrips.indices.contains(offset) ? visibleTrips[offset] : nil
        }

        if !tripsPendingDeletion.isEmpty {
            showingDeleteConfirmation = true
        }
    }

    private func deletePendingTrips() {
        guard !tripsPendingDeletion.isEmpty else {
            return
        }

        let deletedTripSnapshots = tripsPendingDeletion.map { DeletedTripSnapshot(trip: $0) }

        for trip in tripsPendingDeletion {
            for checklistItem in trip.checklistItems {
                modelContext.delete(checklistItem)
            }
            trip.checklistItems.removeAll()
            modelContext.delete(trip)
        }

        do {
            try modelContext.save()
            recentlyDeletedTrips = deletedTripSnapshots
            toastMessage = tripsPendingDeletion.count == 1 ? "Trip deleted" : "Trips deleted"
            tripsPendingDeletion = []
        } catch {
            modelContext.rollback()
            recentlyDeletedTrips = []
            tripsPendingDeletion = []
            toastMessage = "Could not delete trip"
        }
    }

    private func restoreDeletedTrips() {
        guard !recentlyDeletedTrips.isEmpty else {
            return
        }

        let snapshotsToRestore = recentlyDeletedTrips
        recentlyDeletedTrips = []
        toastMessage = nil

        for snapshot in snapshotsToRestore {
            let restoredTrip = snapshot.restoreTrip()
            modelContext.insert(restoredTrip)

            for checklistSnapshot in snapshot.checklistItems {
                let restoredChecklistItem = checklistSnapshot.restoreChecklistItem(for: restoredTrip)
                modelContext.insert(restoredChecklistItem)
                restoredTrip.checklistItems.append(restoredChecklistItem)
            }
        }

        do {
            try modelContext.save()
            toastMessage = snapshotsToRestore.count == 1 ? "Trip restored" : "Trips restored"
        } catch {
            modelContext.rollback()
            toastMessage = "Could not restore trip"
        }
    }

    private func archiveTrip(_ trip: Trip) {
        trip.isArchived = true

        do {
            try modelContext.save()
            toastMessage = "Trip archived"
        } catch {
            modelContext.rollback()
            toastMessage = "Could not archive trip"
        }
    }

    private func restoreTrip(_ trip: Trip) {
        trip.isArchived = false

        do {
            try modelContext.save()
            toastMessage = "Trip restored"
        } catch {
            modelContext.rollback()
            toastMessage = "Could not restore trip"
        }
    }
}

private enum TripListSection: CaseIterable, Identifiable {
    case active
    case archive

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .active:
            "Active"
        case .archive:
            "Archive"
        }
    }
}

private struct DeletedTripSnapshot {
    let id: UUID
    let name: String
    let destination: String
    let startDate: Date
    let endDate: Date
    let tripType: TripType
    let isArchived: Bool
    let checklistItems: [DeletedChecklistItemSnapshot]

    init(trip: Trip) {
        id = trip.id
        name = trip.name
        destination = trip.destination
        startDate = trip.startDate
        endDate = trip.endDate
        tripType = trip.selectedTripType
        isArchived = trip.isArchived
        checklistItems = trip.checklistItems.map(DeletedChecklistItemSnapshot.init)
    }

    func restoreTrip() -> Trip {
        Trip(
            id: id,
            name: name,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            tripType: tripType,
            isArchived: isArchived
        )
    }
}

private struct DeletedChecklistItemSnapshot {
    let id: UUID
    let isPacked: Bool
    let quantity: Int
    let notes: String
    let wasManuallyAdded: Bool
    let packingItem: PackingItem?

    init(checklistItem: TripPackingItem) {
        id = checklistItem.id
        isPacked = checklistItem.isPacked
        quantity = checklistItem.quantity
        notes = checklistItem.notes
        wasManuallyAdded = checklistItem.wasManuallyAdded
        packingItem = checklistItem.packingItem
    }

    func restoreChecklistItem(for trip: Trip) -> TripPackingItem {
        TripPackingItem(
            id: id,
            trip: trip,
            packingItem: packingItem,
            isPacked: isPacked,
            quantity: quantity,
            notes: notes,
            wasManuallyAdded: wasManuallyAdded
        )
    }
}

private struct TripRow: View {
    let trip: Trip

    private var totalCount: Int {
        trip.checklistItems.count
    }

    private var packedCount: Int {
        trip.checklistItems.filter(\.isPacked).count
    }

    private var packingProgress: Double {
        guard totalCount > 0 else {
            return 0
        }

        return Double(packedCount) / Double(totalCount)
    }

    private var packingPercentage: Int {
        Int((packingProgress * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(trip.name)
                .font(.headline)

            Text(trip.destination)
                .foregroundStyle(.secondary)

            Text("\(formattedDate(trip.startDate)) - \(formattedDate(trip.endDate))")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: packingProgress)

            Text("\(packedCount) / \(totalCount) packed (\(packingPercentage)%)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}
