import SwiftUI
import SwiftData

struct TripListView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]
    @State private var showingCreateTrip = false

    var body: some View {
        List {
            ForEach(trips) { trip in
                NavigationLink {
                    TripDetailView(trip: trip)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.name)
                            .font(.headline)
                        Text("\(trip.destination) • \(trip.tripType)")
                            .foregroundStyle(.secondary)
                        Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) - \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Trips")
        .toolbar {
            Button {
                showingCreateTrip = true
            } label: {
                Label("Create Trip", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingCreateTrip) {
            NavigationStack {
                CreateTripView()
            }
        }
        .overlay {
            if trips.isEmpty {
                ContentUnavailableView(
                    "No Trips",
                    systemImage: "suitcase",
                    description: Text("Create a trip to generate a checklist from your packing rules.")
                )
            }
        }
    }
}
