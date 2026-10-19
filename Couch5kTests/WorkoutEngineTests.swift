import Testing
import Foundation
@testable import Couch5k

final class FakeClock: Clock, @unchecked Sendable {
    var current: Date
    init(_ d: Date = Date(timeIntervalSince1970: 1_000_000)) { current = d }
    func now() -> Date { current }
    func advance(_ s: TimeInterval) { current = current.addingTimeInterval(s) }
}

struct WorkoutEngineTests {
    let session = Plan.session(.init(week: 1, day: 1))!   // 300 warm, 8×(60 run, 90 walk), 300 cool

    func make() -> (WorkoutEngine, FakeClock) {
        let c = FakeClock(); return (WorkoutEngine(session: session, clock: c), c)
    }

    @Test func startFiresStartCueAndIsInWarmup() {
        let (e, _) = make()
        e.start()
        let (s, cues) = e.tick()
        #expect(s.phase == .running)
        #expect(s.currentIntervalIndex == 0)
        #expect(s.currentInterval.kind == .warmup)
        #expect(s.secondsRemainingInInterval == 300)
        #expect(cues.map(\.id) == [.start])
    }

    @Test func intervalLookupAtBoundaries() {
        let (e, c) = make(); e.start(); _ = e.tick()
        c.advance(299); #expect(e.tick().0.currentIntervalIndex == 0)
        c.advance(1);   let (s, cues) = e.tick()
        #expect(s.currentIntervalIndex == 1)
        #expect(s.currentInterval.kind == .run)
        #expect(s.secondsRemainingInInterval == 60)
        #expect(cues.map(\.id) == [.transition(1)])
        #expect(cues[0].chime == .run)
    }

    @Test func cuesFireExactlyOnce() {
        let (e, c) = make(); e.start(); _ = e.tick()
        c.advance(300); _ = e.tick()
        c.advance(1); #expect(e.tick().1.isEmpty)
    }

    @Test func tenSecondWarningFires() {
        let (e, c) = make(); e.start(); _ = e.tick()
        c.advance(290); #expect(e.tick().1.map(\.id) == [.tenSecondWarning(1)])
        c.advance(1); #expect(e.tick().1.isEmpty)
    }

    @Test func pauseFreezesElapsedAndResumeOffsets() {
        let (e, c) = make(); e.start(); _ = e.tick()
        c.advance(100)
        e.pause(); let (p, pc) = e.tick()
        #expect(p.phase == .paused); #expect(pc.map(\.id) == [.paused])
        c.advance(500)
        #expect(e.tick().0.elapsedSeconds == 100)
        e.resume(); let (r, rc) = e.tick()
        #expect(r.phase == .running); #expect(rc.map(\.id) == [.resumed])
        #expect(r.elapsedSeconds == 100)
        c.advance(200)
        #expect(e.tick().0.currentIntervalIndex == 1)   // 300 elapsed
    }

    @Test func longSuspensionFiresOnlyLatestTransition() {
        let (e, c) = make(); e.start(); _ = e.tick()
        c.advance(300 + 60 + 90 + 60 + 5)   // inside interval 4 (walk)
        let (s, cues) = e.tick()
        #expect(s.currentIntervalIndex == 4)
        #expect(cues.map(\.id) == [.transition(4)])
        c.advance(1); #expect(e.tick().1.isEmpty)
    }

    @Test func halfwayFiresForRunsOverThreeMinutes() {
        // Week 4 boundaries: 0 warmup, 300 run(180), 480 walk(90), 570 run(300), 870 ...
        let w4 = Plan.session(.init(week: 4, day: 1))!
        let c = FakeClock(); let e = WorkoutEngine(session: w4, clock: c)
        e.start(); _ = e.tick()
        c.advance(300); #expect(e.tick().1.map(\.id) == [.transition(1)])
        c.advance(90); #expect(e.tick().1.isEmpty)                          // 390: run 180 has no halfway
        c.advance(90); #expect(e.tick().1.map(\.id) == [.transition(2)])   // 480
        c.advance(90); #expect(e.tick().1.map(\.id) == [.transition(3)])   // 570
        c.advance(149); #expect(e.tick().1.isEmpty)                         // 719
        c.advance(1); #expect(e.tick().1.map(\.id) == [.halfway(3)])       // 720
        c.advance(1); #expect(e.tick().1.isEmpty)
    }

    @Test func elapsedMinuteCuesForLongRuns() {
        let long = Plan.session(.init(week: 9, day: 1))!   // 300, 1800 run, 300
        let c = FakeClock(); let e = WorkoutEngine(session: long, clock: c)
        e.start(); _ = e.tick()
        c.advance(300); #expect(e.tick().1.map(\.id) == [.transition(1)])
        c.advance(300); #expect(e.tick().1.map(\.id) == [.elapsedMinutes(5)])
        c.advance(1); #expect(e.tick().1.isEmpty)
        c.advance(299); #expect(e.tick().1.map(\.id) == [.elapsedMinutes(10)])
        c.advance(300); #expect(e.tick().1.map(\.id) == [.halfway(1), .elapsedMinutes(15)])
    }

    @Test func completion() {
        let (e, c) = make(); e.start(); _ = e.tick()
        c.advance(Double(session.totalSeconds))
        let (s, cues) = e.tick()
        #expect(s.phase == .finished)
        #expect(cues.map(\.id) == [.complete])
        #expect(s.elapsedSeconds == session.totalSeconds)
        c.advance(5); #expect(e.tick().1.isEmpty)
    }

    @Test func snapshotRestoresState() {
        let (e, c) = make(); e.start(); _ = e.tick()
        c.advance(310); _ = e.tick()
        e.pause(); _ = e.tick()
        let snap = e.snapshot
        let restored = WorkoutEngine(session: session, clock: c, restoring: snap)
        let (s, cues) = restored.tick()
        #expect(s.phase == .paused)
        #expect(s.elapsedSeconds == 310)
        #expect(cues.isEmpty)
    }
}
