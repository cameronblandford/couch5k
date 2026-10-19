enum ChimeKind: String, Sendable { case run, walk, tick }

enum CueID: Hashable, Codable, Sendable {
    case start
    case transition(Int)
    case tenSecondWarning(Int)
    case halfway(Int)
    case elapsedMinutes(Int)
    case complete
    case paused
    case resumed
}

struct Cue: Equatable, Sendable {
    let id: CueID
    let chime: ChimeKind?
    let speech: String?
}
