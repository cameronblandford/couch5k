import SwiftUI

/// The one screen stack of the watch app. A run takes the full screen: there is no way back into
/// the lists by accident while the clock runs.
struct WatchRootView: View {
    @Environment(Settings.self) private var settings
    @Environment(WatchStore.self) private var store
    @State private var stage = Stage.browse
    @State private var recoverable: EngineSnapshot?

    enum Stage {
        case browse
        case warmup(Session)
        case run(WatchWorkout)
        case summary(RunResult, averageHeartRate: Double?)
    }

    var body: some View {
        Group {
            switch stage {
            case .browse:
                WatchHomeView(onStart: begin)
            case .warmup(let s):
                WatchWarmupView(routine: WarmupRoutine.standard.applyingDebugSpeed(),
                                onStartRun: { stage = .run(WatchWorkout(session: s, settings: settings)) },
                                onCancel: { stage = .browse })
            case .run(let w):
                WatchWorkoutView(workout: w) { result in stage = .summary(result, averageHeartRate: w.averageHeartRate) }
            case .summary(let r, let heart):
                WatchSummaryView(result: r, averageHeartRate: heart) { stage = .browse }
            }
        }
        .onAppear {
            if let snap = RunRecovery.default.load(), Plan.session(snap.sessionID) != nil { recoverable = snap }
            // Debug affordance, the same as on the phone: `-autostart` opens the next run, `-warmup` the drills first,
            // and `-fast [factor]` makes each interval short.
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-autostart"), recoverable == nil, case .browse = stage,
               let id = store.history.nextID, let s = Plan.session(id) {
                let session = s.applyingDebugSpeed(args)
                stage = args.contains("-warmup") ? .warmup(session) : .run(WatchWorkout(session: session, settings: settings))
            }
        }
        .alert("Resume your run?", isPresented: Binding(get: { recoverable != nil }, set: { if !$0 { recoverable = nil } })) {
            Button("Resume") {
                if let snap = recoverable, let s = Plan.session(snap.sessionID) {
                    stage = .run(WatchWorkout(session: s.applyingDebugSpeed(), settings: settings, restoring: snap))
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

    /// Start pressed: the warmup drills first if the setting is on, else the run.
    private func begin(_ s: Session) {
        let session = s.applyingDebugSpeed()
        // Debug affordance: `-nowarmup` goes to the run, whatever the setting says.
        let drills = settings.warmupDrills && !ProcessInfo.processInfo.arguments.contains("-nowarmup")
        stage = drills ? .warmup(session) : .run(WatchWorkout(session: session, settings: settings))
    }
}
