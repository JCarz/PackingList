import Foundation
import SwiftData

enum SampleData {
    static func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<PackingCategory>()

        guard let existingCategories = try? context.fetch(descriptor), existingCategories.isEmpty else {
            return
        }

        let categories = [
            PackingCategory(name: "Bedroom", sortOrder: 0),
            PackingCategory(name: "Bathroom", sortOrder: 1),
            PackingCategory(name: "Clothing", sortOrder: 2),
            PackingCategory(name: "Electronics", sortOrder: 3),
            PackingCategory(name: "Documents", sortOrder: 4),
            PackingCategory(name: "Medication", sortOrder: 5),
            PackingCategory(name: "Travel Gear", sortOrder: 6)
        ]

        for category in categories {
            context.insert(category)
        }

        add("Toothbrush", to: "Bathroom", categories: categories, context: context, always: true)
        add("Underwear", to: "Clothing", categories: categories, context: context, always: true)
        add("Phone charger", to: "Electronics", categories: categories, context: context, always: true)
        add("Contact lenses", to: "Bathroom", categories: categories, context: context, tripTypes: ["Selected", "International"])
        add("Passport", to: "Documents", categories: categories, context: context, tripTypes: ["International"])
        add("Sunscreen", to: "Bathroom", categories: categories, context: context, tripTypes: ["Beach", "Hot Weather"], destinations: ["Beach", "Hot Weather"])
        add("Pajamas", to: "Bedroom", categories: categories, context: context, always: true)

        try? context.save()
    }

    private static func add(
        _ name: String,
        to categoryName: String,
        categories: [PackingCategory],
        context: ModelContext,
        always: Bool = false,
        tripTypes: [String] = [],
        destinations: [String] = []
    ) {
        guard let category = categories.first(where: { $0.name == categoryName }) else {
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
