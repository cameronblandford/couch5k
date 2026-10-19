import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(Settings.self) private var settings
    @State private var active: WorkoutSession?
    @State private var recoverable: EngineSnapshot?
    @Query private var runs: [CompletedRun]

    var body: some View {
        TabView {
            Tab("Home", systemImage: "figure.run") { HomeView(active: $active) }
            Tab("Progress", systemImage: "chart.xyaxis.line") { ProgressView() }
            Tab("History", systemImage: "clock.arrow.circlepath") { HistoryView() }
        }
        .onChange(of: runs.map(\.id), initial: true) { PhoneSync.shared.pushContext() }
        .onAppear {
            if let snap = RunRecovery.default.load(), Plan.session(snap.sessionID) != nil { recoverable = snap }
        }
        .alert("Resume your run?", isPresented: Binding(get: { recoverable != nil }, set: { if !$0 { recoverable = nil } })) {
            Button("Resume") {
                if let snap = recoverable, let s = Plan.session(snap.sessionID) {
                    let w = WorkoutSession(session: s.applyingDebugSpeed(), settings: settings, restoring: snap)
                    w.baseline = PaceBaseline.from(runs, before: snap.startDate)
                    active = w
                }
                recoverable = nil
            }
            Button("Discard", role: .destructive) {
                RunRecovery.default.clear()
                recoverable = nil
            }
        } message: {
            if let snap = recoverable, let s = Plan.session(snap.sessionID) {
                Text("\(s.title) was interrupted.")
            }
        }
    }
}
