import Foundation
import SwiftData

enum PackingRuleEngine {
    static func matches(item: PackingItem, trip: Trip) -> Bool {
        if item.isAlwaysPacked {
            return true
        }

        if containsMatch(item.tripTypes, trip.tripType) {
            return true
        }

        if containsMatch(item.destinations, trip.destination) {
            return true
        }

        return false
    }

    static func generateChecklist(for trip: Trip, from items: [PackingItem], in context: ModelContext) {
        for item in items where matches(item: item, trip: trip) {
            guard !trip.checklistItems.contains(where: { $0.packingItem?.id == item.id }) else {
                continue
            }

            let checklistItem = TripPackingItem(
                trip: trip,
                packingItem: item,
                quantity: item.quantity,
                notes: item.notes
            )
            context.insert(checklistItem)
            trip.checklistItems.append(checklistItem)
        }
    }

    static func manuallyAdd(_ item: PackingItem, to trip: Trip, in context: ModelContext) {
        guard !trip.checklistItems.contains(where: { $0.packingItem?.id == item.id }) else {
            return
        }

        let checklistItem = TripPackingItem(
            trip: trip,
            packingItem: item,
            quantity: item.quantity,
            notes: item.notes,
            wasManuallyAdded: true
        )
        context.insert(checklistItem)
        trip.checklistItems.append(checklistItem)
    }

    private static func containsMatch(_ values: [String], _ candidate: String) -> Bool {
        let normalizedCandidate = normalize(candidate)

        return values.contains { value in
            let normalizedValue = normalize(value)
            return normalizedCandidate == normalizedValue
                || normalizedCandidate.contains(normalizedValue)
                || normalizedValue.contains(normalizedCandidate)
        }
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
