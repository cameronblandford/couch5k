import SwiftUI
import MapKit

/// Post-run summary. With `onSave`/`onDiscard` set it is the save prompt; without them it is read-only history.
struct SummaryView: View {
    let title: String
    let subtitle: String?
    let elapsedSeconds: Int
    let distanceMeters: Double?
    let paceSecondsPerKm: Double?
    var runPaceSecondsPerKm: Double? = nil
    var walkPaceSecondsPerKm: Double? = nil
    var elevationGainMeters: Double = 0
    /// Earlier runs to compare pace against. nil hides the deltas.
    var baseline: PaceBaseline? = nil
    let route: [RoutePointValue]
    let intervals: [Interval]
    var segments: [SegmentValue] = []
    var onSave: (() -> Void)? = nil
    var onDiscard: (() -> Void)? = nil

    @Environment(Settings.self) private var settings
    @State private var confirmDiscard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    RouteMap(route: route, segments: segments)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    if let subtitle {
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top) {
                        stat("Time", formatClock(elapsedSeconds))
                        stat("Distance", formatDistance(distanceMeters, miles: settings.useMiles))
                        stat("Pace", formatPace(paceSecondsPerKm, miles: settings.useMiles),
                             delta: delta(paceSecondsPerKm, baseline?.averagePace))
                    }
                    if runPaceSecondsPerKm != nil || walkPaceSecondsPerKm != nil {
                        HStack(alignment: .top) {
                            stat("Run pace", formatPace(runPaceSecondsPerKm, miles: settings.useMiles), tint: Theme.color(for: .run),
                                 delta: delta(runPaceSecondsPerKm, baseline?.runPace))
                            stat("Walk pace", formatPace(walkPaceSecondsPerKm, miles: settings.useMiles), tint: Theme.color(for: .walk),
                                 delta: delta(walkPaceSecondsPerKm, baseline?.walkPace))
                            stat("Elev gain", formatElevation(elevationGainMeters, miles: settings.useMiles))
                        }
                    }
                    if let baseline {
                        Text("Pace excludes warmup and cooldown. Arrows compare against your last \(baseline.runCount == 1 ? "run" : "\(baseline.runCount) runs").")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    IntervalProgressBar(intervals: intervals, elapsedSeconds: elapsedSeconds, height: 12, showsPlayhead: false)
                    if !segments.isEmpty { SegmentList(segments: segments) }
                    if let onSave {
                        Button { onSave() } label: {
                            Text("Save run").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        Button("Discard", role: .destructive) { confirmDiscard = true }
                            .confirmationDialog("Discard this run?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                                Button("Discard", role: .destructive) { onDiscard?() }
                            }
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func stat(_ l: String, _ v: String, tint: Color? = nil, delta: PaceDelta? = nil) -> some View {
        VStack(spacing: 4) {
            Text(v).font(Theme.numeral(28)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            HStack(spacing: 5) {
                if let tint { Circle().fill(tint).frame(width: 7, height: 7) }
                Text(l).font(.caption).foregroundStyle(.secondary)
            }
            if let delta {
                Label(delta.text, systemImage: delta.faster ? "arrow.up" : "arrow.down")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(delta.faster ? Theme.better : Theme.worse)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func delta(_ current: Double?, _ base: Double?) -> PaceDelta? {
        paceDelta(current, base, miles: settings.useMiles)
    }
}

struct RouteMap: View {
    let route: [RoutePointValue]
    var segments: [SegmentValue] = []

    var body: some View {
        if route.count > 1 {
            let slices = routeSlices(route, segments: segments)
            Map {
                if slices.isEmpty {
                    MapPolyline(coordinates: route.map(\.coordinate))
                        .stroke(Theme.accent, lineWidth: 5)
                } else {
                    ForEach(Array(slices.enumerated()), id: \.offset) { _, slice in
                        MapPolyline(coordinates: slice.points.map(\.coordinate))
                            .stroke(Self.mapColor(slice.kind), lineWidth: 5)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        } else {
            ZStack {
                Theme.surface
                Text("No route recorded").foregroundStyle(.secondary)
            }
        }
    }
}

extension RouteMap {
    /// Line colours on the map. Warmup and cooldown are light grey so they read on both map styles.
    static func mapColor(_ kind: IntervalKind) -> Color {
        switch kind {
        case .run: Color(red: 0.20, green: 0.80, blue: 0.45)
        case .walk: Color(red: 0.30, green: 0.60, blue: 1.0)
        case .warmup, .cooldown: Color(white: 0.75)
        }
    }
}

/// One row per recorded interval: time, distance, pace, and elevation gain.
struct SegmentList: View {
    let segments: [SegmentValue]
    @Environment(Settings.self) private var settings

    var body: some View {
        let miles = settings.useMiles
        VStack(alignment: .leading, spacing: 8) {
            Text("Segments").font(.headline)
            Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 7) {
                GridRow {
                    Text("").gridColumnAlignment(.leading)
                    Text("Time")
                    Text(miles ? "mi" : "km")
                    Text("Pace")
                    Text(miles ? "ft" : "m")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(segments, id: \.index) { seg in
                    GridRow {
                        HStack(spacing: 6) {
                            Circle().fill(RouteMap.mapColor(seg.kind)).frame(width: 8, height: 8)
                            Text(label(seg))
                        }
                        .gridColumnAlignment(.leading)
                        Text(formatClock(seg.movingSeconds))
                        Text(String(format: "%.2f", seg.distanceMeters / (miles ? 1609.344 : 1000)))
                        Text(seg.paceSecondsPerKm.map { formatClock(Int(((miles ? $0 * 1.609344 : $0)).rounded())) } ?? "—")
                        Text(String(Int((miles ? seg.elevationGainMeters * 3.28084 : seg.elevationGainMeters).rounded())))
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

    /// "Warm up", "Run 3", "Walk 2", "Cool down".
    private func label(_ seg: SegmentValue) -> String {
        guard seg.kind == .run || seg.kind == .walk else { return seg.kind.label }
        let n = segments.filter { $0.kind == seg.kind && $0.index <= seg.index }.count
        return "\(seg.kind.label) \(n)"
    }
}
