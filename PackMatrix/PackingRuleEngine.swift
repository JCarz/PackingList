import Foundation
import SwiftData

enum PackingListGenerator {
    static func matches(item: PackingItem, trip: Trip) -> Bool {
        if item.isAlwaysPacked {
            return true
        }

        if item.tripTypes.contains(trip.tripType) {
            return true
        }

        return false
    }

    static func matchesManualItem(_ checklistItem: TripPackingItem) -> Bool {
        checklistItem.wasManuallyAdded
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

    static func copyChecklist(from sourceTrip: Trip, to newTrip: Trip, in context: ModelContext) {
        var addedPackingItemIDs = Set(newTrip.checklistItems.compactMap { $0.packingItem?.id })

        for sourceItem in sourceTrip.checklistItems {
            guard let packingItem = sourceItem.packingItem,
                  !addedPackingItemIDs.contains(packingItem.id) else {
                continue
            }

            let checklistItem = TripPackingItem(
                trip: newTrip,
                packingItem: packingItem,
                isPacked: sourceItem.isPacked,
                quantity: sourceItem.quantity,
                notes: sourceItem.notes,
                wasManuallyAdded: sourceItem.wasManuallyAdded
            )
            context.insert(checklistItem)
            newTrip.checklistItems.append(checklistItem)
            addedPackingItemIDs.insert(packingItem.id)
        }
    }

    static func applyTemplate(_ template: PackingTemplate, to trip: Trip, in context: ModelContext) {
        var addedPackingItemIDs = Set(trip.checklistItems.compactMap { $0.packingItem?.id })

        for templateItem in template.items {
            guard let packingItem = templateItem.packingItem,
                  !addedPackingItemIDs.contains(packingItem.id) else {
                continue
            }

            let checklistItem = TripPackingItem(
                trip: trip,
                packingItem: packingItem,
                quantity: templateItem.quantity,
                notes: templateItem.notes
            )
            context.insert(checklistItem)
            trip.checklistItems.append(checklistItem)
            addedPackingItemIDs.insert(packingItem.id)
        }
    }
}
