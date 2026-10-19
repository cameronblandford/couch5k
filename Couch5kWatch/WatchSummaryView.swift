import SwiftUI

/// The figures of the run that just ended. Save writes the workout to Health and sends the run to the phone.
struct WatchSummaryView: View {
    let result: RunResult
    let averageHeartRate: Double?
    let onDone: () -> Void
    @Environment(Settings.self) private var settings
    @Environment(WatchStore.self) private var store
    @State private var saving = false
    @State private var confirmDiscard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(Plan.session(result.sessionID)?.title ?? "Run").font(.system(.title3, design: .rounded).bold())
                Text(result.completed ? "Completed" : "Ended early").font(.footnote).foregroundStyle(Theme.accent)
                row("Time", formatClock(result.elapsedSeconds))
                row("Distance", formatDistance(result.distanceMeters, miles: settings.useMiles))
                row("Avg pace", formatPace(result.averagePaceSecondsPerKm, miles: settings.useMiles))
                row("Run pace", formatPace(paceSecondsPerKm(seconds: result.runSeconds, meters: result.runMeters), miles: settings.useMiles))
                row("Walk pace", formatPace(paceSecondsPerKm(seconds: result.walkSeconds, meters: result.walkMeters), miles: settings.useMiles))
                if let hr = averageHeartRate { row("Avg heart rate", "\(Int(hr.rounded())) bpm") }
                Button { save() } label: {
                    if saving { SwiftUI.ProgressView() } else { Text("Save").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(saving)
                .padding(.top, 6)
                Button("Discard", role: .destructive) { confirmDiscard = true }
                    .disabled(saving)
                    .confirmationDialog("Discard this run?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                        Button("Discard run", role: .destructive) {
                            result.liveWorkout?.discard()
                            onDone()
                        }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit()
        }
    }

    /// The Health workout first, so the run that goes to the phone carries its id. The run is kept if Health fails.
    private func save() {
        saving = true
        Task {
            let workoutID: UUID?
            if let live = result.liveWorkout {
                workoutID = try? await live.finish(result)
            } else {
                await HealthStore.shared.requestAuthorization()
                workoutID = try? await HealthStore.shared.save(result)
            }
            store.add(RunPayload(result: result, healthKitWorkoutID: workoutID))
            onDone()
        }
    }
}
