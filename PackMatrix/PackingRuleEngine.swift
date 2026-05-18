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
        var addedPackingItemIDs = Set(trip.checklistItems.compactMap { $0.packingItem?.id })

        for item in items where matches(item: item, trip: trip) {
            guard !addedPackingItemIDs.contains(item.id) else {
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
            addedPackingItemIDs.insert(item.id)
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

    static func duplicateChecklist(from sourceTrip: Trip, to newTrip: Trip, in context: ModelContext) {
        var addedPackingItemIDs = Set(newTrip.checklistItems.compactMap { $0.packingItem?.id })

        for sourceItem in sourceTrip.checklistItems {
            guard let packingItem = sourceItem.packingItem,
                  !addedPackingItemIDs.contains(packingItem.id) else {
                continue
            }

            let checklistItem = TripPackingItem(
                trip: newTrip,
                packingItem: packingItem,
                quantity: sourceItem.quantity,
                notes: sourceItem.notes,
                wasManuallyAdded: sourceItem.wasManuallyAdded
            )
            context.insert(checklistItem)
            newTrip.checklistItems.append(checklistItem)
            addedPackingItemIDs.insert(packingItem.id)
        }
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
