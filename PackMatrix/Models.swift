import Foundation
import SwiftData

@Model
final class PackingCategory {
    var id: UUID
    var name: String
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \PackingItem.category)
    var items: [PackingItem]

    init(id: UUID = UUID(), name: String, sortOrder: Int) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.items = []
    }
}

@Model
final class PackingItem {
    var id: UUID
    var name: String
    var quantity: Int
    var notes: String
    var isAlwaysPacked: Bool
    var tripTypes: [String]
    var destinations: [String]
    var isOptional: Bool

    var category: PackingCategory?

    init(
        id: UUID = UUID(),
        name: String,
        category: PackingCategory? = nil,
        quantity: Int = 1,
        notes: String = "",
        isAlwaysPacked: Bool = false,
        tripTypes: [String] = [],
        destinations: [String] = [],
        isOptional: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = max(1, quantity)
        self.notes = notes
        self.isAlwaysPacked = isAlwaysPacked
        self.tripTypes = tripTypes
        self.destinations = destinations
        self.isOptional = isOptional
    }
}

@Model
final class Trip {
    var id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var tripType: String

    @Relationship(deleteRule: .cascade, inverse: \TripPackingItem.trip)
    var checklistItems: [TripPackingItem]

    init(
        id: UUID = UUID(),
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        tripType: String
    ) {
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.tripType = tripType
        self.checklistItems = []
    }
}

@Model
final class TripPackingItem {
    var id: UUID
    var isPacked: Bool
    var quantity: Int
    var notes: String
    var wasManuallyAdded: Bool

    var trip: Trip?
    var packingItem: PackingItem?

    init(
        id: UUID = UUID(),
        trip: Trip? = nil,
        packingItem: PackingItem? = nil,
        isPacked: Bool = false,
        quantity: Int = 1,
        notes: String = "",
        wasManuallyAdded: Bool = false
    ) {
        self.id = id
        self.trip = trip
        self.packingItem = packingItem
        self.isPacked = isPacked
        self.quantity = max(1, quantity)
        self.notes = notes
        self.wasManuallyAdded = wasManuallyAdded
    }
}

enum PackMatrixOptions {
    static let tripTypes = [
        "Weekend",
        "Business",
        "International",
        "Beach",
        "Hot Weather",
        "Camping",
        "Selected"
    ]
}
