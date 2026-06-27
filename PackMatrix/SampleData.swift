import Foundation
import SwiftData

enum SampleData {
    static func seedIfNeeded(in context: ModelContext) {
        guard let existingCategories = try? context.fetch(FetchDescriptor<PackingCategory>()),
              let existingItems = try? context.fetch(FetchDescriptor<PackingItem>()) else {
            return
        }

        let categoryNames = [
            "Fucked Without It",
            "Bedroom",
            "Bathroom",
            "Clothing",
            "Electronics",
            "Documents",
            "Medication",
            "Travel Gear"
        ]

        var categories = existingCategories
        var categoryNamesByNormalizedName: [String: PackingCategory] = [:]
        for category in categories {
            categoryNamesByNormalizedName[category.name.normalizedSeedName] = categoryNamesByNormalizedName[category.name.normalizedSeedName] ?? category
        }

        for (sortOrder, name) in categoryNames.enumerated() {
            let normalizedName = name.normalizedSeedName

            if let category = categoryNamesByNormalizedName[normalizedName] {
                category.sortOrder = sortOrder
            } else {
                let category = PackingCategory(name: name, sortOrder: sortOrder)
                context.insert(category)
                categories.append(category)
                categoryNamesByNormalizedName[normalizedName] = category
            }
        }

        var existingItemNames = Set(existingItems.map { $0.name.normalizedSeedName })

        add("Toothbrush", to: "Bathroom", categories: categories, existingItemNames: &existingItemNames, context: context, always: true)
        add("Underwear", to: "Clothing", categories: categories, existingItemNames: &existingItemNames, context: context, always: true)
        add("Phone charger", to: "Electronics", categories: categories, existingItemNames: &existingItemNames, context: context, always: true)
        add("Contact lenses", to: "Bathroom", categories: categories, existingItemNames: &existingItemNames, context: context, tripTypes: [.international])
        add("Passport", to: "Documents", categories: categories, existingItemNames: &existingItemNames, context: context, tripTypes: [.international])
        add("Sunscreen", to: "Bathroom", categories: categories, existingItemNames: &existingItemNames, context: context, tripTypes: [.beach], destinations: ["Beach", "Hot Weather"])
        add("Pajamas", to: "Bedroom", categories: categories, existingItemNames: &existingItemNames, context: context, always: true)

        try? context.save()
    }

    private static func add(
        _ name: String,
        to categoryName: String,
        categories: [PackingCategory],
        existingItemNames: inout Set<String>,
        context: ModelContext,
        always: Bool = false,
        tripTypes: [TripType] = [],
        destinations: [String] = []
    ) {
        guard let category = categories.first(where: { $0.name.normalizedSeedName == categoryName.normalizedSeedName }) else {
            return
        }

        let normalizedName = name.normalizedSeedName
        guard !existingItemNames.contains(normalizedName) else {
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
        existingItemNames.insert(normalizedName)
    }
}

private extension String {
    var normalizedSeedName: String {
        trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }
}
