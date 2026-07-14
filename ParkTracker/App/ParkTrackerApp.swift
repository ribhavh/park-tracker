import SwiftUI
import SwiftData

@main
struct ParkTrackerApp: App {
    private let container: ModelContainer
    @State private var model: TrackerModel

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: CoveredSegment.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        self.container = container
        let parkData = ParkData.loadBundled()
        _model = State(initialValue: TrackerModel(parkData: parkData,
                                                  modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .modelContainer(container)
    }
}
