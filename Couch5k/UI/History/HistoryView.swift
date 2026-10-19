import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(Settings.self) private var settings
    @Environment(\.modelContext) private var context
    @Query(sort: \CompletedRun.startDate, order: .reverse) private var runs: [CompletedRun]

    var body: some View {
        NavigationStack {
            Group {
                if runs.isEmpty {
                    ContentUnavailableView("No runs yet", systemImage: "figure.run", description: Text("Your finished runs show up here."))
                } else {
                    List {
                        ForEach(runs) { run in
                            if run.isManual {
                                manualRow(run)
                            } else {
                            NavigationLink {
                                SummaryView(title: run.title,
                                            subtitle: run.startDate.formatted(date: .long, time: .shortened),
                                            elapsedSeconds: run.movingSeconds, distanceMeters: run.distanceMeters,
                                            paceSecondsPerKm: run.averagePaceSecondsPerKm,
                                            runPaceSecondsPerKm: run.runPaceSecondsPerKm,
                                            walkPaceSecondsPerKm: run.walkPaceSecondsPerKm,
                                            elevationGainMeters: run.elevationGainMeters,
                                            baseline: PaceBaseline.from(runs, before: run.startDate),
                                            route: run.routeValues,
                                            intervals: Plan.session(run.sessionID)?.intervals ?? [],
                                            segments: run.segmentValues)
                            } label: {
                                row(run)
                            }
                            }
                        }
                        .onDelete { idx in
                            for i in idx { context.delete(runs[i]) }
                            try? context.save()
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Theme.background)
            .navigationTitle("History")
        }
    }

    private func manualRow(_ run: CompletedRun) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Theme.surface
                Image(systemName: "checkmark").foregroundStyle(.secondary)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(run.title).font(.headline)
                Text("Marked as done · \(run.startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func row(_ run: CompletedRun) -> some View {
        HStack(spacing: 14) {
            RouteThumbnail(route: run.routeValues)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(run.title).font(.headline)
                    if !run.completed { Text("partial").font(.caption).foregroundStyle(.secondary) }
                }
                Text(run.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDistance(run.distanceMeters, miles: settings.useMiles)).font(Theme.numeral(17)).monospacedDigit()
                Text(formatClock(run.movingSeconds)).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}
