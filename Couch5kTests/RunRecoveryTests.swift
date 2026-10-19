import Testing
import Foundation
@testable import Couch5k

struct RunRecoveryTests {
    @Test func roundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let r = RunRecovery(directory: dir)
        #expect(r.load() == nil)
        let snap = EngineSnapshot(sessionID: .init(week: 2, day: 3), startDate: Date(timeIntervalSince1970: 5),
                                  pausedOffset: 12.5, pauseStartedAt: nil, firedCues: [.start, .transition(1)])
        try r.save(snap)
        #expect(r.load() == snap)
        r.clear()
        #expect(r.load() == nil)
    }

    @Test func segmentsSurviveTheRecoveryFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let r = RunRecovery(directory: dir)
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        var rec = SegmentRecorder(intervals: [.warmup, .run(60), .cooldown])
        rec.start(at: t0)
        rec.add(meters: 400, gain: 2)
        rec.advance(to: 1, elapsed: 300, now: t0 + 300)
        rec.add(meters: 150, gain: 0)
        var snap = EngineSnapshot(sessionID: .init(week: 1, day: 1), startDate: t0, pausedOffset: 0,
                                  pauseStartedAt: nil, firedCues: [.start, .transition(1)])
        snap.segments = rec.snapshot
        try r.save(snap)

        let loaded = try #require(r.load()?.segments)
        var restored = SegmentRecorder(intervals: [.warmup, .run(60), .cooldown], restoring: loaded)
        #expect(restored.all == rec.all)
        restored.add(meters: 50, gain: 0)
        restored.finish(elapsed: 360, now: t0 + 360)
        #expect(restored.all.map(\.distanceMeters) == [400, 200])
        #expect(restored.all.map(\.movingSeconds) == [300, 60])
    }

    @Test func olderRecoveryFilesWithoutSegmentsStillLoad() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let old = #"{"sessionID":{"week":1,"day":1},"startDate":0,"pausedOffset":0,"firedCues":[]}"#
        try Data(old.utf8).write(to: dir.appendingPathComponent("active-run.json"))
        let loaded = try #require(RunRecovery(directory: dir).load())
        #expect(loaded.segments == nil)
    }
}
