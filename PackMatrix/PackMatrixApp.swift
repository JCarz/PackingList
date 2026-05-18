import SwiftUI
import SwiftData

@main
struct PackMatrixApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            PackingCategory.self,
            PackingItem.self,
            Trip.self,
            TripPackingItem.self
        ])
    }
}
