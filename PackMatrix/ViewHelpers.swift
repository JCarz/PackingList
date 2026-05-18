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

extension Array where Element == String {
    var displayText: String {
        isEmpty ? "Any" : joined(separator: ", ")
    }
}

extension String {
    var commaSeparatedValues: [String] {
        split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
