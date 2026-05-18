import SwiftUI
import SwiftData

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingItem.name) private var packingItems: [PackingItem]

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var tripType = PackMatrixOptions.tripTypes.first ?? "Weekend"

    var body: some View {
        Form {
            Section("Trip") {
                TextField("Name", text: $name)
                TextField("Destination", text: $destination)

                Picker("Trip Type", selection: $tripType) {
                    ForEach(PackMatrixOptions.tripTypes, id: \.self) { tripType in
                        Text(tripType).tag(tripType)
                    }
                }
            }

            Section("Dates") {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
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
        PackingRuleEngine.generateChecklist(for: trip, from: packingItems, in: modelContext)
        try? modelContext.save()
        dismiss()
    }
}
