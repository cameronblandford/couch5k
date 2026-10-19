import SwiftUI

/// The guided warmup on the watch: one drill at a time with a countdown, a tap on the wrist, and voice cues.
/// The clock is wall time, so it stays correct while the screen is dim.
struct WatchWarmupView: View {
    let routine: WarmupRoutine
    /// Start the run. Called from "Start run" at the end and from "Skip warmup".
    let onStartRun: () -> Void
    let onCancel: () -> Void
    @Environment(Settings.self) private var settings
    @State private var coach = AudioCoach()
    /// The moment at which elapsed time was zero. A skip or a pause moves it.
    @State private var origin = Date()
    @State private var pausedAt: Date?
    @State private var announced: Int?
    @State private var announcedDone = false
    @State private var page = 1

    private func elapsed(at now: Date) -> Int { Int((pausedAt ?? now).timeIntervalSince(origin)) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let s = routine.state(elapsed: elapsed(at: context.date))
            TabView(selection: $page) {
                controls(s).tag(0).containerBackground(Theme.color(for: .warmup), for: .tabView)
                drill(s).tag(1).containerBackground(Theme.color(for: .warmup), for: .tabView)
            }
            .onChange(of: s.drillIndex, initial: true) { _, index in announce(drill: index, state: s) }
            .onChange(of: s.isFinished) { _, finished in
                guard finished else { return }
                announceDone()
                // Debug affordance: `-warmup run` goes on into the run with no tap, to test the hand-over.
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-warmup"), args.indices.contains(i + 1), args[i + 1] == "run" { onStartRun() }
            }
        }
        .onAppear {
            coach.chimesEnabled = settings.chimesEnabled
            coach.speechEnabled = settings.voiceCues
        }
    }

    @ViewBuilder private func drill(_ s: WarmupState) -> some View {
        if s.isFinished {
            VStack(spacing: 6) {
                Text("READY").font(.system(.title2, design: .rounded).weight(.heavy))
                Text("The run starts with a 5 minute walk.")
                    .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.8))
                Button { onStartRun() } label: { Label("Start run", systemImage: "play.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        } else {
            let d = routine.drills[s.drillIndex]
            VStack(spacing: 0) {
                Text(pausedAt == nil ? d.name.uppercased() : "PAUSED")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(formatClock(s.secondsRemainingInDrill))
                    .font(Theme.numeral(54)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: s.secondsRemainingInDrill)
                Text(d.how)
                    .font(.caption2).multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3).minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                Text("Drill \(s.drillIndex + 1) of \(routine.drills.count)")
                    .font(.caption2).foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 4)
        }
    }

    private func controls(_ s: WarmupState) -> some View {
        ScrollView {
            VStack(spacing: 6) {
                if !s.isFinished {
                    Button(pausedAt == nil ? "Pause" : "Resume") { togglePause(); page = 1 }
                    Button("Next drill") { skip(from: s.drillIndex); page = 1 }
                }
                Button("Skip warmup") { onStartRun() }
                Button("Cancel", role: .destructive) { onCancel() }
            }
        }
    }

    private func announce(drill index: Int, state: WarmupState) {
        guard !state.isFinished, announced != index, routine.drills.indices.contains(index) else { return }
        announced = index
        let cue = Cue(id: .transition(index), chime: .run, speech: routine.speech(forDrill: index))
        Haptics.play(for: cue)
        coach.enqueue([cue])
    }

    private func announceDone() {
        guard !announcedDone else { return }
        announcedDone = true
        let cue = Cue(id: .complete, chime: .walk, speech: WarmupRoutine.doneSpeech)
        Haptics.play(for: cue)
        coach.enqueue([cue])
    }

    private func skip(from index: Int) {
        let now = Date()
        origin = now.addingTimeInterval(-TimeInterval(routine.start(ofDrill: index + 1)))
        if pausedAt != nil { pausedAt = now }
    }

    private func togglePause() {
        if let p = pausedAt {
            origin = origin.addingTimeInterval(Date().timeIntervalSince(p))
            pausedAt = nil
        } else {
            pausedAt = Date()
        }
    }
}
