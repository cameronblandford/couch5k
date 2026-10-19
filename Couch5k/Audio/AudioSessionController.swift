import AVFoundation

/// Owns the shared audio session. Active only while a cue plays so other apps' audio
/// ducks during the cue and returns to full volume immediately after.
@MainActor
final class AudioSessionController {
    private let session = AVAudioSession.sharedInstance()
    private var active = false

    func configure() {
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
    }

    func activate() {
        guard !active else { return }
        try? session.setActive(true)
        active = true
    }

    func deactivate() {
        guard active else { return }
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        active = false
    }
}
