import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Query private var trips: [Trip]
    @Query private var checklistItems: [TripPackingItem]

    private var packedItems: [TripPackingItem] {
        checklistItems.filter(\.isPacked)
    }

    private var mostPackedItemName: String {
        mostCommonName(from: packedItems.compactMap { $0.packingItem?.name })
    }

    private var mostUsedCategoryName: String {
        mostCommonName(from: packedItems.compactMap { $0.packingItem?.category?.name })
    }

    var body: some View {
        Form {
            Section("Overview") {
                StatisticRow(
                    title: "Total trips created",
                    value: "\(trips.count)",
                    systemImage: "suitcase"
                )

                StatisticRow(
                    title: "Total items packed",
                    value: "\(packedItems.count)",
                    systemImage: "checkmark.circle"
                )
            }

            Section("Most Used") {
                StatisticRow(
                    title: "Most packed item",
                    value: mostPackedItemName,
                    systemImage: "star"
                )

                StatisticRow(
                    title: "Most used category",
                    value: mostUsedCategoryName,
                    systemImage: "folder"
                )
            }
        }
        .navigationTitle("Statistics")
    }

    private func mostCommonName(from names: [String]) -> String {
        var counts: [String: Int] = [:]

        for name in names {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

            if !trimmedName.isEmpty {
                counts[trimmedName, default: 0] += 1
            }
        }

        return counts
            .sorted {
                if $0.value == $1.value {
                    return $0.key.localizedStandardCompare($1.key) == .orderedAscending
                }

                return $0.value > $1.value
            }
            .first?
            .key ?? "None yet"
    }
}

private struct StatisticRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        LabeledContent {
            Text(value)
                .fontWeight(.semibold)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}
