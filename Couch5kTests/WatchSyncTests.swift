import Testing
import Foundation
import SwiftData
@testable import Couch5k

struct WatchSyncTests {
    private func result(week: Int = 1, day: Int = 1, completed: Bool = true, start: Date = Date(timeIntervalSince1970: 1_000_000)) -> RunResult {
        let seg = SegmentValue(index: 1, kind: .run, plannedSeconds: 60, startDate: start, endDate: start.addingTimeInterval(60),
                               movingSeconds: 60, distanceMeters: 180, elevationGainMeters: 2)
        let point = RoutePointValue(latitude: 40.7, longitude: -74, timestamp: start, horizontalAccuracy: 5, altitude: 12, verticalAccuracy: 4)
        return RunResult(sessionID: .init(week: week, day: day), startDate: start, endDate: start.addingTimeInterval(1800),
                         elapsedSeconds: 1800, distanceMeters: 3200, averagePaceSecondsPerKm: 420, completed: completed,
                         route: [point], runMeters: 1500, walkMeters: 1200, runSeconds: 480, walkSeconds: 720,
                         elevationGainMeters: 9, segments: [seg], liveWorkout: nil)
    }

    @Test func payloadSurvivesTheTripToThePhone() throws {
        let workout = UUID()
        let sent = RunPayload(result: result(), healthKitWorkoutID: workout)
        let arrived = try JSONDecoder().decode(RunPayload.self, from: JSONEncoder().encode(sent))
        #expect(arrived == sent)
        #expect(arrived.segments.first?.distanceMeters == 180)
        #expect(arrived.route.first?.altitude == 12)
        #expect(arrived.healthKitWorkoutID == workout)
    }

    @MainActor @Test func phoneRunKeepsTheWatchIdAndFigures() throws {
        let container = Persistence.container(inMemory: true)
        let payload = RunPayload(result: result(week: 2, day: 3), healthKitWorkoutID: UUID())
        let run = CompletedRun(payload: payload)
        container.mainContext.insert(run)
        #expect(run.id == payload.id)
        #expect(run.sessionID == SessionID(week: 2, day: 3))
        #expect(run.movingSeconds == 1800)
        #expect(run.healthKitWorkoutID == payload.healthKitWorkoutID)
        #expect(run.segmentValues.count == 1)
        #expect(run.routeValues.count == 1)
        #expect(!run.isManual)
        #expect(run.summary == payload.summary)
    }

    @Test func nextSessionFollowsTheFurthestCompletedRun() {
        var history = WatchHistory()
        #expect(history.nextID == SessionID(week: 1, day: 1))
        history.pending.append(RunPayload(result: result(week: 1, day: 1)))
        #expect(history.nextID == SessionID(week: 1, day: 2))
        // A run that ended early does not move the plan.
        history.pending.append(RunPayload(result: result(week: 1, day: 2, completed: false)))
        #expect(history.nextID == SessionID(week: 1, day: 2))
        let phone = RunSummary(id: UUID(), sessionID: .init(week: 3, day: 3), startDate: Date(), seconds: 0, distanceMeters: nil,
                               averagePaceSecondsPerKm: nil, completed: true, isManual: true)
        history.apply(SyncContext(runs: [phone]))
        #expect(history.nextID == SessionID(week: 4, day: 1))
        history.apply(SyncContext(runs: [RunSummary(id: UUID(), sessionID: .init(week: 9, day: 3), startDate: Date(), seconds: 0,
                                                    distanceMeters: nil, averagePaceSecondsPerKm: nil, completed: true, isManual: true)]))
        #expect(history.nextID == nil)
    }

    @Test func pendingRunStaysUntilThePhoneConfirmsIt() {
        var history = WatchHistory()
        let run = RunPayload(result: result())
        history.pending.append(run)
        history.apply(SyncContext())
        #expect(history.pending == [run])
        #expect(history.runs.map(\.id) == [run.id])
        // The phone has it: one line in the history, not two.
        history.apply(SyncContext(runs: [run.summary], received: [run.id]))
        #expect(history.pending.isEmpty)
        #expect(history.runs.map(\.id) == [run.id])
    }

    @Test func runDeletedOnThePhoneLeavesTheWatch() {
        var history = WatchHistory()
        let run = RunPayload(result: result())
        history.pending.append(run)
        // Received, then deleted on the phone before the watch saw it in the list.
        history.apply(SyncContext(runs: [], received: [run.id]))
        #expect(history.pending.isEmpty)
        #expect(history.runs.isEmpty)
        #expect(history.nextID == SessionID(week: 1, day: 1))
    }

    @Test func historyIsNewestFirst() {
        var history = WatchHistory()
        let old = RunPayload(result: result(start: Date(timeIntervalSince1970: 1_000)))
        let new = RunPayload(result: result(day: 2, start: Date(timeIntervalSince1970: 9_000)))
        history.pending = [old, new]
        #expect(history.runs.map(\.id) == [new.id, old.id])
    }
}
