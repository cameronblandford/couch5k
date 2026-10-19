import Foundation

/// Persists the engine snapshot so a force-quit or crash mid-run can be resumed.
struct RunRecovery {
    let fileURL: URL
    init(directory: URL) { fileURL = directory.appendingPathComponent("active-run.json") }

    static let `default`: RunRecovery = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return RunRecovery(directory: dir)
    }()

    func save(_ s: EngineSnapshot) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(s).write(to: fileURL, options: .atomic)
    }

    func load() -> EngineSnapshot? {
        guard let d = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(EngineSnapshot.self, from: d)
    }

    func clear() { try? FileManager.default.removeItem(at: fileURL) }
}
