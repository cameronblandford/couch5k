import Testing
@testable import Couch5k

struct PlanTests {
    @Test func hasTwentySevenSessions() {
        #expect(Plan.sessions.count == 27)
        for week in 1...9 { for day in 1...3 { #expect(Plan.session(.init(week: week, day: day)) != nil) } }
    }

    @Test func everySessionStartsWithWarmupAndEndsWithCooldown() {
        for s in Plan.sessions {
            #expect(s.intervals.first?.kind == .warmup)
            #expect(s.intervals.last?.kind == .cooldown)
            #expect(s.intervals.first?.seconds == 300)
            #expect((s.intervals.last?.seconds ?? 0) >= 300)
            // The last work interval is always a run: a trailing recovery walk is folded into the cooldown.
            #expect(s.intervals.dropLast().last?.kind == .run)
        }
    }

    @Test func trailingWalkIsFoldedIntoCooldown() {
        let w1 = Plan.session(.init(week: 1, day: 1))!
        #expect(w1.intervals.count == 1 + 15 + 1)          // warmup, 8 runs + 7 walks, cooldown
        #expect(w1.intervals.last == Interval(kind: .cooldown, seconds: 390))
        let w9 = Plan.session(.init(week: 9, day: 1))!
        #expect(w9.intervals.last == Interval(kind: .cooldown, seconds: 300))
    }

    @Test func segmentNumbering() {
        let w1 = Plan.session(.init(week: 1, day: 1))!
        #expect(w1.segment(at: 0) == nil)                                  // warmup
        #expect(w1.segment(at: 1)! == (1, 8))                              // first run
        #expect(w1.segment(at: 2)! == (1, 7))                              // first walk
        #expect(w1.segment(at: 7)! == (4, 8))                              // fourth run
        #expect(w1.segment(at: w1.intervals.count - 1) == nil)             // cooldown
        #expect(Plan.session(.init(week: 9, day: 1))!.segment(at: 1) == nil)   // single run
    }

    @Test func activitySecondsSplit() {
        let w1 = Plan.session(.init(week: 1, day: 1))!
        #expect(w1.activitySeconds(upTo: 0) == (0, 0, 0))
        #expect(w1.activitySeconds(upTo: 330) == (30, 0, 300))             // 30 s into first run
        #expect(w1.activitySeconds(upTo: 300 + 60 + 45) == (60, 45, 300))
        let all = w1.activitySeconds(upTo: w1.totalSeconds + 100)
        #expect(all.run == 480)
        #expect(all.walk == 7 * 90)                                        // 7 walks between 8 runs
        #expect(all.easy == 300 + 390)                                     // warmup + folded cooldown
        #expect(all.run + all.walk + all.easy == w1.totalSeconds)
        #expect(w1.longestRunSeconds == 60)
        #expect(Plan.session(.init(week: 5, day: 3))!.longestRunSeconds == 1200)
    }

    @Test func referenceDurations() {
        let expected: [SessionID: Int] = [
            .init(week: 1, day: 1): 300 + 8 * (60 + 90) + 300,
            .init(week: 2, day: 1): 300 + 6 * (90 + 120) + 300,
            .init(week: 3, day: 1): 300 + 2 * (90 + 90 + 180 + 180) + 300,
            .init(week: 4, day: 1): 300 + 180 + 90 + 300 + 150 + 180 + 90 + 300 + 300,
            .init(week: 5, day: 3): 300 + 1200 + 300,
            .init(week: 6, day: 3): 300 + 1500 + 300,
            .init(week: 9, day: 3): 300 + 1800 + 300,
        ]
        for (id, secs) in expected { #expect(Plan.session(id)?.totalSeconds == secs, "\(id)") }
    }

    @Test func nextSessionAdvancesAndWrapsWeeks() {
        #expect(Plan.next(after: .init(week: 1, day: 1)) == .init(week: 1, day: 2))
        #expect(Plan.next(after: .init(week: 1, day: 3)) == .init(week: 2, day: 1))
        #expect(Plan.next(after: .init(week: 9, day: 3)) == nil)
    }

    @Test func summaryDescribesIntervals() {
        let s = Plan.session(.init(week: 1, day: 1))!
        #expect(s.title == "Week 1, Run 1")
        #expect(s.summary == "8 × (run 1 min, walk 90 sec)")
        #expect(Plan.session(.init(week: 2, day: 1))!.summary == "6 × (run 90 sec, walk 2 min)")
        #expect(Plan.session(.init(week: 3, day: 2))!.summary == "2 × (run 90 sec, walk 90 sec, run 3 min, walk 3 min)")
        #expect(Plan.session(.init(week: 5, day: 1))!.summary == "3 × (run 5 min, walk 3 min)")
    }

    @Test func speechWords() {
        #expect(Session.speechWords(60) == "1 minute")
        #expect(Session.speechWords(90) == "90 seconds")
        #expect(Session.speechWords(120) == "2 minutes")
        #expect(Session.speechWords(150) == "2 minutes 30 seconds")
    }
}
