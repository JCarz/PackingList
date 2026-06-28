import SwiftUI
import SwiftData

struct QuickAddItemsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingCategory.sortOrder) private var categories: [PackingCategory]
    @Query(sort: \PackingItem.name) private var existingItems: [PackingItem]

    @State private var selectedCategoryID: UUID?
    @State private var itemNames = ""
    @FocusState private var isItemNamesFocused: Bool

    var onQuickAddCompleted: (Int, Int) -> Void = { _, _ in }

    var body: some View {
        Form {
            Section("Category") {
                Picker("Category", selection: $selectedCategoryID) {
                    Text("Choose").tag(nil as UUID?)
                    ForEach(categories) { category in
                        Text(category.name).tag(category.id as UUID?)
                    }
                }
            }

            Section("Items") {
                TextEditor(text: $itemNames)
                    .frame(minHeight: 160)
                    .focused($isItemNamesFocused)
            }
        }
        .navigationTitle("Quick Add")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isItemNamesFocused = false
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    isItemNamesFocused = false
                    save()
                }
                .disabled(selectedCategory == nil || parsedItemNames.isEmpty)
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    isItemNamesFocused = false
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

    private var parsedItemNames: [String] {
        itemNames
            .split { character in
                character.isNewline || character == ","
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func save() {
        guard let selectedCategory else {
            return
        }

        var addedCount = 0
        var skippedDuplicateCount = 0
        var existingNames = Set(existingItems.map { $0.name.normalizedPackingItemName })
        for name in parsedItemNames {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = trimmedName.normalizedPackingItemName
            guard !existingNames.contains(normalizedName) else {
                skippedDuplicateCount += 1
                continue
            }

            let item = PackingItem(name: trimmedName, category: selectedCategory)
            modelContext.insert(item)
            selectedCategory.items.append(item)
            existingNames.insert(normalizedName)
            addedCount += 1
        }

        try? modelContext.save()
        dismiss()
        onQuickAddCompleted(addedCount, skippedDuplicateCount)
    }
}
