import SwiftUI
import SwiftData

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingItem.name) private var packingItems: [PackingItem]
    @Query(sort: \Trip.startDate, order: .reverse) private var previousTrips: [Trip]

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var tripType = TripType.weekend
    @State private var sourceTripID: UUID?

    var body: some View {
        Form {
            Section("Trip") {
                TextField("Name", text: $name)
                TextField("Destination", text: $destination)

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

            Section("Packing List") {
                Picker("Start With", selection: $sourceTripID) {
                    Text("Generate from rules").tag(nil as UUID?)
                    ForEach(previousTrips) { trip in
                        Text(trip.name).tag(trip.id as UUID?)
                    }
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

            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    createTrip()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func createTrip() {
        let trip = Trip(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: endDate,
            tripType: tripType
        )

        modelContext.insert(trip)

        if let sourceTrip {
            PackingListGenerator.duplicateChecklist(from: sourceTrip, to: trip, in: modelContext)
        } else {
            PackingListGenerator.generateChecklist(for: trip, from: packingItems, in: modelContext)
        }

        try? modelContext.save()
        dismiss()
    }

    private var sourceTrip: Trip? {
        previousTrips.first { $0.id == sourceTripID }
    }
}
