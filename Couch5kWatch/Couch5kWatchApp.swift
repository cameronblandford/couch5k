import SwiftUI

@main
struct Couch5kWatchApp: App {
    @State private var settings = Settings()
    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(settings)
                .environment(store)
                .tint(Theme.accent)
        }
    }
}
