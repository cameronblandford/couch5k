import SwiftData

enum Persistence {
    /// The one store of the app. The views and the watch sync use the same container.
    @MainActor static let shared = container()

    static func container(inMemory: Bool = false) -> ModelContainer {
        let cfg = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: CompletedRun.self, RoutePoint.self, RunSegment.self, UserProgress.self, configurations: cfg)
        } catch {
            fatalError("Could not create model container: \(error)")
        }
    }
}
