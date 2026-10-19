import SwiftUI

/// The run on the watch. Three pages, as in the Workout app: controls on the left, the interval
/// in the middle, the figures on the right.
struct WatchWorkoutView: View {
    let workout: WatchWorkout
    let onFinish: (RunResult) -> Void
    @Environment(Settings.self) private var settings
    @Environment(\.isLuminanceReduced) private var dimmed
    @State private var page = 1
    @State private var confirmEnd = false

    var body: some View {
        let s = workout.state
        TabView(selection: $page) {
            controls(s).tag(0).containerBackground(color(s), for: .tabView)
            interval(s).tag(1).containerBackground(color(s), for: .tabView)
            figures(s).tag(2).containerBackground(color(s), for: .tabView)
        }
        .onAppear { workout.start() }
    }

    /// The colour of the interval fills the screen. It is darker while the wrist is down.
    private func color(_ s: WorkoutState) -> Color {
        Theme.color(for: s.currentInterval.kind).opacity(dimmed ? 0.5 : 1)
    }

    private func interval(_ s: WorkoutState) -> some View {
        VStack(spacing: 0) {
            Text(s.phase == .finished ? "DONE" : s.phase == .paused ? "PAUSED" : s.currentInterval.kind.label.uppercased())
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .lineLimit(1).minimumScaleFactor(0.7)
            if s.phase == .finished {
                Text(workout.session.title).font(.footnote).foregroundStyle(.white.opacity(0.8))
                Spacer(minLength: 4)
                Button("Finish") { onFinish(workout.end()) }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
            } else {
                Text(formatClock(s.secondsRemainingInInterval))
                    .font(Theme.numeral(64)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(dimmed ? nil : .default, value: s.secondsRemainingInInterval)
                Text(workout.segmentLabel ?? workout.session.title)
                    .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 2)
                HStack {
                    Label(formatClock(workout.remainingSeconds), systemImage: "flag.checkered")
                        .accessibilityLabel("Remaining \(formatClock(workout.remainingSeconds))")
                    Spacer()
                    if let hr = workout.heartRate {
                        Label("\(Int(hr.rounded()))", systemImage: "heart.fill")
                            .accessibilityLabel("Heart rate \(Int(hr.rounded()))")
                    }
                }
                .font(.footnote).monospacedDigit().foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 6)
    }

    private func figures(_ s: WorkoutState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                figure("Distance", formatDistance(workout.distanceMeters, miles: settings.useMiles))
                figure("Avg pace", formatPace(workout.averagePaceSecondsPerKm, miles: settings.useMiles))
                figure("Pace now", formatPace(workout.currentPaceSecondsPerKm, miles: settings.useMiles))
                figure("Heart rate", workout.heartRate.map { "\(Int($0.rounded())) bpm" } ?? "—")
                figure("Elapsed", formatClock(s.elapsedSeconds))
                if workout.locationDenied {
                    Text("Location is off for Couch5k, so there is no distance.").font(.caption2).foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
        }
    }

    private func figure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(Theme.numeral(24)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.7))
        }
    }

    private func controls(_ s: WorkoutState) -> some View {
        VStack(spacing: 8) {
            if s.phase == .finished {
                Button("Finish") { onFinish(workout.end()) }
            } else {
                Button { workout.togglePause(); page = 1 } label: {
                    Label(s.phase == .paused ? "Resume" : "Pause", systemImage: s.phase == .paused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                Button(role: .destructive) { confirmEnd = true } label: {
                    Label("End", systemImage: "xmark").frame(maxWidth: .infinity)
                }
                .confirmationDialog("End this run?", isPresented: $confirmEnd, titleVisibility: .visible) {
                    Button("End run", role: .destructive) { onFinish(workout.end()) }
                }
            }
        }
        .padding(.horizontal, 6)
    }
}
