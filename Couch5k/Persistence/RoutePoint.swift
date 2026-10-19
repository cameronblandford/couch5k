import SwiftData
import Foundation

@Model
final class RoutePoint {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var horizontalAccuracy: Double
    var altitude: Double?
    var verticalAccuracy: Double?
    var run: CompletedRun?

    init(_ v: RoutePointValue) {
        latitude = v.latitude
        longitude = v.longitude
        timestamp = v.timestamp
        horizontalAccuracy = v.horizontalAccuracy
        altitude = v.altitude
        verticalAccuracy = v.verticalAccuracy
    }
}
