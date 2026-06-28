import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingCategory.sortOrder) private var categories: [PackingCategory]
    @Query(sort: \PackingItem.name) private var existingItems: [PackingItem]

    @State private var name = ""
    @State private var selectedCategoryID: UUID?
    @State private var quantity = 1
    @State private var notes = ""
    @State private var isAlwaysPacked = false
    @State private var isOptional = false
    @State private var selectedTripTypes: Set<TripType> = []
    @State private var destinationsText = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: AddItemField?

    var onItemAdded: () -> Void = { }

    var body: some View {
        Form {
            Section("Item Details") {
                TextField("Item Name", text: $name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .notes
                    }

                Picker("Category (Required)", selection: $selectedCategoryID) {
                    Text("Select Category").tag(nil as UUID?)
                    ForEach(categories) { category in
                        Text(category.name).tag(category.id as UUID?)
                    }
                }

                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                Toggle("Always Pack", isOn: $isAlwaysPacked)
                TextField("Notes", text: $notes, axis: .vertical)
                    .focused($focusedField, equals: .notes)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .destinations
                    }
            }

            Section("Rules") {
                Toggle("Optional", isOn: $isOptional)

                ForEach(TripType.allCases) { tripType in
                    Toggle(tripType.displayName, isOn: binding(for: tripType))
                }

                TextField("Destinations, separated by commas", text: $destinationsText)
                    .focused($focusedField, equals: .destinations)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Add Item")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    focusedField = nil
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    focusedField = nil
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategory == nil)
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    focusedField = nil
                }
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
        guard !trimmedName.isEmpty, let selectedCategory else {
            return
        }

        let existingNames = Set(existingItems.map { $0.name.normalizedPackingItemName })
        guard !existingNames.contains(trimmedName.normalizedPackingItemName) else {
            errorMessage = "An item with this name already exists."
            return
        }

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
        selectedCategory.items.append(item)
        try? modelContext.save()
        dismiss()
        onItemAdded()
    }
}

private enum AddItemField: Hashable {
    case name
    case notes
    case destinations
}
