import SwiftUI
import SwiftData

struct QuickAddItemsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingCategory.sortOrder) private var categories: [PackingCategory]

    @State private var selectedCategoryID: UUID?
    @State private var itemNames = ""

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
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func save() {
        guard let selectedCategory else {
            return
        }

        for name in parsedItemNames {
            let item = PackingItem(name: name, category: selectedCategory)
            modelContext.insert(item)
            selectedCategory.items.append(item)
        }

        try? modelContext.save()
        dismiss()
    }
}
