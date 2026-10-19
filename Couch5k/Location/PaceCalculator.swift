import Foundation

enum PaceCalculator {
    /// Seconds per km over the trailing window, nil when too little distance to be meaningful.
    static func rollingPace(points: [RoutePointValue], now: Date, window: TimeInterval = 30, minMeters: Double = 20) -> Double? {
        let recent = points.filter { now.timeIntervalSince($0.timestamp) <= window }
        guard recent.count >= 2 else { return nil }
        var meters = 0.0
        for (a, b) in zip(recent, recent.dropFirst()) { meters += b.location.distance(from: a.location) }
        let secs = recent.last!.timestamp.timeIntervalSince(recent.first!.timestamp)
        guard meters >= minMeters, secs > 0 else { return nil }
        return secs / (meters / 1000)
    }
}
