import AVFoundation

enum SpeechCoach {
    /// English voices: female first, then best quality, then name.
    static func availableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { a, b in
                (a.gender == .female ? 1 : 0, a.quality.rawValue, b.name) > (b.gender == .female ? 1 : 0, b.quality.rawValue, a.name)
            }
    }

    /// Prefers a female voice in the device locale, at the highest installed quality.
    static func bestDefaultVoice() -> AVSpeechSynthesisVoice? {
        let locale = AVSpeechSynthesisVoice.currentLanguageCode()
        let candidates = availableVoices()
        return candidates.first { $0.language == locale && $0.gender == .female }
            ?? candidates.first { $0.gender == .female }
            ?? candidates.first { $0.language == locale }
            ?? candidates.first
    }

    static func genderLabel(_ v: AVSpeechSynthesisVoice) -> String? {
        switch v.gender {
        case .female: "Female"
        case .male: "Male"
        default: nil
        }
    }

    static func qualityLabel(_ v: AVSpeechSynthesisVoice) -> String {
        switch v.quality {
        case .premium: "Premium"
        case .enhanced: "Enhanced"
        default: "Standard"
        }
    }
}

/// Speaks one utterance at a time and awaits its completion.
@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, voice: AVSpeechSynthesisVoice?) async {
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        u.prefersAssistiveTechnologySettings = false
        await withCheckedContinuation { c in
            continuation = c
            synth.speak(u)
        }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in finish() }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in finish() }
    }

    private func finish() {
        continuation?.resume()
        continuation = nil
    }
}
