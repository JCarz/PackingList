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

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactTabs
            } else {
                splitView
            }
        }
        .onAppear {
            SampleData.seedIfNeeded(in: modelContext)
        }
    }

    private var compactTabs: some View {
        TabView {
            NavigationStack {
                MasterListView()
            }
            .tabItem {
                Label("Master", systemImage: "square.grid.2x2")
            }

            NavigationStack {
                TripListView()
            }
            .tabItem {
                Label("Trips", systemImage: "suitcase")
            }

            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar")
            }

            NavigationStack {
                DebugView()
            }
            .tabItem {
                Label("Debug", systemImage: "gearshape")
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
                switch selection ?? .masterList {
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
        }
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
