# PackMatrix Architecture Overview

PackMatrix is a local-first SwiftUI application backed by SwiftData. The architecture is intentionally lightweight so the app remains approachable for future contributors and easy to evolve toward an App Store release.

## Goals

- Keep user data local by default
- Use native Apple frameworks
- Keep views simple and focused
- Keep checklist generation logic outside of views
- Avoid backend, Firebase, authentication, and networking dependencies
- Leave room for future CloudKit sync

## High-Level Architecture

```text
SwiftUI Views
    |
    | read/write
    v
SwiftData Models
    |
    | used by
    v
PackingListGenerator
```

## SwiftUI Layer

SwiftUI powers all user-facing screens:

- `ContentView` chooses compact tabs or a split-view layout
- `MasterListView` shows the reusable packing inventory
- `AddItemView` and `ItemDetailView` create and edit master items
- `QuickAddItemsView` supports bulk item entry
- `TripListView` manages active and archived trips
- `CreateTripView` creates trips and generates checklists
- `TripDetailView` displays and edits trip checklists
- `StatisticsView` summarizes usage
- `DebugView` shows lightweight app health information

Compact layouts use `TabView` and `NavigationStack`. Wider layouts use `NavigationSplitView`.

## SwiftData Layer

The app registers its SwiftData models in `PackMatrixApp`:

- `PackingCategory`
- `PackingItem`
- `Trip`
- `TripPackingItem`
- `PackingTemplate`
- `PackingTemplateItem`

SwiftData handles local persistence. Relationships connect categories to items, trips to checklist rows, and templates to template rows.

## Rule Engine

`PackingListGenerator` owns checklist generation behavior. It keeps trip-generation logic out of the SwiftUI forms and centralizes duplicate prevention.

Current responsibilities:

- Match packing items to trips
- Generate checklist rows
- Manually add items
- Duplicate trip checklists
- Copy packed state when duplicating
- Apply packing templates
- Avoid duplicate checklist rows

## Data Flow

1. The user maintains a master list of `PackingItem` records.
2. Each item can belong to a `PackingCategory`.
3. Items can be marked always-packed or associated with one or more trip types.
4. The user creates a `Trip`.
5. `PackingListGenerator` creates `TripPackingItem` rows for matching master items.
6. The user checks items off as packed.
7. SwiftData persists changes locally.

## Local-First Storage

PackMatrix does not currently use a backend, account system, Firebase, or networking layer. This keeps the app private, fast, and simple.

## Future CloudKit Support

CloudKit sync is a planned future enhancement. A future implementation should preserve local-first behavior and use iCloud only as a sync layer.

Potential considerations:

- SwiftData CloudKit compatibility
- Conflict handling for edited trips and checklist rows
- Migration strategy for existing local stores
- Clear user-facing sync status

## App Store Readiness Notes

Before App Store submission, the project should add:

- Final screenshots
- Privacy policy
- App Store description and keywords
- App icon review across all required sizes
- Automated tests for checklist generation
- A release versioning strategy
