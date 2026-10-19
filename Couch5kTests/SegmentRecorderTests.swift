import Testing
import Foundation
@testable import Couch5k

struct SegmentRecorderTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    let intervals: [Interval] = [.warmup, .run(60), .walk(90), .run(60), .cooldown]   // boundaries 0,300,360,450,510,810

    @Test func recordsEachSegmentWithMovingTimeAndDistance() {
        var r = SegmentRecorder(intervals: intervals)
        r.start(at: t0)
        r.add(meters: 400, gain: 1)
        r.advance(to: 1, elapsed: 300, now: t0 + 300)
        r.add(meters: 200, gain: 3)
        r.advance(to: 2, elapsed: 360, now: t0 + 360)
        #expect(r.closed.count == 2)
        #expect(r.closed[0].kind == .warmup)
        #expect(r.closed[0].movingSeconds == 300)
        #expect(r.closed[0].distanceMeters == 400)
        #expect(r.closed[1].kind == .run)
        #expect(r.closed[1].movingSeconds == 60)
        #expect(r.closed[1].distanceMeters == 200)
        #expect(r.closed[1].elevationGainMeters == 3)
        #expect(abs(r.closed[1].paceSecondsPerKm! - 300) < 0.01)     // 200 m in 60 s
        #expect(r.current?.index == 2)
    }

    @Test func pauseTimeIsExcludedFromMovingSeconds() {
        var r = SegmentRecorder(intervals: intervals)
        r.start(at: t0)
        // 300 s of warmup plus a 120 s pause: wall clock 420, engine elapsed 300
        r.advance(to: 1, elapsed: 300, now: t0 + 420)
        #expect(r.closed[0].movingSeconds == 300)
        #expect(r.closed[0].endDate == t0 + 420)
    }

    @Test func longSuspensionClosesSkippedSegmentsAtTheirBoundaries() {
        var r = SegmentRecorder(intervals: intervals)
        r.start(at: t0)
        r.advance(to: 3, elapsed: 460, now: t0 + 460)             // woke up 10 s into interval 3
        #expect(r.closed.map(\.index) == [0, 1, 2])
        #expect(r.closed.map(\.movingSeconds) == [300, 60, 90])
        #expect(r.closed[2].endDate == t0 + 450)
        #expect(r.current?.startDate == t0 + 450)
    }

    @Test func finishClosesTheOpenSegment() {
        var r = SegmentRecorder(intervals: intervals)
        r.start(at: t0)
        r.advance(to: 1, elapsed: 300, now: t0 + 300)
        r.finish(elapsed: 330, now: t0 + 330)                     // ended early, 30 s into the run
        #expect(r.current == nil)
        #expect(r.all.count == 2)
        #expect(r.all.last!.movingSeconds == 30)
    }

    @Test func routeSlicesJoinAtTransitions() {
        var r = SegmentRecorder(intervals: intervals)
        r.start(at: t0)
        r.advance(to: 1, elapsed: 300, now: t0 + 300)
        r.finish(elapsed: 360, now: t0 + 360)
        let route = [0.0, 100, 200, 310, 330, 350].map {
            RoutePointValue(latitude: 0, longitude: $0 / 100_000, timestamp: t0 + $0, horizontalAccuracy: 5)
        }
        let slices = routeSlices(route, segments: r.all)
        #expect(slices.map(\.kind) == [.warmup, .run])
        #expect(slices[0].points.count == 3)
        #expect(slices[1].points.first == route[2])               // run slice starts where warmup ended
        #expect(slices[1].points.count == 4)
    }
}
