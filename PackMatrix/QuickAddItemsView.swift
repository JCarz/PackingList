import SwiftUI
import SwiftData

struct QuickAddItemsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingCategory.sortOrder) private var categories: [PackingCategory]

    @State private var selectedCategoryID: UUID?
    @State private var itemNames = ""

    var onQuickAddCompleted: (Int) -> Void = { _ in }

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
            }
        }
        .navigationTitle("Quick Add")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    save()
                }
                .disabled(selectedCategory == nil || parsedItemNames.isEmpty)
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
        var existingNames = Set(selectedCategory.items.map { $0.name.normalizedItemName })
        for name in parsedItemNames {
            let normalizedName = name.normalizedItemName
            guard !existingNames.contains(normalizedName) else {
                continue
            }

            let item = PackingItem(name: name, category: selectedCategory)
            modelContext.insert(item)
            selectedCategory.items.append(item)
            existingNames.insert(normalizedName)
            addedCount += 1
        }

        try? modelContext.save()
        dismiss()
        if addedCount > 0 {
            onQuickAddCompleted(addedCount)
        }
    }
}

private extension String {
    var normalizedItemName: String {
        trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }
}
