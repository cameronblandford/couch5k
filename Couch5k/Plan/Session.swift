import Foundation
struct SessionID: Hashable, Codable, Sendable, Comparable {
    let week: Int
    let day: Int
    static func < (a: SessionID, b: SessionID) -> Bool { (a.week, a.day) < (b.week, b.day) }
}

extension SessionID: Identifiable {
    var id: Int { week * 10 + day }
}

struct Session: Identifiable, Sendable {
    let id: SessionID
    let intervals: [Interval]

    var totalSeconds: Int { intervals.reduce(0) { $0 + $1.seconds } }
    var title: String { "Week \(id.week), Run \(id.day)" }

    /// Human summary of the work intervals between warmup and cooldown.
    /// Detects a repeated pattern and collapses it: "8 × (run 1 min, walk 90 sec)".
    var summary: String {
        let work = Array(intervals.dropFirst().dropLast())
        guard !work.isEmpty else { return "" }
        // The final recovery walk is folded into the cooldown, so restore it when looking for a repeat.
        var candidates = [work]
        if let cooldown = intervals.last, cooldown.kind == .cooldown, cooldown.seconds > Interval.cooldown.seconds {
            candidates.insert(work + [.walk(cooldown.seconds - Interval.cooldown.seconds)], at: 0)
        }
        for candidate in candidates {
            if let repeated = Self.repeatedPattern(in: candidate) { return repeated }
        }
        return work.map(Self.describe).joined(separator: ", ")
    }

    private static func repeatedPattern(in work: [Interval]) -> String? {
        for unit in 1...max(1, work.count / 2) where work.count % unit == 0 {
            let pattern = Array(work.prefix(unit))
            let repeats = work.count / unit
            if repeats > 1, (0..<repeats).allSatisfy({ Array(work[$0 * unit ..< ($0 + 1) * unit]) == pattern }) {
                return "\(repeats) × (\(pattern.map(describe).joined(separator: ", ")))"
            }
        }
        return nil
    }

    /// Position of the interval among intervals of its kind, e.g. run 4 of 8.
    /// nil for warmup and cooldown, and when there is only one of that kind.
    func segment(at index: Int) -> (number: Int, count: Int)? {
        guard intervals.indices.contains(index) else { return nil }
        let kind = intervals[index].kind
        guard kind == .run || kind == .walk else { return nil }
        let count = intervals.filter { $0.kind == kind }.count
        guard count > 1 else { return nil }
        return (intervals[...index].filter { $0.kind == kind }.count, count)
    }

    /// Seconds spent running, walking between runs, and in the warmup and cooldown, up to `elapsed`.
    /// Warmup and cooldown are "easy" time: counted in duration and distance, excluded from pace.
    func activitySeconds(upTo elapsed: Int) -> (run: Int, walk: Int, easy: Int) {
        var run = 0, walk = 0, easy = 0, start = 0
        for iv in intervals {
            let spent = min(max(elapsed - start, 0), iv.seconds)
            switch iv.kind {
            case .run: run += spent
            case .walk: walk += spent
            case .warmup, .cooldown: easy += spent
            }
            start += iv.seconds
        }
        return (run, walk, easy)
    }

    /// Duration of the longest single run interval.
    var longestRunSeconds: Int { intervals.filter { $0.kind == .run }.map(\.seconds).max() ?? 0 }

    static func describe(_ i: Interval) -> String { "\(i.kind.label.lowercased()) \(durationWords(i.seconds))" }

    /// Compact form: "1 min", "90 sec", "2 min 30 sec".
    static func durationWords(_ s: Int) -> String {
        if s % 60 == 0 { return "\(s / 60) min" }
        if s < 120 { return "\(s) sec" }
        return "\(s / 60) min \(s % 60) sec"
    }

    /// Spoken form: "90 seconds", "1 minute", "2 minutes", "2 minutes 30 seconds".
    static func speechWords(_ s: Int) -> String {
        if s < 120 && s % 60 != 0 { return "\(s) seconds" }
        let m = s / 60, r = s % 60
        let mins = m == 1 ? "1 minute" : "\(m) minutes"
        return r == 0 ? mins : "\(mins) \(r) seconds"
    }
}

extension Session {
    /// Debug affordance: with the `-fast [factor]` launch argument, every interval is divided by
    /// the factor (20 by default, minimum 3 s). Without it, the session is unchanged.
    func applyingDebugSpeed(_ args: [String] = ProcessInfo.processInfo.arguments) -> Session {
        guard let i = args.firstIndex(of: "-fast") else { return self }
        let factor = args.indices.contains(i + 1) ? Int(args[i + 1]) ?? 20 : 20
        return Session(id: id, intervals: intervals.map { Interval(kind: $0.kind, seconds: max(3, $0.seconds / factor)) })
    }
}
