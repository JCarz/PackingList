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

                ForEach(PackMatrixOptions.tripTypes, id: \.self) { tripType in
                    Toggle(tripType, isOn: binding(for: tripType))
                }

                TextField("Destinations, separated by commas", text: $destinationsText)
                    .textInputAutocapitalization(.words)
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

    private func binding(for tripType: String) -> Binding<Bool> {
        Binding {
            item.tripTypes.contains(tripType)
        } set: { isSelected in
            if isSelected, !item.tripTypes.contains(tripType) {
                item.tripTypes.append(tripType)
                item.tripTypes.sort()
            } else if !isSelected {
                item.tripTypes.removeAll { $0 == tripType }
            }
        }
    }

    private func updateDestinations() {
        item.destinations = destinationsText.commaSeparatedValues
    }

    private func updateCategory() {
        item.category = categories.first { $0.id == selectedCategoryID }
    }
}
