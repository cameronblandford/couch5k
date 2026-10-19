enum IntervalKind: String, Codable, Sendable {
    case warmup, run, walk, cooldown
    var isRunning: Bool { self == .run }
    var label: String {
        switch self {
        case .warmup: "Warm up"
        case .run: "Run"
        case .walk: "Walk"
        case .cooldown: "Cool down"
        }
    }
}

struct Interval: Equatable, Codable, Sendable {
    let kind: IntervalKind
    let seconds: Int
    static func run(_ s: Int) -> Interval { .init(kind: .run, seconds: s) }
    static func walk(_ s: Int) -> Interval { .init(kind: .walk, seconds: s) }
    static let warmup = Interval(kind: .warmup, seconds: 300)
    static let cooldown = Interval(kind: .cooldown, seconds: 300)
}
