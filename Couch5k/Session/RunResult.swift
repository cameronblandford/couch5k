import Foundation

struct RunResult {
    let sessionID: SessionID
    let startDate: Date
    let endDate: Date
    let elapsedSeconds: Int
    let distanceMeters: Double?
    let averagePaceSecondsPerKm: Double?
    let completed: Bool
    let route: [RoutePointValue]
    let runMeters: Double
    let walkMeters: Double
    let runSeconds: Int
    let walkSeconds: Int
    let elevationGainMeters: Double
    let segments: [SegmentValue]
    /// The live Health workout for this run, if one started. Finished on save, discarded on discard.
    let liveWorkout: LiveWorkout?
}

/// Seconds per km, or nil when there is too little distance for the number to mean anything.
func paceSecondsPerKm(seconds: Int, meters: Double, minMeters: Double = 50) -> Double? {
    pacePerKm(seconds: seconds, meters: meters, minMeters: minMeters)
}

/// The same figure under a name that a type with a `paceSecondsPerKm` property can call.
func pacePerKm(seconds: Int, meters: Double, minMeters: Double) -> Double? {
    guard meters >= minMeters, seconds > 0 else { return nil }
    return Double(seconds) / (meters / 1000)
}

extension RunResult: Identifiable {
    var id: Date { startDate }
}
