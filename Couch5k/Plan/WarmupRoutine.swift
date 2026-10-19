import Foundation

/// One drill of the warmup before a run.
struct WarmupDrill: Equatable, Sendable, Identifiable {
    let name: String
    let seconds: Int
    /// How to do it, in one line. Shown on the screen and spoken at the start of the drill.
    let how: String
    var id: String { name }
}

/// Where the warmup is at a moment: the drill in work and the time that is left in it.
struct WarmupState: Equatable, Sendable {
    var drillIndex: Int
    var secondsRemainingInDrill: Int
    var elapsedSeconds: Int
    var totalSeconds: Int
    var isFinished: Bool
}

/// The dynamic warmup before a run: hops and skips that wake the calves and the hips, so the
/// first run interval does not start on cold muscles. It is a set of drills on the spot, about
/// three and a half minutes, before the session and its warmup walk start. Not saved to Health.
struct WarmupRoutine: Equatable, Sendable {
    let drills: [WarmupDrill]

    static let standard = WarmupRoutine(drills: [
        .init(name: "A-skips", seconds: 45, how: "Skip forward. Drive one knee up to hip height with each skip."),
        .init(name: "B-skips", seconds: 45, how: "Skip, lift the knee, then reach the foot forward and sweep it back down."),
        .init(name: "High knees", seconds: 30, how: "Run on the spot. Lift the knees fast and high."),
        .init(name: "Jump in place", seconds: 60, how: "Small quick jumps on the balls of your feet."),
        .init(name: "Butt kicks", seconds: 30, how: "Jog on the spot. Kick each heel up to your seat."),
    ])

    var totalSeconds: Int { drills.reduce(0) { $0 + $1.seconds } }

    /// The start of each drill in seconds from the start of the warmup, plus the total at the end.
    var boundaries: [Int] { drills.reduce(into: [0]) { $0.append($0.last! + $1.seconds) } }

    func state(elapsed: Int) -> WarmupState {
        let total = totalSeconds
        let e = min(max(elapsed, 0), total)
        let b = boundaries
        let index = e >= total ? max(drills.count - 1, 0) : (b.lastIndex { $0 <= e } ?? 0)
        return .init(drillIndex: index, secondsRemainingInDrill: drills.isEmpty ? 0 : max(0, b[index + 1] - e),
                     elapsedSeconds: e, totalSeconds: total, isFinished: e >= total)
    }

    /// The seconds from the start at which the drill with this index starts. A skip moves the clock here.
    func start(ofDrill index: Int) -> Int { boundaries[min(max(index, 0), drills.count)] }

    /// What the coach says when a drill starts.
    func speech(forDrill index: Int) -> String {
        let d = drills[index]
        return "\(index == 0 ? "Warm up. " : "")\(d.name). \(Session.speechWords(d.seconds)). \(d.how)"
    }

    static let doneSpeech = "Warm up done. Start your run when you are ready."

    /// Debug affordance, the same as for a session: `-fast [factor]` divides each drill (minimum 3 s).
    func applyingDebugSpeed(_ args: [String] = ProcessInfo.processInfo.arguments) -> WarmupRoutine {
        guard let i = args.firstIndex(of: "-fast") else { return self }
        let factor = args.indices.contains(i + 1) ? Int(args[i + 1]) ?? 20 : 20
        return WarmupRoutine(drills: drills.map { .init(name: $0.name, seconds: max(3, $0.seconds / factor), how: $0.how) })
    }
}
