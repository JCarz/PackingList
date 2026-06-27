import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingCategory.sortOrder) private var categories: [PackingCategory]

    @Bindable var item: PackingItem
    @State private var destinationsText = ""
    @State private var selectedCategoryID: UUID?
    @State private var originalName = ""
    @State private var toastMessage: String?

    var body: some View {
        Form {
            Section("Item") {
                TextField("Name", text: $item.name)

                Picker("Category (Required)", selection: $selectedCategoryID) {
                    Text("Select Category").tag(nil as UUID?)
                    ForEach(categories) { category in
                        Text(category.name).tag(category.id as UUID?)
                    }
                }

                Stepper("Quantity: \(item.quantity)", value: $item.quantity, in: 1...99)
                TextField("Notes", text: $item.notes, axis: .vertical)

                if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Item name is required.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if selectedCategory == nil {
                    Text("Category is required.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
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
                    updateName()
                    updateCategory()
                    updateDestinations()
                    try? modelContext.save()
                    toastMessage = "Changes saved"
                }
                .disabled(!canSave)
            }
        }
        .onAppear {
            originalName = item.name
            destinationsText = item.destinations.joined(separator: ", ")
            selectedCategoryID = item.category?.id ?? categories.first?.id
        }
        .onDisappear {
            updateName()
            if selectedCategory != nil {
                updateCategory()
            }
            updateDestinations()
            try? modelContext.save()
        }
        .toast(message: $toastMessage)
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

    private func updateName() {
        let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            item.name = originalName.isEmpty ? "Untitled Item" : originalName
        } else {
            item.name = trimmedName
        }
    }

    private func updateCategory() {
        item.category = selectedCategory
    }

    private var selectedCategory: PackingCategory? {
        categories.first { $0.id == selectedCategoryID }
    }

    private var canSave: Bool {
        !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedCategory != nil
    }
}
