import SwiftUI
import SwiftData

enum SidebarSection: String, CaseIterable, Identifiable {
    case masterList = "Master List"
    case trips = "Trips"
    case statistics = "Statistics"
    case debug = "Debug"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .masterList:
            "square.grid.2x2"
        case .trips:
            "suitcase"
        case .statistics:
            "chart.bar"
        case .debug:
            "gearshape"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: SidebarSection? = .masterList
    @State private var compactSelection = SidebarSection.masterList
    @AppStorage("hasSeededSampleData") private var hasSeededSampleData = false

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactTabs
            } else {
                splitView
            }
        }
        .onAppear {
            seedSampleDataOnce()
        }
    }

    private var compactTabs: some View {
        TabView(selection: $compactSelection) {
            compactTab(.masterList)
            .tabItem {
                Label("Master", systemImage: "square.grid.2x2")
            }
            .tag(SidebarSection.masterList)

            compactTab(.trips)
            .tabItem {
                Label("Trips", systemImage: "suitcase")
            }
            .tag(SidebarSection.trips)

            compactTab(.statistics)
            .tabItem {
                Label("Stats", systemImage: "chart.bar")
            }
            .tag(SidebarSection.statistics)

            compactTab(.debug)
            .tabItem {
                Label("Debug", systemImage: "gearshape")
            }
            .tag(SidebarSection.debug)
        }
    }

    @ViewBuilder
    private func compactTab(_ section: SidebarSection) -> some View {
        NavigationStack {
            if compactSelection == section {
                destination(for: section)
            } else {
                Color.clear
            }
        }
    }

    private var splitView: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("PackMatrix")
        } detail: {
            NavigationStack {
                destination(for: selection ?? .masterList)
            }
        }
    }

    @ViewBuilder
    private func destination(for section: SidebarSection) -> some View {
        switch section {
        case .masterList:
            MasterListView()
        case .trips:
            TripListView()
        case .statistics:
            StatisticsView()
        case .debug:
            DebugView()
        }
    }

    private func seedSampleDataOnce() {
        guard !hasSeededSampleData else {
            return
        }

        SampleData.seedIfNeeded(in: modelContext)
        hasSeededSampleData = true
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            PackingCategory.self,
            PackingItem.self,
            Trip.self,
            TripPackingItem.self,
            PackingTemplate.self,
            PackingTemplateItem.self
        ], inMemory: true)
}
