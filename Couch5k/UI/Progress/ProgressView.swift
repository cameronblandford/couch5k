import SwiftUI
import SwiftData
import Charts

/// Trends across completed runs. Each chart carries one measure on one axis.
struct ProgressView: View {
    @Environment(Settings.self) private var settings
    @Query(sort: \CompletedRun.startDate) private var allRuns: [CompletedRun]

    private var runs: [CompletedRun] { allRuns.filter { !$0.isManual } }

    /// One x position per run, in date order, so two runs on the same day never share a bar.
    private struct Indexed: Identifiable {
        let index: Int
        let run: CompletedRun
        var id: UUID { run.id }
        var label: String { "\(index + 1)" }
    }
    private var indexed: [Indexed] { runs.enumerated().map { Indexed(index: $0.offset, run: $0.element) } }

    var body: some View {
        NavigationStack {
            Group {
                if runs.count < 2 {
                    ContentUnavailableView("Not enough runs yet", systemImage: "chart.xyaxis.line",
                                           description: Text("Trends appear after your second run."))
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            longestRunChart
                            paceChart
                            distanceChart
                            if runs.contains(where: { $0.elevationGainMeters > 0 }) { elevationChart }
                            table
                        }
                        .padding()
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle("Progress")
        }
    }

    // MARK: Charts

    private var longestRunChart: some View {
        card("Longest run segment", unit: "minutes") {
            Chart(indexed) { item in
                BarMark(x: .value("Run", item.label), y: .value("Minutes", Double(item.run.longestRunSeconds) / 60), width: .fixed(16))
                    .foregroundStyle(Theme.color(for: .run))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .chartYAxis { AxisMarks(position: .leading) { AxisGridLine().foregroundStyle(.white.opacity(0.08)); AxisValueLabel() } }
        }
    }

    private var paceChart: some View {
        let points = indexed.flatMap { item -> [PacePoint] in
            var out: [PacePoint] = []
            if let p = item.run.averagePaceSecondsPerKm { out.append(.init(label: item.label, kind: "All", pace: displayPace(p))) }
            if let p = item.run.runPaceSecondsPerKm { out.append(.init(label: item.label, kind: "Run", pace: displayPace(p))) }
            if let p = item.run.walkPaceSecondsPerKm { out.append(.init(label: item.label, kind: "Walk", pace: displayPace(p))) }
            return out
        }
        return card("Pace", unit: settings.useMiles ? "min / mi, lower is faster" : "min / km, lower is faster",
                    legend: [("All", Theme.chartAll), ("Run", Theme.color(for: .run)), ("Walk", Theme.color(for: .walk))]) {
            Chart(points) { p in
                LineMark(x: .value("Run", p.label), y: .value("Pace", p.pace))
                    .foregroundStyle(by: .value("Kind", p.kind))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Run", p.label), y: .value("Pace", p.pace))
                    .foregroundStyle(by: .value("Kind", p.kind))
                    .symbol(by: .value("Kind", p.kind))
                    .symbolSize(50)
            }
            .chartForegroundStyleScale(["All": Theme.chartAll, "Run": Theme.color(for: .run), "Walk": Theme.color(for: .walk)])
            .chartSymbolScale(["All": .circle, "Run": .triangle, "Walk": .square])
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.08))
                    AxisValueLabel { if let m = value.as(Double.self) { Text(formatClock(Int(m * 60))) } }
                }
            }
            .chartLegend(.hidden)
        }
    }

    private var distanceChart: some View {
        card("Distance", unit: settings.useMiles ? "miles" : "km") {
            Chart(indexed.filter { $0.run.distanceMeters != nil }) { item in
                BarMark(x: .value("Run", item.label),
                        y: .value("Distance", (item.run.distanceMeters ?? 0) / (settings.useMiles ? 1609.344 : 1000)), width: .fixed(16))
                    .foregroundStyle(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .chartYAxis { AxisMarks(position: .leading) { AxisGridLine().foregroundStyle(.white.opacity(0.08)); AxisValueLabel() } }
        }
    }

    private var elevationChart: some View {
        card("Elevation gain", unit: settings.useMiles ? "feet" : "meters") {
            Chart(indexed) { item in
                BarMark(x: .value("Run", item.label),
                        y: .value("Gain", settings.useMiles ? item.run.elevationGainMeters * 3.28084 : item.run.elevationGainMeters), width: .fixed(16))
                    .foregroundStyle(Color(white: 0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .chartYAxis { AxisMarks(position: .leading) { AxisGridLine().foregroundStyle(.white.opacity(0.08)); AxisValueLabel() } }
        }
    }

    // MARK: Table

    /// The same figures as the charts, one row per run, newest first.
    private var table: some View {
        let miles = settings.useMiles
        let showElevation = runs.contains { $0.elevationGainMeters > 0 }
        return VStack(alignment: .leading, spacing: 8) {
            Text("All runs").font(.headline)
            Text("Pace in \(miles ? "min / mi" : "min / km") · longest run in minutes")
                .font(.caption).foregroundStyle(.secondary)
            Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    Text("Run").gridColumnAlignment(.leading)
                    Text(miles ? "mi" : "km")
                    Text("All")
                    Text("Run").foregroundStyle(Theme.color(for: .run))
                    Text("Walk").foregroundStyle(Theme.color(for: .walk))
                    Text("Long")
                    if showElevation { Text(miles ? "ft" : "m") }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(Array(indexed.reversed()), id: \.id) { item in
                    GridRow {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(item.label) · W\(item.run.week) R\(item.run.day)")
                            Text(item.run.startDate.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .gridColumnAlignment(.leading)
                        Text(distanceNumber(item.run.distanceMeters))
                        Text(paceClock(item.run.averagePaceSecondsPerKm))
                        Text(paceClock(item.run.runPaceSecondsPerKm))
                        Text(paceClock(item.run.walkPaceSecondsPerKm))
                        Text(String(format: "%g", Double(item.run.longestRunSeconds) / 60))
                        if showElevation { Text(String(Int((miles ? item.run.elevationGainMeters * 3.28084 : item.run.elevationGainMeters).rounded()))) }
                    }
                    .font(.caption)
                    .monospacedDigit()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    /// Pace as m:ss in the display unit, or a dash.
    private func paceClock(_ secPerKm: Double?) -> String {
        guard let p = secPerKm else { return "—" }
        return formatClock(Int((settings.useMiles ? p * 1.609344 : p).rounded()))
    }

    private func distanceNumber(_ meters: Double?) -> String {
        guard let m = meters else { return "—" }
        return String(format: "%.2f", m / (settings.useMiles ? 1609.344 : 1000))
    }

    // MARK: Helpers

    private struct PacePoint: Identifiable {
        let label: String
        let kind: String
        let pace: Double
        var id: String { "\(kind)-\(label)" }
    }

    /// Minutes per display unit.
    private func displayPace(_ secPerKm: Double) -> Double {
        (settings.useMiles ? secPerKm * 1.609344 : secPerKm) / 60
    }

    private func card<C: View>(_ title: String, unit: String, legend: [(String, Color)] = [], @ViewBuilder chart: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer()
                ForEach(legend, id: \.0) { name, color in
                    HStack(spacing: 5) {
                        Circle().fill(color).frame(width: 8, height: 8)
                        Text(name).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Text("\(unit) · by run number").font(.caption).foregroundStyle(.secondary)
            chart()
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel() }
                }
                .chartXScale(domain: indexed.map(\.label))
                .frame(height: 170)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
