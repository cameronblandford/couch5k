import AVFoundation

/// Serial cue queue: activates the session, plays chime then speech for each cue,
/// and deactivates the session when the queue drains.
@MainActor
final class AudioCoach {
    var voiceIdentifier: String?
    var chimesEnabled = true
    var speechEnabled = true

    private let session = AudioSessionController()
    private let speaker = Speaker()
    private let chimes = ChimePlayer()
    private var queue: [Cue] = []
    private var draining = false

    init() { session.configure() }

    private var voice: AVSpeechSynthesisVoice? {
        if let id = voiceIdentifier, let v = AVSpeechSynthesisVoice(identifier: id) { return v }
        return SpeechCoach.bestDefaultVoice()
    }

    func enqueue(_ cues: [Cue]) {
        guard !cues.isEmpty else { return }
        queue.append(contentsOf: cues)
        drain()
    }

    func preview(_ text: String) {
        enqueue([Cue(id: .start, chime: .run, speech: text)])
    }

    private func drain() {
        guard !draining else { return }
        draining = true
        Task {
            session.activate()
            while !queue.isEmpty {
                let cue = queue.removeFirst()
                if chimesEnabled, let c = cue.chime { await chimes.play(c) }
                if speechEnabled, let s = cue.speech { await speaker.speak(s, voice: voice) }
            }
            session.deactivate()
            draining = false
        }
    }
}
