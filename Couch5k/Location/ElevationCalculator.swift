import Foundation

/// Accumulates elevation gain from GPS altitude with hysteresis, so metre-scale
/// altitude noise does not add up to a phantom climb.
struct ElevationCalculator {
    /// Points with worse vertical accuracy than this are ignored.
    static let maxVerticalAccuracy = 10.0
    /// A rise only counts once it exceeds this, measured from the lowest point since the last counted rise.
    static let threshold = 3.0

    private(set) var gainMeters = 0.0
    private var reference: Double?

    mutating func add(altitude: Double?, verticalAccuracy: Double?) {
        guard let altitude, let acc = verticalAccuracy, acc > 0, acc <= Self.maxVerticalAccuracy else { return }
        guard let ref = reference else { reference = altitude; return }
        if altitude < ref {
            reference = altitude
        } else if altitude - ref >= Self.threshold {
            gainMeters += altitude - ref
            reference = altitude
        }
    }
}
