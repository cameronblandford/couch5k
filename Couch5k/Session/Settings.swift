import Foundation
import Observation

@Observable @MainActor
final class Settings {
    var voiceIdentifier: String? { didSet { UserDefaults.standard.set(voiceIdentifier, forKey: "voice") } }
    var chimesEnabled: Bool { didSet { UserDefaults.standard.set(chimesEnabled, forKey: "chimes") } }
    var useMiles: Bool { didSet { UserDefaults.standard.set(useMiles, forKey: "miles") } }
    /// Show the warmup drills before each run.
    var warmupDrills: Bool { didSet { UserDefaults.standard.set(warmupDrills, forKey: "warmupDrills") } }
    /// Speak the cues. The watch has a switch for this; the phone always speaks.
    var voiceCues: Bool { didSet { UserDefaults.standard.set(voiceCues, forKey: "voiceCues") } }

    init() {
        let d = UserDefaults.standard
        voiceIdentifier = d.string(forKey: "voice")
        chimesEnabled = d.object(forKey: "chimes") as? Bool ?? true
        useMiles = d.object(forKey: "miles") as? Bool ?? true
        warmupDrills = d.object(forKey: "warmupDrills") as? Bool ?? true
        voiceCues = d.object(forKey: "voiceCues") as? Bool ?? true
    }
}
