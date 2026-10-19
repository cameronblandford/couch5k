import SwiftUI

enum Theme {
    static let accent = Color(red: 0.98, green: 0.55, blue: 0.20)
    static let background = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let surface = Color(white: 0.12)
    /// The accent, darkened for use as a data mark on chart surfaces (validated against the run and walk tones).
    static let chartAll = Color(red: 0.85, green: 0.41, blue: 0.06)
    /// Status colours for comparisons. Always paired with an arrow and a word, never colour alone.
    static let better = Color(red: 0.30, green: 0.85, blue: 0.50)
    static let worse = Color(red: 0.95, green: 0.40, blue: 0.40)

    static func color(for kind: IntervalKind) -> Color {
        switch kind {
        case .run: Color(red: 0.08, green: 0.60, blue: 0.32)
        case .walk: Color(red: 0.13, green: 0.42, blue: 0.88)
        case .warmup, .cooldown: Color(red: 0.24, green: 0.24, blue: 0.28)
        }
    }

    static func numeral(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
}

func formatClock(_ seconds: Int) -> String {
    let m = seconds / 60, s = seconds % 60
    return String(format: "%d:%02d", m, s)
}

func formatDistance(_ meters: Double?, miles: Bool) -> String {
    guard let m = meters else { return "—" }
    return miles ? String(format: "%.2f mi", m / 1609.344) : String(format: "%.2f km", m / 1000)
}

func formatElevation(_ meters: Double, miles: Bool) -> String {
    miles ? "\(Int((meters * 3.28084).rounded())) ft" : "\(Int(meters.rounded())) m"
}

/// Seconds-per-km delta as a short signed clock, in the display unit: "0:12".
func formatPaceDelta(_ secPerKm: Double, miles: Bool) -> String {
    formatClock(Int((miles ? secPerKm * 1.609344 : secPerKm).rounded()))
}

struct PaceDelta: Equatable {
    let faster: Bool
    let text: String
}

/// Change versus a baseline pace, or nil when either side is missing or the change is under 2 s per km.
func paceDelta(_ current: Double?, _ base: Double?, miles: Bool) -> PaceDelta? {
    guard let current, let base else { return nil }
    let diff = base - current    // positive means faster (fewer seconds per km)
    guard abs(diff) >= 2 else { return nil }
    return .init(faster: diff > 0, text: "\(formatPaceDelta(abs(diff), miles: miles)) \(diff > 0 ? "faster" : "slower")")
}

func formatPace(_ secPerKm: Double?, miles: Bool) -> String {
    guard let p = secPerKm, p.isFinite else { return "—" }
    let v = miles ? p * 1.609344 : p
    return "\(formatClock(Int(v)))/\(miles ? "mi" : "km")"
}
