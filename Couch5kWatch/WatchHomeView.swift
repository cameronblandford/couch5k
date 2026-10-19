import SwiftUI

struct WatchHomeView: View {
    @Environment(WatchStore.self) private var store
    let onStart: (Session) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let id = store.history.nextID, let s = Plan.session(id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NEXT RUN").font(.caption2.bold()).foregroundStyle(Theme.accent)
                            Text(s.title).font(.system(.title3, design: .rounded).bold())
                            Text(s.summary).font(.footnote).foregroundStyle(.secondary)
                            Text("\(s.totalSeconds / 60) minutes").font(.footnote).foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
                        Button { onStart(s) } label: {
                            Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .listRowBackground(Color.clear)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PLAN COMPLETE").font(.caption2.bold()).foregroundStyle(Theme.accent)
                            Text("You can run 5K.").font(.system(.title3, design: .rounded).bold())
                            Text("Pick a session in the plan to run it again.").font(.footnote).foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                Section {
                    NavigationLink { WatchPlanView(onStart: onStart) } label: { Label("The plan", systemImage: "calendar") }
                    NavigationLink { WatchHistoryView() } label: { Label("History", systemImage: "clock.arrow.circlepath") }
                    NavigationLink { WatchSettingsView() } label: { Label("Settings", systemImage: "gearshape") }
                }
            }
            .navigationTitle("Couch5k")
        }
    }
}

/// The nine weeks. A session opens with its intervals and a Start button, so any session can be run again.
struct WatchPlanView: View {
    @Environment(WatchStore.self) private var store
    let onStart: (Session) -> Void

    var body: some View {
        let done = store.history.completedIDs
        let next = store.history.nextID
        List {
            ForEach(1...9, id: \.self) { week in
                Section("Week \(week)") {
                    ForEach(Plan.sessions.filter { $0.id.week == week }) { s in
                        NavigationLink { WatchSessionView(session: s, isCompleted: done.contains(s.id), onStart: onStart) } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Run \(s.id.day)")
                                    Text("\(s.totalSeconds / 60) min").font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if done.contains(s.id) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.better)
                                        .accessibilityLabel("Done")
                                } else if s.id == next {
                                    Text("Next").font(.caption2.bold()).foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("The plan")
    }
}

struct WatchSessionView: View {
    let session: Session
    let isCompleted: Bool
    let onStart: (Session) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.title).font(.system(.title3, design: .rounded).bold())
                if isCompleted { Label("Done", systemImage: "checkmark.circle.fill").font(.footnote).foregroundStyle(Theme.better) }
                Text(session.summary).font(.footnote).foregroundStyle(.secondary)
                Text("\(session.totalSeconds / 60) minutes, with a 5 minute walk at the start and at the end.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button { onStart(session) } label: {
                    Label(isCompleted ? "Run it again" : "Start", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
        }
        .navigationTitle("Session")
    }
}

/// Every run that the phone has, and the watch runs that wait for the phone. Runs are deleted on the phone.
struct WatchHistoryView: View {
    @Environment(Settings.self) private var settings
    @Environment(WatchStore.self) private var store

    var body: some View {
        let runs = store.history.runs
        let waiting = store.history.pending.count
        List {
            if runs.isEmpty {
                Text("No runs yet. Your finished runs show up here.").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(runs) { run in
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.title).font(.headline)
                    Text(run.startDate.formatted(date: .abbreviated, time: .omitted)).font(.footnote).foregroundStyle(.secondary)
                    if run.isManual {
                        Text("Marked as done").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text("\(formatDistance(run.distanceMeters, miles: settings.useMiles)) · \(formatClock(run.seconds))\(run.completed ? "" : " · ended early")")
                            .font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
            if waiting > 0 {
                Text("\(waiting) \(waiting == 1 ? "run waits" : "runs wait") for the iPhone. Open Couch5k on the iPhone to get \(waiting == 1 ? "it" : "them").")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("History")
    }
}

struct WatchSettingsView: View {
    @Environment(Settings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        List {
            Section {
                Toggle("Warmup drills", isOn: $settings.warmupDrills)
            } footer: {
                Text("About \(Session.durationWords(WarmupRoutine.standard.totalSeconds)) of drills before the run.")
            }
            Section {
                Toggle("Voice cues", isOn: $settings.voiceCues)
                Toggle("Chimes", isOn: $settings.chimesEnabled)
            } footer: {
                Text("The watch always taps your wrist at each change. Sound follows the watch volume and Silent Mode.")
            }
            Section("Distance") {
                Picker("Unit", selection: $settings.useMiles) {
                    Text("Miles").tag(true)
                    Text("Kilometers").tag(false)
                }
            }
        }
        .navigationTitle("Settings")
    }
}
