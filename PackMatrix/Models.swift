import Foundation
import SwiftData

enum TripType: String, CaseIterable, Codable, Identifiable {
    case weekend
    case international
    case domestic
    case beach
    case work
    case familyVisit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekend:
            "Weekend"
        case .international:
            "International"
        case .domestic:
            "Domestic"
        case .beach:
            "Beach"
        case .work:
            "Work"
        case .familyVisit:
            "Family Visit"
        }
    }

    init(storedValue: String) {
        let normalizedValue = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let tripType = TripType(rawValue: normalizedValue) {
            self = tripType
            return
        }

        switch normalizedValue.lowercased() {
        case "weekend":
            self = .weekend
        case "international", "selected":
            self = .international
        case "domestic":
            self = .domestic
        case "beach":
            self = .beach
        case "business", "work":
            self = .work
        case "family visit", "familyvisit":
            self = .familyVisit
        case "hot weather", "hotweather", "cold weather", "coldweather", "camping", "wedding":
            self = .domestic
        default:
            self = .weekend
        }
    }
}

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
    var selectedTripTypes: [TripType] {
        get {
            tripTypes.map(TripType.init(storedValue:))
        }
        set {
            tripTypes = newValue.map(\.rawValue)
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: PackingCategory? = nil,
        quantity: Int = 1,
        notes: String = "",
        isAlwaysPacked: Bool = false,
        tripTypes: [TripType] = [],
        destinations: [String] = [],
        isOptional: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = max(1, quantity)
        self.notes = notes
        self.isAlwaysPacked = isAlwaysPacked
        self.tripTypes = tripTypes.map(\.rawValue)
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
    var isArchived: Bool = false
    var selectedTripType: TripType {
        get {
            TripType(storedValue: tripType)
        }
        set {
            tripType = newValue.rawValue
        }
    }

    @Relationship(deleteRule: .cascade, inverse: \TripPackingItem.trip)
    var checklistItems: [TripPackingItem]

    init(
        id: UUID = UUID(),
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        tripType: TripType,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.tripType = tripType.rawValue
        self.isArchived = isArchived
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

@Model
final class PackingTemplate {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PackingTemplateItem.template)
    var items: [PackingTemplateItem]

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.items = []
    }
}

@Model
final class PackingTemplateItem {
    var id: UUID
    var quantity: Int
    var notes: String

    var template: PackingTemplate?
    var packingItem: PackingItem?

    init(
        id: UUID = UUID(),
        template: PackingTemplate? = nil,
        packingItem: PackingItem? = nil,
        quantity: Int = 1,
        notes: String = ""
    ) {
        self.id = id
        self.template = template
        self.packingItem = packingItem
        self.quantity = max(1, quantity)
        self.notes = notes
    }
}
