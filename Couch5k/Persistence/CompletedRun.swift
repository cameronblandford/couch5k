import SwiftData
import Foundation

@Model
final class CompletedRun {
    var id: UUID
    var week: Int
    var day: Int
    var startDate: Date
    var endDate: Date
    var distanceMeters: Double?
    var movingSeconds: Int
    var averagePaceSecondsPerKm: Double?
    var completed: Bool
    var healthKitWorkoutID: UUID?
    var runMeters: Double = 0
    var walkMeters: Double = 0
    var runSeconds: Int = 0
    var walkSeconds: Int = 0
    var elevationGainMeters: Double = 0
    /// True when the session was marked done without being run in this app.
    var isManual: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \RoutePoint.run) var points: [RoutePoint]
    /// Per-interval figures. Empty for runs recorded before segments existed and for marked-done runs.
    @Relationship(deleteRule: .cascade, inverse: \RunSegment.run) var segments: [RunSegment] = []

    init(result r: RunResult) {
        id = UUID()
        week = r.sessionID.week
        day = r.sessionID.day
        startDate = r.startDate
        endDate = r.endDate
        distanceMeters = r.distanceMeters
        movingSeconds = r.elapsedSeconds
        averagePaceSecondsPerKm = r.averagePaceSecondsPerKm
        completed = r.completed
        healthKitWorkoutID = nil
        runMeters = r.runMeters
        walkMeters = r.walkMeters
        runSeconds = r.runSeconds
        walkSeconds = r.walkSeconds
        elevationGainMeters = r.elevationGainMeters
        points = r.route.map(RoutePoint.init)
        segments = r.segments.map(RunSegment.init)
    }

    /// A run recorded on the watch. It keeps the id from the watch, so the same run is never stored twice.
    init(payload p: RunPayload) {
        id = p.id
        week = p.sessionID.week
        day = p.sessionID.day
        startDate = p.startDate
        endDate = p.endDate
        distanceMeters = p.distanceMeters
        movingSeconds = p.elapsedSeconds
        averagePaceSecondsPerKm = p.averagePaceSecondsPerKm
        completed = p.completed
        healthKitWorkoutID = p.healthKitWorkoutID
        runMeters = p.runMeters
        walkMeters = p.walkMeters
        runSeconds = p.runSeconds
        walkSeconds = p.walkSeconds
        elevationGainMeters = p.elevationGainMeters
        points = p.route.map(RoutePoint.init)
        segments = p.segments.map(RunSegment.init)
    }

    var summary: RunSummary {
        .init(id: id, sessionID: sessionID, startDate: startDate, seconds: movingSeconds, distanceMeters: distanceMeters,
              averagePaceSecondsPerKm: averagePaceSecondsPerKm, completed: completed, isManual: isManual)
    }

    /// A session done elsewhere and marked complete by hand. Carries no stats.
    init(manual sessionID: SessionID, date: Date = Date()) {
        id = UUID()
        week = sessionID.week
        day = sessionID.day
        startDate = date
        endDate = date
        distanceMeters = nil
        movingSeconds = 0
        averagePaceSecondsPerKm = nil
        completed = true
        healthKitWorkoutID = nil
        isManual = true
        points = []
    }

    var runPaceSecondsPerKm: Double? { paceSecondsPerKm(seconds: runSeconds, meters: runMeters) }
    var walkPaceSecondsPerKm: Double? { paceSecondsPerKm(seconds: walkSeconds, meters: walkMeters) }

    var sessionID: SessionID { .init(week: week, day: day) }
    var title: String { "Week \(week), Run \(day)" }

    var segmentValues: [SegmentValue] { segments.map(\.value).sorted { $0.index < $1.index } }

    var routeValues: [RoutePointValue] {
        points.sorted { $0.timestamp < $1.timestamp }
            .map { .init(latitude: $0.latitude, longitude: $0.longitude, timestamp: $0.timestamp, horizontalAccuracy: $0.horizontalAccuracy,
                         altitude: $0.altitude, verticalAccuracy: $0.verticalAccuracy) }
    }

    /// Longest single run interval in the session's plan.
    var longestRunSeconds: Int { Plan.session(sessionID)?.longestRunSeconds ?? 0 }
}

/// Average pace figures from a set of earlier runs, used to colour a summary's deltas.
struct PaceBaseline: Equatable {
    var averagePace: Double?
    var runPace: Double?
    var walkPace: Double?
    var runCount: Int

    /// Averages over the last `count` real runs that ended before `date`, ignoring runs without GPS pace.
    static func from(_ runs: [CompletedRun], before date: Date, count: Int = 3) -> PaceBaseline? {
        let earlier = runs
            .filter { !$0.isManual && $0.startDate < date && $0.averagePaceSecondsPerKm != nil }
            .sorted { $0.startDate > $1.startDate }
            .prefix(count)
        guard !earlier.isEmpty else { return nil }
        func mean(_ values: [Double?]) -> Double? {
            let v = values.compactMap { $0 }
            return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
        }
        return .init(averagePace: mean(earlier.map(\.averagePaceSecondsPerKm)),
                     runPace: mean(earlier.map(\.runPaceSecondsPerKm)),
                     walkPace: mean(earlier.map(\.walkPaceSecondsPerKm)),
                     runCount: earlier.count)
    }
}
