import Foundation
import Observation

/// Main-actor coordinator that drives the engine once per second and fans state out to
/// audio, the UI, and later location and the Live Activity.
@Observable @MainActor
final class WorkoutSession: Identifiable {
    let session: Session
    private(set) var state: WorkoutState
    var distanceMeters: Double?
    /// Rolling pace over the last 30 seconds.
    var currentPaceSecondsPerKm: Double?
    private(set) var runMeters = 0.0
    /// Distance covered in the walk intervals between runs. Warmup and cooldown are not included.
    private(set) var walkMeters = 0.0
    private(set) var elevationGainMeters = 0.0
    /// Averages of recent runs, for the faster and slower pills. Set by whoever starts the run.
    var baseline: PaceBaseline?

    /// True once the work intervals are over: the averages will not change any more.
    var isResolved: Bool { state.currentInterval.kind == .cooldown || state.phase == .finished }

    var remainingSeconds: Int { max(0, state.totalSeconds - state.elapsedSeconds) }

    /// Average over the work intervals only: warmup and cooldown are excluded.
    var averagePaceSecondsPerKm: Double? {
        let split = session.activitySeconds(upTo: state.elapsedSeconds)
        return paceSecondsPerKm(seconds: split.run + split.walk, meters: runMeters + walkMeters)
    }
    var runPaceSecondsPerKm: Double? {
        paceSecondsPerKm(seconds: session.activitySeconds(upTo: state.elapsedSeconds).run, meters: runMeters)
    }
    var walkPaceSecondsPerKm: Double? {
        paceSecondsPerKm(seconds: session.activitySeconds(upTo: state.elapsedSeconds).walk, meters: walkMeters)
    }
    var segmentLabel: String? {
        guard let seg = session.segment(at: state.currentIntervalIndex) else { return nil }
        return "\(state.currentInterval.kind.label) \(seg.number) of \(seg.count)"
    }

    private let engine: WorkoutEngine
    private let coach = AudioCoach()
    private let recovery = RunRecovery.default
    private var remote: RemoteCommands?
    private var timer: Timer?
    private let startedAt: Date
    private let tracker = RunTracker()
    private var distance = DistanceCalculator()
    private var elevation = ElevationCalculator()
    private var segments: SegmentRecorder
    /// Distance and climb recorded before a crash, restored from the recovery file.
    private var baseMeters = 0.0
    private var baseGain = 0.0
    private var ticksSinceSave = 0
    private var live: LiveWorkout?
    private var ended = false
    private let restoredStartDate: Date?
    private let activity = RunActivityController()
    private var lastActivityKey: ActivityKey?
    private struct ActivityKey: Equatable { let index: Int; let phase: WorkoutPhase }

    var locationDenied: Bool { tracker.authorizationDenied }

    init(session: Session, settings: Settings, restoring snapshot: EngineSnapshot? = nil) {
        self.session = session
        engine = snapshot.map { WorkoutEngine(session: session, restoring: $0) } ?? WorkoutEngine(session: session)
        state = engine.state
        startedAt = snapshot?.startDate ?? Date()
        restoredStartDate = snapshot?.startDate
        if let saved = snapshot?.segments {
            // Resume the segment record, and seed the run totals from it so they stay consistent.
            let rec = SegmentRecorder(intervals: session.intervals, restoring: saved)
            segments = rec
            let all = rec.all
            baseMeters = all.reduce(0) { $0 + $1.distanceMeters }
            baseGain = all.reduce(0) { $0 + $1.elevationGainMeters }
            runMeters = all.filter { $0.kind == .run }.reduce(0) { $0 + $1.distanceMeters }
            walkMeters = all.filter { $0.kind == .walk }.reduce(0) { $0 + $1.distanceMeters }
            if baseMeters > 0 { distanceMeters = baseMeters }
            elevationGainMeters = baseGain
        } else {
            segments = SegmentRecorder(intervals: session.intervals)
        }
        coach.voiceIdentifier = settings.voiceIdentifier
        coach.chimesEnabled = settings.chimesEnabled
    }

    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }

    /// Idempotent: starts the engine on first call, and (re)wires the timer and remote commands.
    func start() {
        guard timer == nil else { return }
        engine.start()
        let r = RemoteCommands(onPause: { [weak self] in self?.pause() },
                               onResume: { [weak self] in self?.resume() },
                               onToggle: { [weak self] in self?.togglePause() })
        r.activate(title: session.title)
        remote = r
        tracker.onPoint = { [weak self] p in self?.addPoint(p) }
        tracker.start()
        let s0 = engine.state
        segments.start(at: Date(), index: s0.currentIntervalIndex, elapsed: s0.elapsedSeconds)
        saveRecovery()
        Task { await attachLiveWorkout() }
        tick()
        activity.start(title: session.title, intervalCount: session.intervals.count, state: activityState(state))
        lastActivityKey = ActivityKey(index: state.currentIntervalIndex, phase: state.phase)
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Starts the Health workout, or re-attaches to it after a crash.
    private func attachLiveWorkout() async {
        var w: LiveWorkout?
        if let restored = restoredStartDate {
            w = await LiveWorkout.recover()
            if w == nil { w = await LiveWorkout.start(at: restored) }
        } else {
            w = await LiveWorkout.start(at: startedAt)
        }
        guard let w else { return }
        if ended { w.discard(); return }     // the run ended before Health answered; the result already fell back
        live = w
        if state.phase == .paused { w.pause() }
    }

    func pause() {
        live?.pause()
        engine.pause()
        distance.markPauseGap()
        saveRecovery()
        tick()
    }

    func resume() {
        live?.resume()
        engine.resume()
        saveRecovery()
        tick()
    }

    func togglePause() {
        state.phase == .paused ? resume() : pause()
    }

    private func addPoint(_ p: RoutePointValue) {
        guard state.phase == .running else { return }
        let before = distance.totalMeters
        guard distance.add(p) else { return }
        let delta = distance.totalMeters - before
        let gainBefore = elevation.gainMeters
        defer { segments.add(meters: delta, gain: elevation.gainMeters - gainBefore) }
        switch state.currentInterval.kind {
        case .run: runMeters += delta
        case .walk: walkMeters += delta
        case .warmup, .cooldown: break
        }
        elevation.add(altitude: p.altitude, verticalAccuracy: p.verticalAccuracy)
        elevationGainMeters = baseGain + elevation.gainMeters
        distanceMeters = baseMeters + distance.totalMeters
        currentPaceSecondsPerKm = PaceCalculator.rollingPace(points: distance.accepted, now: Date())
    }

    private func tick() {
        let (s, cues) = engine.tick()
        state = s
        ticksSinceSave += 1
        if let open = segments.currentIndex, s.currentIntervalIndex > open {
            segments.advance(to: s.currentIntervalIndex, elapsed: s.elapsedSeconds, now: Date())
            saveRecovery()
        } else if ticksSinceSave >= 10, s.phase == .running {
            saveRecovery()   // keeps the open segment's distance within 10 s of current
        }
        if s.phase == .finished, segments.currentIndex != nil {
            // Close at the moment the plan ended, not when Finish is tapped.
            segments.finish(elapsed: s.totalSeconds, now: Date())
        }
        coach.enqueue(cues)
        let key = ActivityKey(index: s.currentIntervalIndex, phase: s.phase)
        if s.phase == .paused, lastActivityKey == key {
            activity.update(activityState(s))   // keep the remaining-time figure honest while paused
        }
        if let last = lastActivityKey, last != key {
            activity.update(activityState(s))
            lastActivityKey = key
        }
        if s.phase == .finished { stopTicking() }
    }

    private func activityState(_ s: WorkoutState) -> RunActivityAttributes.ContentState {
        let seg = session.segment(at: s.currentIntervalIndex)
        return .init(kind: s.currentInterval.kind, intervalIndex: s.currentIntervalIndex,
                     intervalEndDate: Date().addingTimeInterval(Double(s.secondsRemainingInInterval)),
                     paused: s.phase == .paused, finished: s.phase == .finished, secondsRemaining: s.secondsRemainingInInterval,
                     elapsedSeconds: s.elapsedSeconds, segmentNumber: seg?.number, segmentCount: seg?.count,
                     sessionEndDate: Date().addingTimeInterval(Double(max(0, s.totalSeconds - s.elapsedSeconds))),
                     sessionSecondsRemaining: max(0, s.totalSeconds - s.elapsedSeconds))
    }

    private func saveRecovery() {
        ticksSinceSave = 0
        guard engine.hasStarted else { return }
        var snap = engine.snapshot
        snap.segments = segments.snapshot
        try? recovery.save(snap)
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    func end() -> RunResult {
        ended = true
        live?.stop()
        stopTicking()
        tracker.stop()
        activity.end()
        remote?.deactivate()
        recovery.clear()
        let s = engine.state
        if segments.currentIndex != nil { segments.finish(elapsed: s.elapsedSeconds, now: Date()) }
        let split = session.activitySeconds(upTo: s.elapsedSeconds)
        return .init(sessionID: session.id, startDate: startedAt, endDate: Date(), elapsedSeconds: s.elapsedSeconds,
                     distanceMeters: distanceMeters,
                     averagePaceSecondsPerKm: paceSecondsPerKm(seconds: split.run + split.walk, meters: runMeters + walkMeters),
                     completed: s.phase == .finished, route: distance.accepted,
                     runMeters: runMeters, walkMeters: walkMeters, runSeconds: split.run, walkSeconds: split.walk,
                     elevationGainMeters: elevationGainMeters, segments: segments.all, liveWorkout: live)
    }
}
