import SwiftUI
import SwiftData

struct DebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [PackingCategory]
    @Query private var items: [PackingItem]
    @Query private var trips: [Trip]
    @Query private var checklistItems: [TripPackingItem]

    var body: some View {
        Form {
            Section("App Health") {
                LabeledContent("Categories", value: "\(categories.count)")
                LabeledContent("Master Packing Items", value: "\(items.count)")
                LabeledContent("Trips", value: "\(trips.count)")
                LabeledContent("Checklist Items", value: "\(checklistItems.count)")
            }

            Section {
                Button("Re-seed missing sample data") {
                    SampleData.seedIfNeeded(in: modelContext)
                }
            }
        }
        .navigationTitle("Debug")
    }
}
