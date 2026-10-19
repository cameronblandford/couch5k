import SwiftData

@Model
final class UserProgress {
    var nextWeek: Int
    var nextDay: Int
    var totalRuns: Int

    init() {
        nextWeek = 1
        nextDay = 1
        totalRuns = 0
    }

    /// nil once the plan is complete.
    var nextSessionID: SessionID? { nextWeek > 9 ? nil : .init(week: nextWeek, day: nextDay) }

    /// Only moves forward; repeating an earlier session never regresses progress.
    func advance(from completed: SessionID) {
        totalRuns += 1
        guard let n = Plan.next(after: completed) else {
            nextWeek = 10
            nextDay = 1
            return
        }
        if let cur = nextSessionID, n <= cur { return }
        nextWeek = n.week
        nextDay = n.day
    }

    static func fetchOrCreate(in ctx: ModelContext) -> UserProgress {
        if let p = try? ctx.fetch(FetchDescriptor<UserProgress>()).first { return p }
        let p = UserProgress()
        ctx.insert(p)
        return p
    }
}
