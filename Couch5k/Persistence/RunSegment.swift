import SwiftData
import Foundation

/// One interval of a recorded run. Its route is the run's points between `startDate` and `endDate`.
@Model
final class RunSegment {
    var index: Int
    var kindRaw: String
    var plannedSeconds: Int
    var startDate: Date
    var endDate: Date
    var movingSeconds: Int
    var distanceMeters: Double
    var elevationGainMeters: Double
    var run: CompletedRun?

    init(_ v: SegmentValue) {
        index = v.index
        kindRaw = v.kind.rawValue
        plannedSeconds = v.plannedSeconds
        startDate = v.startDate
        endDate = v.endDate
        movingSeconds = v.movingSeconds
        distanceMeters = v.distanceMeters
        elevationGainMeters = v.elevationGainMeters
    }

    var value: SegmentValue {
        .init(index: index, kind: IntervalKind(rawValue: kindRaw) ?? .walk, plannedSeconds: plannedSeconds,
              startDate: startDate, endDate: endDate, movingSeconds: movingSeconds,
              distanceMeters: distanceMeters, elevationGainMeters: elevationGainMeters)
    }
}
