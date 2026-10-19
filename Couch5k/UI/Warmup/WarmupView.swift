import SwiftUI

/// The guided warmup before a run: one drill at a time with a countdown and voice cues.
/// The clock is wall time, so it stays correct if the app is in the background for a moment.
struct WarmupView: View {
    let routine: WarmupRoutine
    let sessionTitle: String
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

    private func elapsed(at now: Date) -> Int { Int((pausedAt ?? now).timeIntervalSince(origin)) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let s = routine.state(elapsed: elapsed(at: context.date))
            content(s)
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
            UIApplication.shared.isIdleTimerDisabled = true
            coach.voiceIdentifier = settings.voiceIdentifier
            coach.chimesEnabled = settings.chimesEnabled
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func content(_ s: WarmupState) -> some View {
        ZStack {
            Theme.color(for: .warmup).ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Button("Cancel") { onCancel() }
                    Spacer()
                    Button("Skip warmup") { onStartRun() }
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal)

                progress(s).padding(.horizontal)
                Text("Warm up before \(sessionTitle)")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                if s.isFinished {
                    Text("READY").font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    Text("Your muscles are warm. The run starts with a 5 minute walk.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 32)
                } else {
                    let drill = routine.drills[s.drillIndex]
                    Text(pausedAt == nil ? drill.name.uppercased() : "PAUSED")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                    Text(formatClock(s.secondsRemainingInDrill))
                        .font(Theme.numeral(120))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.default, value: s.secondsRemainingInDrill)
                    Text(drill.how)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 32)
                    Text(s.drillIndex + 1 < routine.drills.count ? "Next: \(routine.drills[s.drillIndex + 1].name)" : "Last drill")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 16) {
                    if s.isFinished {
                        Button { onStartRun() } label: { Label("Start run", systemImage: "play.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(Theme.accent)
                    } else {
                        Button(pausedAt == nil ? "Pause" : "Resume") { togglePause() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.white)
                            .foregroundStyle(.black)
                        Button("Next drill") { skip(from: s.drillIndex) }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .tint(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.top)
        }
    }

    /// One bar for each drill, with a width in proportion to its time. Drills that are done are full.
    private func progress(_ s: WarmupState) -> some View {
        GeometryReader { geo in
            let gap: CGFloat = 4
            let width = geo.size.width - gap * CGFloat(max(routine.drills.count - 1, 0))
            HStack(spacing: gap) {
                ForEach(Array(routine.drills.enumerated()), id: \.offset) { index, drill in
                    let done = s.isFinished || index < s.drillIndex ? 1.0
                        : index == s.drillIndex ? 1 - Double(s.secondsRemainingInDrill) / Double(max(drill.seconds, 1)) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(.white).frame(width: max(0, width * CGFloat(drill.seconds) / CGFloat(max(routine.totalSeconds, 1)) * done))
                    }
                    .frame(width: width * CGFloat(drill.seconds) / CGFloat(max(routine.totalSeconds, 1)))
                }
            }
        }
        .frame(height: 8)
    }

    private func announce(drill index: Int, state: WarmupState) {
        guard !state.isFinished, announced != index, routine.drills.indices.contains(index) else { return }
        announced = index
        coach.enqueue([Cue(id: .transition(index), chime: .run, speech: routine.speech(forDrill: index))])
    }

    private func announceDone() {
        guard !announcedDone else { return }
        announcedDone = true
        coach.enqueue([Cue(id: .complete, chime: .walk, speech: WarmupRoutine.doneSpeech)])
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
