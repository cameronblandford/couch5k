import WatchKit

/// The tap on the wrist for each cue. A run and a walk feel different, so the screen is not necessary.
enum Haptics {
    static func play(for cue: Cue) {
        let type: WKHapticType? = switch cue.id {
        case .start: .start
        case .transition: cue.chime == .run ? .start : .stop
        case .tenSecondWarning: .directionUp
        case .halfway, .elapsedMinutes: .notification
        case .complete: .success
        case .paused, .resumed: .click
        }
        if let type { WKInterfaceDevice.current().play(type) }
    }
}
