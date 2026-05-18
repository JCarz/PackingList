import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingCategory.sortOrder) private var categories: [PackingCategory]

    @State private var name = ""
    @State private var selectedCategoryID: UUID?
    @State private var quantity = 1
    @State private var notes = ""
    @State private var isAlwaysPacked = false
    @State private var isOptional = false
    @State private var selectedTripTypes: Set<TripType> = []
    @State private var destinationsText = ""

    var body: some View {
        Form {
            Section("Item") {
                TextField("Name", text: $name)

                Picker("Category", selection: $selectedCategoryID) {
                    Text("Choose").tag(nil as UUID?)
                    ForEach(categories) { category in
                        Text(category.name).tag(category.id as UUID?)
                    }
                }

                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                TextField("Notes", text: $notes, axis: .vertical)
            }

            Section("Rules") {
                Toggle("Always pack", isOn: $isAlwaysPacked)
                Toggle("Optional", isOn: $isOptional)

                ForEach(TripType.allCases) { tripType in
                    Toggle(tripType.displayName, isOn: binding(for: tripType))
                }

                TextField("Destinations, separated by commas", text: $destinationsText)
            }
        }
        .navigationTitle("Add Item")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategory == nil)
            }
        }
        .onAppear {
            selectedCategoryID = selectedCategoryID ?? categories.first?.id
        }
    }

    private var selectedCategory: PackingCategory? {
        categories.first { $0.id == selectedCategoryID }
    }

    private func binding(for tripType: TripType) -> Binding<Bool> {
        Binding {
            selectedTripTypes.contains(tripType)
        } set: { isSelected in
            if isSelected {
                selectedTripTypes.insert(tripType)
            } else {
                selectedTripTypes.remove(tripType)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = PackingItem(
            name: trimmedName,
            category: selectedCategory,
            quantity: quantity,
            notes: notes,
            isAlwaysPacked: isAlwaysPacked,
            tripTypes: TripType.allCases.filter { selectedTripTypes.contains($0) },
            destinations: destinationsText.commaSeparatedValues,
            isOptional: isOptional
        )

        modelContext.insert(item)
        selectedCategory?.items.append(item)
        try? modelContext.save()
        dismiss()
    }
}
