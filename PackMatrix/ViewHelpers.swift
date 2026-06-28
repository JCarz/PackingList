import Foundation

enum ListGrouping {
    static func categoriesWithItems(from items: [PackingItem]) -> [(PackingCategory, [PackingItem])] {
        let grouped = Dictionary(grouping: items) { item in
            item.category
        }

        return grouped.compactMap { category, items in
            guard let category else {
                return nil
            }
            return (category, items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        }
        .sorted {
            if $0.0.sortOrder == $1.0.sortOrder {
                return $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending
            }
            return $0.0.sortOrder < $1.0.sortOrder
        }
    }

    static func checklistByCategory(from items: [TripPackingItem]) -> [(PackingCategory, [TripPackingItem])] {
        let grouped = Dictionary(grouping: items) { item in
            item.packingItem?.category
        }

        return grouped.compactMap { category, items in
            guard let category else {
                return nil
            }
            return (category, items.sorted {
                ($0.packingItem?.name ?? "").localizedStandardCompare($1.packingItem?.name ?? "") == .orderedAscending
            })
        }
        .sorted {
            if $0.0.sortOrder == $1.0.sortOrder {
                return $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending
            }
            return $0.0.sortOrder < $1.0.sortOrder
        }
    }
}

enum QuickAddFeedback {
    static func message(addedCount: Int, skippedDuplicateCount: Int) -> String {
        let itemWord = addedCount == 1 ? "item" : "items"
        let duplicateWord = skippedDuplicateCount == 1 ? "duplicate" : "duplicates"

        if addedCount > 0 && skippedDuplicateCount > 0 {
            return "Added \(addedCount) \(itemWord), skipped \(skippedDuplicateCount) \(duplicateWord)"
        }

        if addedCount > 0 {
            return "Added \(addedCount) \(itemWord)"
        }

        return "Skipped \(skippedDuplicateCount) \(duplicateWord)"
    }
}

extension Array where Element == String {
    var displayText: String {
        isEmpty ? "Any" : joined(separator: ", ")
    }
}

extension Array where Element == TripType {
    var displayText: String {
        isEmpty ? "Any" : map(\.displayName).joined(separator: ", ")
    }
}

extension String {
    var commaSeparatedValues: [String] {
        split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var normalizedPackingItemName: String {
        trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }
}
