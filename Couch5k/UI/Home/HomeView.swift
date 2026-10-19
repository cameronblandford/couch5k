import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(Settings.self) private var settings
    @Environment(\.modelContext) private var context
    @Query private var progressRecords: [UserProgress]
    @Query private var runs: [CompletedRun]
    @Binding var active: WorkoutSession?
    @State private var pendingResult: RunResult?
    @State private var selected: SessionID?
    @State private var showSettings = false
    /// The session whose warmup drills are on the screen.
    @State private var warmup: Session?
    /// The session to start when the warmup screen is gone. One full-screen cover must close before the next opens.
    @State private var startAfterWarmup: Session?

    /// The session after the furthest one completed. Derived from the runs themselves, so deleting
    /// a run or a marked-done entry from History moves this back.
    private var nextID: SessionID? {
        guard let furthest = completedIDs.max() else { return SessionID(week: 1, day: 1) }
        return Plan.next(after: furthest)
    }

    private var completedIDs: Set<SessionID> {
        Set(runs.filter(\.completed).map(\.sessionID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    heroCard
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The plan").font(.title3.bold())
                        PlanGridView(completed: completedIDs, next: nextID) { selected = $0 }
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Couch5k")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(item: $selected) { id in
            if let s = Plan.session(id) {
                SessionSheet(session: s, isCompleted: completedIDs.contains(id), onStart: {
                    selected = nil
                    begin(s)
                }, onMarkDone: { includingEarlier in
                    markDone(id, includingEarlier: includingEarlier)
                    selected = nil
                })
                .presentationDetents([.medium, .large])
            }
        }
        .fullScreenCover(item: $warmup, onDismiss: {
            if let s = startAfterWarmup {
                startAfterWarmup = nil
                active = makeWorkout(s)
            }
        }) { s in
            WarmupView(routine: WarmupRoutine.standard.applyingDebugSpeed(), sessionTitle: s.title, onStartRun: {
                startAfterWarmup = s
                warmup = nil
            }, onCancel: { warmup = nil })
        }
        .fullScreenCover(item: $active) { w in
            WorkoutView(workout: w) { result in
                active = nil
                pendingResult = result
            }
        }
        .sheet(item: $pendingResult) { r in
            SummaryView(title: Plan.session(r.sessionID)?.title ?? "Run",
                        subtitle: r.completed ? "Completed" : "Ended early",
                        elapsedSeconds: r.elapsedSeconds, distanceMeters: r.distanceMeters,
                        paceSecondsPerKm: r.averagePaceSecondsPerKm,
                        runPaceSecondsPerKm: paceSecondsPerKm(seconds: r.runSeconds, meters: r.runMeters),
                        walkPaceSecondsPerKm: paceSecondsPerKm(seconds: r.walkSeconds, meters: r.walkMeters),
                        elevationGainMeters: r.elevationGainMeters,
                        baseline: PaceBaseline.from(runs, before: r.startDate),
                        route: r.route,
                        intervals: Plan.session(r.sessionID)?.intervals ?? [],
                        segments: r.segments,
                        onSave: { save(r); pendingResult = nil },
                        onDiscard: { r.liveWorkout?.discard(); pendingResult = nil })
            .interactiveDismissDisabled()
        }
        .onAppear {
            // Debug affordance: `-autostart` launches straight into a run.
            // `-fast` also compresses every interval, 20x by default (about 90 seconds a session); `-fast 6` sets the factor.
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-autostart"), active == nil, let id = nextID, let s = Plan.session(id) {
                let session = s.applyingDebugSpeed(args)
                // `-warmup` opens the warmup drills first; without it, `-autostart` goes straight into the run as before.
                if args.contains("-warmup"), warmup == nil { warmup = session } else { active = makeWorkout(session) }
            }
        }
    }

    @ViewBuilder private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let id = nextID, let s = Plan.session(id) {
                Text("NEXT RUN").font(.caption.bold()).foregroundStyle(Theme.accent)
                Text(s.title).font(.system(size: 34, weight: .bold, design: .rounded))
                Text(s.summary).foregroundStyle(.secondary)
                Text("\(s.totalSeconds / 60) minutes").font(.subheadline).foregroundStyle(.secondary)
                Button { begin(s) } label: {
                    Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
                Button("Already did this one? Skip it") { selected = id }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            } else {
                Text("PLAN COMPLETE").font(.caption.bold()).foregroundStyle(Theme.accent)
                Text("You can run 5K.").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Pick any session below to run it again.").foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    /// Marks a session (and optionally every earlier one not yet completed) as done without a run.
    private func markDone(_ id: SessionID, includingEarlier: Bool) {
        let done = completedIDs
        let targets = Plan.sessions.map(\.id).filter { includingEarlier ? $0 <= id : $0 == id }.filter { !done.contains($0) }
        let progress = UserProgress.fetchOrCreate(in: context)
        for target in targets {
            context.insert(CompletedRun(manual: target))
            progress.advance(from: target)
        }
        try? context.save()
    }

    /// Start pressed: the warmup drills first if the setting is on, else the run.
    private func begin(_ s: Session) {
        if settings.warmupDrills { warmup = s } else { active = makeWorkout(s) }
    }

    private func makeWorkout(_ s: Session) -> WorkoutSession {
        let w = WorkoutSession(session: s, settings: settings)
        w.baseline = PaceBaseline.from(runs, before: Date())
        return w
    }

    private func save(_ r: RunResult) {
        let run = CompletedRun(result: r)
        context.insert(run)
        if r.completed { UserProgress.fetchOrCreate(in: context).advance(from: r.sessionID) }
        try? context.save()
        Task {
            let id: UUID?
            if let live = r.liveWorkout {
                id = try? await live.finish(r)
            } else {
                await HealthStore.shared.requestAuthorization()
                id = try? await HealthStore.shared.save(r)
            }
            if let id {
                run.healthKitWorkoutID = id
                try? context.save()
            }
        }
    }
}
