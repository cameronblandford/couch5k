import MediaPlayer

/// Routes headphone play/pause presses to the workout when Couch5k is the Now Playing app.
/// With music playing in another app, those presses go to the music app instead; that is
/// the intended trade-off for never stealing playback.
@MainActor
final class RemoteCommands {
    private let onPause: () -> Void
    private let onResume: () -> Void
    private let onToggle: () -> Void

    init(onPause: @escaping () -> Void, onResume: @escaping () -> Void, onToggle: @escaping () -> Void) {
        self.onPause = onPause
        self.onResume = onResume
        self.onToggle = onToggle
    }

    func activate(title: String) {
        let c = MPRemoteCommandCenter.shared()
        c.pauseCommand.addTarget { [onPause] _ in onPause(); return .success }
        c.playCommand.addTarget { [onResume] _ in onResume(); return .success }
        c.togglePlayPauseCommand.addTarget { [onToggle] _ in onToggle(); return .success }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Couch5k",
        ]
    }

    func deactivate() {
        let c = MPRemoteCommandCenter.shared()
        c.pauseCommand.removeTarget(nil)
        c.playCommand.removeTarget(nil)
        c.togglePlayPauseCommand.removeTarget(nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
