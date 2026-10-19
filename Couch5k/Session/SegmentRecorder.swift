import Foundation

/// Measured figures for one interval of a run. Pace is derived, never stored.
struct SegmentValue: Codable, Sendable, Equatable {
    let index: Int
    let kind: IntervalKind
    let plannedSeconds: Int
    var startDate: Date
    var endDate: Date
    /// Time spent in the segment with pauses removed.
    var movingSeconds: Int
    var distanceMeters: Double
    var elevationGainMeters: Double

    var paceSecondsPerKm: Double? { pacePerKm(seconds: movingSeconds, meters: distanceMeters, minMeters: 20) }
}

/// Splits a run into one `SegmentValue` per interval as the engine moves through the plan.
/// Timing comes from the engine's pause-free elapsed seconds, so pauses never count toward a segment.
struct SegmentRecorder {
    let intervals: [Interval]
    private(set) var closed: [SegmentValue] = []
    private(set) var current: SegmentValue?
    private var currentStartElapsed = 0
    /// Pause-free elapsed second at which each interval starts, plus a trailing total.
    private let boundaries: [Int]

    init(intervals: [Interval]) {
        self.intervals = intervals
        var b = [0]
        for i in intervals { b.append(b.last! + i.seconds) }
        boundaries = b
    }

    var all: [SegmentValue] { closed + (current.map { [$0] } ?? []) }

    /// Everything needed to carry the recorder across a crash or force-quit.
    struct Snapshot: Codable, Sendable, Equatable {
        var closed: [SegmentValue]
        var current: SegmentValue?
        var currentStartElapsed: Int
    }

    var snapshot: Snapshot { .init(closed: closed, current: current, currentStartElapsed: currentStartElapsed) }

    init(intervals: [Interval], restoring s: Snapshot) {
        self.init(intervals: intervals)
        closed = s.closed
        current = s.current
        currentStartElapsed = s.currentStartElapsed
    }
    var currentIndex: Int? { current?.index }

    /// Opens the first segment. Call once when the run starts. A run restored after a crash
    /// passes its current interval and elapsed time: that segment opens at its planned boundary,
    /// and earlier segments are not recorded, since their GPS data did not survive.
    mutating func start(at date: Date, index: Int = 0, elapsed: Int = 0) {
        guard current == nil, closed.isEmpty, intervals.indices.contains(index) else { return }
        let boundary = boundaries[index]
        open(index: index, at: date.addingTimeInterval(Double(boundary - elapsed)), elapsed: boundary)
    }

    /// Moves to `index`. Every segment skipped on the way (after a long suspension) is closed
    /// at its planned boundary, with its wall-clock end back-dated from `now`.
    mutating func advance(to index: Int, elapsed: Int, now: Date) {
        guard let cur = current, index > cur.index, index < intervals.count else { return }
        for i in cur.index..<index {
            let boundary = boundaries[i + 1]
            let at = now.addingTimeInterval(Double(boundary - elapsed))
            close(at: at, elapsed: boundary)
            open(index: i + 1, at: at, elapsed: boundary)
        }
    }

    /// Credits distance and elevation to the open segment.
    mutating func add(meters: Double, gain: Double) {
        current?.distanceMeters += meters
        current?.elevationGainMeters += gain
    }

    /// Closes the open segment. Call when the run finishes or is ended early.
    mutating func finish(elapsed: Int, now: Date) {
        close(at: now, elapsed: elapsed)
    }

    private mutating func open(index: Int, at date: Date, elapsed: Int) {
        current = .init(index: index, kind: intervals[index].kind, plannedSeconds: intervals[index].seconds,
                        startDate: date, endDate: date, movingSeconds: 0, distanceMeters: 0, elevationGainMeters: 0)
        currentStartElapsed = elapsed
    }

    private mutating func close(at date: Date, elapsed: Int) {
        guard var seg = current else { return }
        seg.endDate = date
        seg.movingSeconds = max(0, elapsed - currentStartElapsed)
        closed.append(seg)
        current = nil
    }
}

/// A run's route split by segment for drawing. Each slice starts at the previous slice's last
/// point, so the coloured polylines join up instead of leaving gaps at the transitions.
func routeSlices(_ route: [RoutePointValue], segments: [SegmentValue]) -> [(kind: IntervalKind, points: [RoutePointValue])] {
    guard !segments.isEmpty else { return [] }
    var out: [(kind: IntervalKind, points: [RoutePointValue])] = []
    var carry: RoutePointValue?
    for seg in segments {
        var pts = route.filter { $0.timestamp >= seg.startDate && $0.timestamp < seg.endDate }
        if seg.index == segments.last?.index { pts = route.filter { $0.timestamp >= seg.startDate } }
        if let c = carry { pts.insert(c, at: 0) }
        if let last = pts.last { carry = last }
        if pts.count > 1 { out.append((seg.kind, pts)) }
    }
    return out
}
