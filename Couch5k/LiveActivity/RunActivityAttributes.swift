import ActivityKit
import Foundation

struct RunActivityAttributes: ActivityAttributes {
    let title: String
    let intervalCount: Int

    struct ContentState: Codable, Hashable {
        var kind: IntervalKind
        var intervalIndex: Int
        /// The widget counts down to this itself, so updates are only needed on interval change or pause.
        var intervalEndDate: Date
        var paused: Bool
        var finished: Bool = false
        var secondsRemaining: Int
        var elapsedSeconds: Int
        /// e.g. run 4 of 8. nil during warmup, cooldown, and single-run sessions.
        var segmentNumber: Int?
        var segmentCount: Int?
        /// End of the whole session, for a "left" countdown. Only valid while not paused.
        var sessionEndDate: Date?
        var sessionSecondsRemaining: Int?

        var segmentLabel: String? {
            guard let n = segmentNumber, let c = segmentCount else { return nil }
            return "\(n)/\(c)"
        }
    }
}
