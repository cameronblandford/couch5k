import Testing
@testable import Couch5k

struct WarmupRoutineTests {
    let routine = WarmupRoutine.standard

    @Test func standardRoutineIsHopsAndSkipsOfThreeToFiveMinutes() {
        #expect(routine.drills.map(\.name) == ["A-skips", "B-skips", "High knees", "Jump in place", "Butt kicks"])
        #expect(routine.totalSeconds == 210)
        #expect((180...300).contains(routine.totalSeconds))
        #expect(routine.drills.first { $0.name == "Jump in place" }?.seconds == 60)
        for d in routine.drills { #expect(!d.how.isEmpty) }
    }

    @Test func stateFollowsTheClock() {
        #expect(routine.state(elapsed: 0) == WarmupState(drillIndex: 0, secondsRemainingInDrill: 45, elapsedSeconds: 0, totalSeconds: 210, isFinished: false))
        #expect(routine.state(elapsed: 44).drillIndex == 0)
        #expect(routine.state(elapsed: 44).secondsRemainingInDrill == 1)
        #expect(routine.state(elapsed: 45) == WarmupState(drillIndex: 1, secondsRemainingInDrill: 45, elapsedSeconds: 45, totalSeconds: 210, isFinished: false))
        #expect(routine.state(elapsed: 130).drillIndex == 3)
        #expect(routine.state(elapsed: 130).secondsRemainingInDrill == 50)
        #expect(routine.state(elapsed: 209).drillIndex == 4)
        #expect(!routine.state(elapsed: 209).isFinished)
    }

    @Test func stateStopsAtTheEndAndBeforeTheStart() {
        let end = routine.state(elapsed: 210)
        #expect(end.isFinished)
        #expect(end.drillIndex == 4)
        #expect(end.secondsRemainingInDrill == 0)
        #expect(routine.state(elapsed: 9999) == end)
        #expect(routine.state(elapsed: -5) == routine.state(elapsed: 0))
    }

    @Test func aSkipMovesTheClockToTheNextDrill() {
        #expect(routine.start(ofDrill: 0) == 0)
        #expect(routine.start(ofDrill: 2) == 90)
        #expect(routine.start(ofDrill: 5) == 210)   // after the last drill: the end
        #expect(routine.start(ofDrill: 99) == 210)
        #expect(routine.state(elapsed: routine.start(ofDrill: 3)).drillIndex == 3)
    }

    @Test func speechNamesTheDrillItsTimeAndHow() {
        #expect(routine.speech(forDrill: 0) == "Warm up. A-skips. 45 seconds. Skip forward. Drive one knee up to hip height with each skip.")
        #expect(routine.speech(forDrill: 3).hasPrefix("Jump in place. 1 minute. "))
        #expect(!routine.speech(forDrill: 1).hasPrefix("Warm up."))
    }

    @Test func debugSpeedDividesEachDrill() {
        let fast = routine.applyingDebugSpeed(["app", "-fast"])
        #expect(fast.drills.map(\.seconds) == [3, 3, 3, 3, 3])
        #expect(routine.applyingDebugSpeed(["app", "-fast", "5"]).drills.map(\.seconds) == [9, 9, 6, 12, 6])
        #expect(routine.applyingDebugSpeed(["app"]) == routine)
    }

    @Test func anEmptyRoutineIsFinishedAtOnce() {
        let none = WarmupRoutine(drills: [])
        #expect(none.state(elapsed: 0).isFinished)
        #expect(none.totalSeconds == 0)
    }
}
