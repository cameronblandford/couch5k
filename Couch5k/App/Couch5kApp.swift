import SwiftUI

@main
struct Couch5kApp: App {
    @State private var settings = Settings()

    init() { PhoneSync.shared.activate() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .modelContainer(Persistence.shared)
    }
}
