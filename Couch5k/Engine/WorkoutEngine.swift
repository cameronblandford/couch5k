import Foundation

enum WorkoutPhase: Sendable, Equatable { case notStarted, running, paused, finished }

struct WorkoutState: Sendable, Equatable {
    var phase: WorkoutPhase
    var currentIntervalIndex: Int
    var currentInterval: Interval
    var secondsRemainingInInterval: Int
    var elapsedSeconds: Int
    var totalSeconds: Int
}

struct EngineSnapshot: Codable, Sendable, Equatable {
    var sessionID: SessionID
    var startDate: Date
    var pausedOffset: TimeInterval
    var pauseStartedAt: Date?
    var firedCues: Set<CueID>
    /// Segments recorded so far. Written by the workout session; nil in files from older builds.
    var segments: SegmentRecorder.Snapshot? = nil
}

/// Wall-clock interval engine. All timing derives from `clock.now()` minus the start date
/// minus accumulated pause time, so suspension and timer drift never lose time.
final class WorkoutEngine {
    let session: Session
    private let clock: Clock
    private var startDate: Date?
    private var pausedOffset: TimeInterval = 0
    private var pauseStartedAt: Date?
    private var firedCues: Set<CueID> = []
    /// Absolute start offset (seconds) of each interval, plus a trailing total.
    private let boundaries: [Int]
    private var pendingPhaseCues: [CueID] = []

    init(session: Session, clock: Clock = SystemClock()) {
        self.session = session
        self.clock = clock
        var b: [Int] = [0]
        for i in session.intervals { b.append(b.last! + i.seconds) }
        boundaries = b
    }

    convenience init(session: Session, clock: Clock = SystemClock(), restoring s: EngineSnapshot) {
        self.init(session: session, clock: clock)
        startDate = s.startDate
        pausedOffset = s.pausedOffset
        pauseStartedAt = s.pauseStartedAt
        firedCues = s.firedCues
    }

    var snapshot: EngineSnapshot {
        .init(sessionID: session.id, startDate: startDate ?? clock.now(), pausedOffset: pausedOffset,
              pauseStartedAt: pauseStartedAt, firedCues: firedCues)
    }

    var hasStarted: Bool { startDate != nil }
    var isPaused: Bool { pauseStartedAt != nil }

    func start() {
        guard startDate == nil else { return }
        startDate = clock.now()
    }

    func pause() {
        guard startDate != nil, pauseStartedAt == nil, !isFinished else { return }
        pauseStartedAt = clock.now()
        pendingPhaseCues.append(.paused)
    }

    func resume() {
        guard let p = pauseStartedAt else { return }
        pausedOffset += clock.now().timeIntervalSince(p)
        pauseStartedAt = nil
        pendingPhaseCues.append(.resumed)
    }

    private var totalSeconds: Int { boundaries.last! }
    private var isFinished: Bool { firedCues.contains(.complete) }

    private var elapsed: TimeInterval {
        guard let start = startDate else { return 0 }
        let end = pauseStartedAt ?? clock.now()
        return max(0, end.timeIntervalSince(start) - pausedOffset)
    }

    var state: WorkoutState { computeState(elapsedWhole: Int(elapsed)) }

    private func computeState(elapsedWhole: Int) -> WorkoutState {
        let total = totalSeconds
        let e = min(elapsedWhole, total)
        let lastIndex = session.intervals.count - 1
        let idx = e >= total ? lastIndex : (boundaries.lastIndex { $0 <= e } ?? 0)
        let phase: WorkoutPhase
        if startDate == nil { phase = .notStarted }
        else if e >= total { phase = .finished }
        else if pauseStartedAt != nil { phase = .paused }
        else { phase = .running }
        return .init(phase: phase, currentIntervalIndex: idx, currentInterval: session.intervals[idx],
                     secondsRemainingInInterval: max(0, boundaries[idx + 1] - e),
                     elapsedSeconds: e, totalSeconds: total)
    }

    /// Recompute state and return any cues that are due and have not yet fired.
    func tick() -> (WorkoutState, [Cue]) {
        let e = Int(elapsed)
        var cues: [Cue] = pendingPhaseCues.map { Self.cue(for: $0, session: session) }
        pendingPhaseCues.removeAll()

        guard startDate != nil, !isFinished else { return (computeState(elapsedWhole: e), cues) }

        var due: [CueID] = []
        if !firedCues.contains(.start) { due.append(.start) }

        // Transitions: every boundary at or before e. Index 0 is covered by .start.
        let dueTransitions = (1..<session.intervals.count).filter { boundaries[$0] <= e && !firedCues.contains(.transition($0)) }
        if let latest = dueTransitions.last {
            // After a long suspension, swallow earlier transitions silently.
            for t in dueTransitions.dropLast() { firedCues.insert(.transition(t)) }
            due.append(.transition(latest))
        }
        // A transition that fires supersedes its own warning.
        for t in dueTransitions { firedCues.insert(.tenSecondWarning(t)) }

        for i in 0..<session.intervals.count {
            let start = boundaries[i], end = boundaries[i + 1]
            let interval = session.intervals[i]
            let inInterval = e >= start && e < end
            guard inInterval else { continue }

            let warnAt = end - 10
            if i + 1 < session.intervals.count, e >= warnAt, warnAt > start, !firedCues.contains(.tenSecondWarning(i + 1)) {
                due.append(.tenSecondWarning(i + 1))
            }
            if interval.kind == .run, interval.seconds > 180 {
                let half = start + interval.seconds / 2
                if e >= half, !firedCues.contains(.halfway(i)) { due.append(.halfway(i)) }
            }
            if interval.kind == .run, interval.seconds >= 1200 {
                let secondsIn = e - start
                let minutesIn = secondsIn / 60
                if minutesIn > 0, minutesIn % 5 == 0, secondsIn % 60 < 5, !firedCues.contains(.elapsedMinutes(minutesIn)) {
                    due.append(.elapsedMinutes(minutesIn))
                }
            }
        }

        if e >= totalSeconds {
            due.removeAll { if case .transition = $0 { return true }; return false }
            due.append(.complete)
        }

        for id in due {
            firedCues.insert(id)
            cues.append(Self.cue(for: id, session: session))
        }
        return (computeState(elapsedWhole: e), cues)
    }

    static func cue(for id: CueID, session: Session) -> Cue {
        switch id {
        case .start:
            return .init(id: id, chime: .walk, speech: "\(session.title). Warm up with a 5 minute brisk walk.")
        case .transition(let i):
            let interval = session.intervals[i]
            switch interval.kind {
            case .cooldown: return .init(id: id, chime: .walk, speech: "Cool down. Walk for \(Session.speechWords(interval.seconds)).")
            case .run: return .init(id: id, chime: .run, speech: "Run for \(Session.speechWords(interval.seconds)).")
            case .walk, .warmup: return .init(id: id, chime: .walk, speech: "Walk for \(Session.speechWords(interval.seconds)).")
            }
        case .tenSecondWarning: return .init(id: id, chime: .tick, speech: nil)
        case .halfway: return .init(id: id, chime: nil, speech: "Halfway.")
        case .elapsedMinutes(let m): return .init(id: id, chime: nil, speech: "\(m) minutes.")
        case .complete: return .init(id: id, chime: .walk, speech: "Great work. \(session.title) done.")
        case .paused: return .init(id: id, chime: nil, speech: "Paused.")
        case .resumed: return .init(id: id, chime: nil, speech: "Resuming.")
        }
    }
}
