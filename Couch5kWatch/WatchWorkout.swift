import Foundation
import Observation

/// Drives one run on the watch: the interval engine once per second, GPS distance, the Health workout,
/// and the cues as taps on the wrist, chimes, and speech. The phone is not necessary during the run.
@Observable @MainActor
final class WatchWorkout: Identifiable {
    let session: Session
    private(set) var state: WorkoutState
    private(set) var distanceMeters: Double?
    /// Rolling pace over the last 30 seconds.
    private(set) var currentPaceSecondsPerKm: Double?
    private(set) var runMeters = 0.0
    /// Distance covered in the walk intervals between runs. Warmup and cooldown are not included.
    private(set) var walkMeters = 0.0
    private(set) var elevationGainMeters = 0.0
    /// Beats per minute, nil until the sensor has a value.
    private(set) var heartRate: Double?
    private(set) var averageHeartRate: Double?

    var remainingSeconds: Int { max(0, state.totalSeconds - state.elapsedSeconds) }

    /// Average over the work intervals only: warmup and cooldown are excluded.
    var averagePaceSecondsPerKm: Double? {
        let split = session.activitySeconds(upTo: state.elapsedSeconds)
        return paceSecondsPerKm(seconds: split.run + split.walk, meters: runMeters + walkMeters)
    }
    var segmentLabel: String? {
        guard let seg = session.segment(at: state.currentIntervalIndex) else { return nil }
        return "\(state.currentInterval.kind.label) \(seg.number) of \(seg.count)"
    }

    private let engine: WorkoutEngine
    private let coach = AudioCoach()
    private let recovery = RunRecovery.default
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
        coach.chimesEnabled = settings.chimesEnabled
        coach.speechEnabled = settings.voiceCues
    }

    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }

    /// Idempotent: starts the engine on first call, and (re)wires the timer.
    func start() {
        guard timer == nil, !ended else { return }
        engine.start()
        tracker.onPoint = { [weak self] p in self?.addPoint(p) }
        tracker.start()
        let s0 = engine.state
        segments.start(at: Date(), index: s0.currentIntervalIndex, elapsed: s0.elapsedSeconds)
        saveRecovery()
        Task { await attachLiveWorkout() }
        tick()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Starts the Health workout, or re-attaches to it after a crash. The workout session also keeps
    /// the app in work with the wrist down, so the timer and the cues go on.
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
        w.onHeartRate = { [weak self] current, average in
            self?.heartRate = current
            self?.averageHeartRate = average
        }
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
        for cue in cues { Haptics.play(for: cue) }
        coach.enqueue(cues)
        if s.phase == .finished { stopTicking() }
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
