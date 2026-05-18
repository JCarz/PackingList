import Foundation
import SwiftData

enum SampleData {
    static func seedIfNeeded(in context: ModelContext) {
        guard let existingCategories = try? context.fetch(FetchDescriptor<PackingCategory>()),
              let existingItems = try? context.fetch(FetchDescriptor<PackingItem>()) else {
            return
        }

        let categoryNames = [
            "Fucked Without It"
            "Bedroom",
            "Bathroom",
            "Clothing",
            "Electronics",
            "Documents",
            "Medication",
            "Travel Gear"
        ]

        var categories = existingCategories

        for (sortOrder, name) in categoryNames.enumerated() {
            if let category = categories.first(where: { $0.name == name }) {
                category.sortOrder = sortOrder
            } else {
                let category = PackingCategory(name: name, sortOrder: sortOrder)
                context.insert(category)
                categories.append(category)
            }
        }

        add("Toothbrush", to: "Bathroom", categories: categories, existingItems: existingItems, context: context, always: true)
        add("Underwear", to: "Clothing", categories: categories, existingItems: existingItems, context: context, always: true)
        add("Phone charger", to: "Electronics", categories: categories, existingItems: existingItems, context: context, always: true)
        add("Contact lenses", to: "Bathroom", categories: categories, existingItems: existingItems, context: context, tripTypes: [.international])
        add("Passport", to: "Documents", categories: categories, existingItems: existingItems, context: context, tripTypes: [.international])
        add("Sunscreen", to: "Bathroom", categories: categories, existingItems: existingItems, context: context, tripTypes: [.beach], destinations: ["Beach", "Hot Weather"])
        add("Pajamas", to: "Bedroom", categories: categories, existingItems: existingItems, context: context, always: true)

        try? context.save()
    }

    private static func add(
        _ name: String,
        to categoryName: String,
        categories: [PackingCategory],
        existingItems: [PackingItem],
        context: ModelContext,
        always: Bool = false,
        tripTypes: [TripType] = [],
        destinations: [String] = []
    ) {
        guard let category = categories.first(where: { $0.name == categoryName }) else {
            return
        }

        guard !existingItems.contains(where: { $0.name == name }) else {
            return
        }

        let item = PackingItem(
            name: name,
            category: category,
            isAlwaysPacked: always,
            tripTypes: tripTypes,
            destinations: destinations
        )
        context.insert(item)
        category.items.append(item)
    }
}
