import HealthKit
import CoreLocation

@MainActor
final class HealthStore {
    static let shared = HealthStore()
    private let store = HKHealthStore()

    /// Debug affordance: with the `-noprompts` launch argument the app uses neither Health nor location,
    /// so no permission prompt covers the screen in a simulator test.
    nonisolated static let isDisabledForTest = ProcessInfo.processInfo.arguments.contains("-noprompts")

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() && !Self.isDisabledForTest }
    var authorizationStatus: HKAuthorizationStatus { store.authorizationStatus(for: .workoutType()) }

    private var shareTypes: Set<HKSampleType> {
        [.workoutType(), HKSeriesType.workoutRoute(), HKQuantityType(.distanceWalkingRunning),
         HKQuantityType(.activeEnergyBurned)]
    }

    /// The watch shows the heart rate during a run. The phone reads nothing.
    private var readTypes: Set<HKObjectType> {
        #if os(watchOS)
        [HKQuantityType(.heartRate)]
        #else
        []
        #endif
    }

    func requestAuthorization() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    /// Saves the run as an outdoor running workout with distance and route. Returns the workout UUID.
    func save(_ r: RunResult) async throws -> UUID {
        guard isAvailable else { throw HKError(.errorHealthDataUnavailable) }
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: r.startDate)
        if let m = r.distanceMeters, m > 0 {
            let q = HKQuantity(unit: .meter(), doubleValue: m)
            let sample = HKCumulativeQuantitySample(type: HKQuantityType(.distanceWalkingRunning), quantity: q,
                                                    start: r.startDate, end: r.endDate)
            try await builder.addSamples([sample])
        }
        try await builder.endCollection(at: r.endDate)
        guard let workout = try await builder.finishWorkout() else { throw HKError(.unknownError) }
        if r.route.count > 1 {
            let rb = HKWorkoutRouteBuilder(healthStore: store, device: .local())
            let locs = r.route.map {
                CLLocation(coordinate: $0.coordinate, altitude: 0, horizontalAccuracy: $0.horizontalAccuracy,
                           verticalAccuracy: -1, timestamp: $0.timestamp)
            }
            try await rb.insertRouteData(locs)
            try await rb.finishRoute(with: workout, metadata: nil)
        }
        return workout.uuid
    }
}
