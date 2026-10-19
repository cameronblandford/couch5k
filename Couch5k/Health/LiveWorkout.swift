import HealthKit
import CoreLocation
import os

/// A live HealthKit workout that runs alongside the Couch5k session (iOS 26+ on iPhone).
/// It shows as an in-progress running workout, earns Fitness ring credit, and records pauses.
/// Distance comes from Couch5k's own GPS, one sample per segment, so Health and the app agree.
@MainActor
final class LiveWorkout: NSObject {
    nonisolated private static let log = Logger(subsystem: "com.example.Couch5k", category: "LiveWorkout")
    private static let store = HKHealthStore()

    private let session: HKWorkoutSession
    private let builder: HKLiveWorkoutBuilder
    private(set) var isFinished = false
    /// The newest heart rate and the average of the workout, in beats per minute. Only the watch has a sensor.
    var onHeartRate: ((_ current: Double, _ average: Double?) -> Void)?

    private init(session: HKWorkoutSession) {
        self.session = session
        builder = session.associatedWorkoutBuilder()
        super.init()
        session.delegate = self
        builder.delegate = self
    }

    private static var configuration: HKWorkoutConfiguration {
        let c = HKWorkoutConfiguration()
        c.activityType = .running
        c.locationType = .outdoor
        return c
    }

    /// Starts a live workout at `date`. Returns nil when Health is unavailable or not authorized,
    /// in which case the caller falls back to saving a finished workout after the run.
    static func start(at date: Date) async -> LiveWorkout? {
        guard HKHealthStore.isHealthDataAvailable(), !HealthStore.isDisabledForTest else { return nil }
        await HealthStore.shared.requestAuthorization()
        guard store.authorizationStatus(for: .workoutType()) == .sharingAuthorized else { return nil }
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let live = LiveWorkout(session: session)
            let source = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            // Couch5k supplies distance from GPS; the data source keeps energy and anything else it can collect.
            source.disableCollection(for: HKQuantityType(.distanceWalkingRunning))
            live.builder.dataSource = source
            session.startActivity(with: date)
            try await live.builder.beginCollection(at: date)
            return live
        } catch {
            log.error("Could not start live workout: \(error.localizedDescription)")
            return nil
        }
    }

    /// Re-attaches to a workout that was running when the app was killed.
    static func recover() async -> LiveWorkout? {
        guard HKHealthStore.isHealthDataAvailable(), !HealthStore.isDisabledForTest else { return nil }
        return await withCheckedContinuation { cont in
            store.recoverActiveWorkoutSession { session, error in
                Task { @MainActor in
                    if let error { log.error("Recovery failed: \(error.localizedDescription)") }
                    cont.resume(returning: session.map { LiveWorkout(session: $0) })
                }
            }
        }
    }

    func pause() { if session.state == .running { session.pause() } }
    func resume() { if session.state == .paused { session.resume() } }

    /// Stops the session when the run ends. The workout is only written once the run is saved.
    func stop() {
        if session.state == .running || session.state == .paused { session.end() }
    }

    /// Writes the workout: one distance sample and one segment event per interval, then the route.
    func finish(_ r: RunResult) async throws -> UUID {
        guard !isFinished else { throw HKError(.errorInvalidArgument) }
        isFinished = true
        let distance = HKQuantityType(.distanceWalkingRunning)
        var samples: [HKSample] = []
        var events: [HKWorkoutEvent] = []
        for seg in r.segments where seg.endDate > seg.startDate {
            if seg.distanceMeters > 0 {
                samples.append(HKCumulativeQuantitySample(type: distance, quantity: HKQuantity(unit: .meter(), doubleValue: seg.distanceMeters),
                                                          start: seg.startDate, end: seg.endDate))
            }
            events.append(HKWorkoutEvent(type: .segment, dateInterval: DateInterval(start: seg.startDate, end: seg.endDate),
                                         metadata: ["Couch5kSegment": "\(seg.kind.rawValue) \(seg.index)"]))
        }
        if r.segments.isEmpty, let m = r.distanceMeters, m > 0 {
            samples.append(HKCumulativeQuantitySample(type: distance, quantity: HKQuantity(unit: .meter(), doubleValue: m),
                                                      start: r.startDate, end: r.endDate))
        }
        if !samples.isEmpty { try await builder.addSamples(samples) }
        if !events.isEmpty { try await builder.addWorkoutEvents(events) }
        try await builder.endCollection(at: r.endDate)
        guard let workout = try await builder.finishWorkout() else { throw HKError(.unknownError) }
        if r.route.count > 1 {
            let rb = HKWorkoutRouteBuilder(healthStore: Self.store, device: .local())
            try await rb.insertRouteData(r.route.map {
                CLLocation(coordinate: $0.coordinate, altitude: $0.altitude ?? 0, horizontalAccuracy: $0.horizontalAccuracy,
                           verticalAccuracy: $0.verticalAccuracy ?? -1, timestamp: $0.timestamp)
            })
            try await rb.finishRoute(with: workout, metadata: nil)
        }
        return workout.uuid
    }

    /// Throws the workout away when the run is discarded, so nothing reaches Health.
    func discard() {
        guard !isFinished else { return }
        isFinished = true
        stop()
        builder.discardWorkout()
    }
}

extension LiveWorkout: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutSession(_ s: HKWorkoutSession, didChangeTo to: HKWorkoutSessionState,
                                    from: HKWorkoutSessionState, date: Date) {
        Self.log.info("Session \(from.rawValue) -> \(to.rawValue)")
    }
    nonisolated func workoutSession(_ s: HKWorkoutSession, didFailWithError error: Error) {
        Self.log.error("Session failed: \(error.localizedDescription)")
    }
    nonisolated func workoutBuilder(_ b: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        let type = HKQuantityType(.heartRate)
        guard types.contains(type), let stats = b.statistics(for: type) else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        guard let current = stats.mostRecentQuantity()?.doubleValue(for: unit) else { return }
        let average = stats.averageQuantity()?.doubleValue(for: unit)
        Task { @MainActor in self.onHeartRate?(current, average) }
    }
    nonisolated func workoutBuilderDidCollectEvent(_ b: HKLiveWorkoutBuilder) {}
}
