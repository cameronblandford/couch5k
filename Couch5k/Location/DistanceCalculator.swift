import CoreLocation

struct RoutePointValue: Codable, Sendable, Equatable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let horizontalAccuracy: Double
    var altitude: Double? = nil
    var verticalAccuracy: Double? = nil

    init(latitude: Double, longitude: Double, timestamp: Date, horizontalAccuracy: Double,
         altitude: Double? = nil, verticalAccuracy: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.altitude = altitude
        self.verticalAccuracy = verticalAccuracy
    }

    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}

/// Accumulates distance from accepted GPS points. Segments that span a pause are skipped.
struct DistanceCalculator {
    static let maxAccuracy = 20.0
    private(set) var totalMeters = 0.0
    private(set) var accepted: [RoutePointValue] = []
    private var gapPending = false

    @discardableResult
    mutating func add(_ p: RoutePointValue) -> Bool {
        guard p.horizontalAccuracy >= 0, p.horizontalAccuracy <= Self.maxAccuracy else { return false }
        if let last = accepted.last, !gapPending {
            totalMeters += p.location.distance(from: last.location)
        }
        gapPending = false
        accepted.append(p)
        return true
    }

    mutating func markPauseGap() { gapPending = true }
}
