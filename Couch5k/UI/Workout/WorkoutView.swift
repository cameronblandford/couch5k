import SwiftUI

struct WorkoutView: View {
    let workout: WorkoutSession
    let onFinish: (RunResult) -> Void
    @Environment(Settings.self) private var settings
    @State private var confirmEnd = false

    var body: some View {
        let s = workout.state
        ZStack {
            Theme.color(for: s.currentInterval.kind)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: s.currentIntervalIndex)

            VStack(spacing: 16) {
                IntervalProgressBar(intervals: workout.session.intervals, elapsedSeconds: s.elapsedSeconds, style: .onColor, showsHalfway: true)
                    .padding(.horizontal)
                Text(workout.session.title)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                Text("\(formatClock(s.elapsedSeconds)) elapsed")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                Text(s.phase == .finished ? "DONE" : s.phase == .paused ? "PAUSED" : s.currentInterval.kind.label.uppercased())
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(formatClock(s.secondsRemainingInInterval))
                    .font(Theme.numeral(workout.isResolved ? 72 : 120))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: s.secondsRemainingInInterval)
                if workout.isResolved {
                    resolvedCard
                } else {
                    Text(workout.segmentLabel ?? " ")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                HStack(alignment: .top) {
                    stat("Remaining", formatClock(workout.remainingSeconds))
                    stat("Distance", formatDistance(workout.distanceMeters, miles: settings.useMiles))
                    if workout.isResolved {
                        stat("Pace now", formatPace(workout.currentPaceSecondsPerKm, miles: settings.useMiles))
                    } else {
                        // No faster/slower pill here: it would appear mid-run and push the layout up.
                        stat("Avg pace", formatPace(workout.averagePaceSecondsPerKm, miles: settings.useMiles),
                             secondary: "now \(formatPace(workout.currentPaceSecondsPerKm, miles: settings.useMiles))")
                    }
                }
                .padding(.horizontal)

                if !workout.isResolved {
                    HStack(spacing: 16) {
                        split("Run avg", workout.runPaceSecondsPerKm, delta(workout.runPaceSecondsPerKm, workout.baseline?.runPace))
                        split("Walk avg", workout.walkPaceSecondsPerKm, delta(workout.walkPaceSecondsPerKm, workout.baseline?.walkPace))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                }

                HStack(spacing: 16) {
                    if s.phase == .finished {
                        Button("Finish") { onFinish(workout.end()) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.white)
                            .foregroundStyle(.black)
                    } else {
                        Button(s.phase == .paused ? "Resume" : "Pause") { workout.togglePause() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.white)
                            .foregroundStyle(.black)
                        Button("End") { confirmEnd = true }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .tint(.white)
                            .confirmationDialog("End this run?", isPresented: $confirmEnd, titleVisibility: .visible) {
                                Button("End run", role: .destructive) { onFinish(workout.end()) }
                            }
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.top)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            workout.start()
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    /// The work intervals are over, so these averages are final. Shown through the cooldown.
    private var resolvedCard: some View {
        VStack(spacing: 10) {
            Text("YOUR RUN").font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.7))
            HStack(alignment: .top) {
                stat("Avg pace", formatPace(workout.averagePaceSecondsPerKm, miles: settings.useMiles))
                stat("Run avg", formatPace(workout.runPaceSecondsPerKm, miles: settings.useMiles),
                     delta: delta(workout.runPaceSecondsPerKm, workout.baseline?.runPace))
                stat("Walk avg", formatPace(workout.walkPaceSecondsPerKm, miles: settings.useMiles),
                     delta: delta(workout.walkPaceSecondsPerKm, workout.baseline?.walkPace))
            }
            if let b = workout.baseline {
                Text("Compared with your last \(b.runCount == 1 ? "run" : "\(b.runCount) runs")")
                    .font(.caption2).foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }

    private func delta(_ current: Double?, _ base: Double?) -> PaceDelta? {
        paceDelta(current, base, miles: settings.useMiles)
    }

    private func stat(_ label: String, _ value: String, secondary: String? = nil, delta: PaceDelta? = nil) -> some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.numeral(26)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6).foregroundStyle(.white)
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.7))
            if let secondary {
                Text(secondary).font(.caption2).monospacedDigit().foregroundStyle(.white.opacity(0.5))
            }
            if let delta { DeltaPill(delta: delta) }
        }
        .frame(maxWidth: .infinity)
    }

    private func split(_ label: String, _ pace: Double?, _ delta: PaceDelta?) -> some View {
        HStack(spacing: 6) {
            Text(label)
            Text(formatPace(pace, miles: settings.useMiles)).monospacedDigit().fontWeight(.semibold)
            if let delta { DeltaPill(delta: delta, compact: true) }
        }
    }
}

/// Faster or slower than recent runs, readable on the green and blue workout backgrounds:
/// a dark pill carries the status colour, and the arrow and word carry the meaning without colour.
struct DeltaPill: View {
    let delta: PaceDelta
    var compact = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: delta.faster ? "arrow.up" : "arrow.down")
            Text(compact ? String(delta.text.split(separator: " ").first ?? "") : delta.text)
        }
        .font(.caption2.weight(.bold))
        .monospacedDigit()
        .foregroundStyle(delta.faster ? Theme.better : Theme.worse)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.black.opacity(0.45), in: Capsule())
    }
}
