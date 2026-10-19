import AVFoundation

/// Plays the bundled run/walk/tick chimes and awaits completion.
@MainActor
final class ChimePlayer: NSObject, AVAudioPlayerDelegate {
    private var players: [ChimeKind: AVAudioPlayer] = [:]
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        for k in [ChimeKind.run, .walk, .tick] {
            if let url = Bundle.main.url(forResource: k.rawValue, withExtension: "caf"),
               let p = try? AVAudioPlayer(contentsOf: url) {
                p.delegate = self
                p.prepareToPlay()
                players[k] = p
            }
        }
    }

    func play(_ kind: ChimeKind) async {
        guard let p = players[kind] else { return }
        p.currentTime = 0
        await withCheckedContinuation { c in
            continuation = c
            if !p.play() { finish() }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully f: Bool) {
        Task { @MainActor in finish() }
    }

    private func finish() {
        continuation?.resume()
        continuation = nil
    }
}
