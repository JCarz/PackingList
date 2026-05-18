import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingCategory.sortOrder) private var categories: [PackingCategory]

    @Bindable var item: PackingItem
    @State private var destinationsText = ""
    @State private var selectedCategoryID: UUID?

    var body: some View {
        Form {
            Section("Item") {
                TextField("Name", text: $item.name)

                Picker("Category", selection: $selectedCategoryID) {
                    ForEach(categories) { category in
                        Text(category.name).tag(category.id as UUID?)
                    }
                }

                Stepper("Quantity: \(item.quantity)", value: $item.quantity, in: 1...99)
                TextField("Notes", text: $item.notes, axis: .vertical)
            }

            Section("Rules") {
                Toggle("Always pack", isOn: $item.isAlwaysPacked)
                Toggle("Optional", isOn: $item.isOptional)

                ForEach(TripType.allCases) { tripType in
                    Toggle(tripType.displayName, isOn: binding(for: tripType))
                }

                TextField("Destinations, separated by commas", text: $destinationsText)
                    .onSubmit(updateDestinations)
            }
        }
        .navigationTitle(item.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    updateCategory()
                    updateDestinations()
                    try? modelContext.save()
                }
            }
        }
        .onAppear {
            destinationsText = item.destinations.joined(separator: ", ")
            selectedCategoryID = item.category?.id ?? categories.first?.id
        }
        .onDisappear {
            updateCategory()
            updateDestinations()
            try? modelContext.save()
        }
    }

    private func binding(for tripType: TripType) -> Binding<Bool> {
        Binding {
            item.selectedTripTypes.contains(tripType)
        } set: { isSelected in
            var selectedTripTypes = Set(item.selectedTripTypes)

            if isSelected {
                selectedTripTypes.insert(tripType)
            } else if !isSelected {
                selectedTripTypes.remove(tripType)
            }

            item.selectedTripTypes = TripType.allCases.filter { selectedTripTypes.contains($0) }
        }
    }

    private func updateDestinations() {
        item.destinations = destinationsText.commaSeparatedValues
    }

    private func updateCategory() {
        item.category = categories.first { $0.id == selectedCategoryID }
    }
}
