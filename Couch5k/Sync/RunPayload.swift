import Foundation

/// A finished run in the form that goes from the watch to the phone. The phone makes a `CompletedRun` from it.
struct RunPayload: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var sessionID: SessionID
    var startDate: Date
    var endDate: Date
    var elapsedSeconds: Int
    var distanceMeters: Double?
    var averagePaceSecondsPerKm: Double?
    var completed: Bool
    var runMeters: Double
    var walkMeters: Double
    var runSeconds: Int
    var walkSeconds: Int
    var elevationGainMeters: Double
    var segments: [SegmentValue]
    var route: [RoutePointValue]
    var healthKitWorkoutID: UUID?

    init(id: UUID = UUID(), result r: RunResult, healthKitWorkoutID: UUID? = nil) {
        self.id = id
        sessionID = r.sessionID
        startDate = r.startDate
        endDate = r.endDate
        elapsedSeconds = r.elapsedSeconds
        distanceMeters = r.distanceMeters
        averagePaceSecondsPerKm = r.averagePaceSecondsPerKm
        completed = r.completed
        runMeters = r.runMeters
        walkMeters = r.walkMeters
        runSeconds = r.runSeconds
        walkSeconds = r.walkSeconds
        elevationGainMeters = r.elevationGainMeters
        segments = r.segments
        route = r.route
        self.healthKitWorkoutID = healthKitWorkoutID
    }

    var summary: RunSummary {
        .init(id: id, sessionID: sessionID, startDate: startDate, seconds: elapsedSeconds, distanceMeters: distanceMeters,
              averagePaceSecondsPerKm: averagePaceSecondsPerKm, completed: completed, isManual: false)
    }
}

/// One line of the run history, small enough to send every run to the watch.
struct RunSummary: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var sessionID: SessionID
    var startDate: Date
    var seconds: Int
    var distanceMeters: Double?
    var averagePaceSecondsPerKm: Double?
    var completed: Bool
    /// True when the session was marked done on the phone without a run.
    var isManual: Bool

    var title: String { "Week \(sessionID.week), Run \(sessionID.day)" }
}

/// What the phone tells the watch: every run that the phone has, and which watch runs arrived.
struct SyncContext: Codable, Sendable, Equatable {
    var runs: [RunSummary] = []
    /// Ids of watch runs that the phone received. A received run that is not in `runs` was deleted on the phone.
    var received: [UUID] = []

    static let key = "context"
    static let runKey = "run"
}

/// The run history as the watch sees it: the phone's list plus the watch runs that the phone does not have yet.
struct WatchHistory: Equatable, Sendable {
    var context = SyncContext()
    /// Runs saved on the watch, kept until the phone confirms them.
    var pending: [RunPayload] = []

    /// Newest first, with no run twice.
    var runs: [RunSummary] {
        let known = Set(context.runs.map(\.id))
        return (context.runs + pending.filter { !known.contains($0.id) }.map(\.summary))
            .sorted { $0.startDate > $1.startDate }
    }

    var completedIDs: Set<SessionID> { Set(runs.filter(\.completed).map(\.sessionID)) }

    /// The session after the furthest one completed, the same rule as on the phone. nil when the plan is complete.
    var nextID: SessionID? {
        guard let furthest = completedIDs.max() else { return SessionID(week: 1, day: 1) }
        return Plan.next(after: furthest)
    }

    /// Takes a new context from the phone and drops the pending runs that the phone has.
    mutating func apply(_ new: SyncContext) {
        context = new
        let arrived = Set(new.received).union(new.runs.map(\.id))
        pending.removeAll { arrived.contains($0.id) }
    }
}
