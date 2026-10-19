import Foundation
import Observation
import WatchConnectivity
import os

/// The run history on the watch and the link to the phone. The phone owns the history:
/// the watch keeps the phone's list, plus its own runs until the phone confirms them.
@Observable @MainActor
final class WatchStore: NSObject {
    private(set) var history = WatchHistory()
    nonisolated private static let log = Logger(subsystem: "com.example.Couch5k", category: "WatchStore")

    private struct Saved: Codable {
        var context: SyncContext
        var pending: [RunPayload]
    }

    private let fileURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("watch-history.json")

    /// Debug affordance: with the `-uitest` launch argument the store starts empty, keeps nothing, and
    /// does not talk to a phone, so each UI test starts from the same state.
    private let isTest = ProcessInfo.processInfo.arguments.contains("-uitest")

    override init() {
        super.init()
        guard !isTest else {
            RunRecovery.default.clear()
            return
        }
        if let data = try? Data(contentsOf: fileURL), let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            history = WatchHistory(context: saved.context, pending: saved.pending)
        }
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// Keeps a finished run and puts it in the queue to the phone. The system delivers it when the phone is in reach.
    func add(_ payload: RunPayload) {
        history.pending.append(payload)
        persist()
        send(payload)
    }

    private func send(_ payload: RunPayload) {
        guard !isTest, WCSession.isSupported(), WCSession.default.activationState == .activated,
              let data = try? JSONEncoder().encode(payload) else { return }
        WCSession.default.transferUserInfo([SyncContext.runKey: data])
    }

    /// Sends again each pending run that is not in the system's queue, for example after a new install of the phone app.
    private func resendPending() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let queued = Set(WCSession.default.outstandingUserInfoTransfers.compactMap { transfer -> UUID? in
            guard let data = transfer.userInfo[SyncContext.runKey] as? Data else { return nil }
            return (try? JSONDecoder().decode(RunPayload.self, from: data))?.id
        })
        for run in history.pending where !queued.contains(run.id) { send(run) }
    }

    private func apply(_ context: SyncContext) {
        history.apply(context)
        persist()
        resendPending()
    }

    private func persist() {
        guard !isTest else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(Saved(context: history.context, pending: history.pending)).write(to: fileURL, options: .atomic)
        } catch {
            Self.log.error("History not saved: \(error.localizedDescription)")
        }
    }

    nonisolated private static func context(in dictionary: [String: Any]) -> SyncContext? {
        guard let data = dictionary[SyncContext.key] as? Data else { return nil }
        return try? JSONDecoder().decode(SyncContext.self, from: data)
    }
}

extension WatchStore: WCSessionDelegate {
    nonisolated func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let context = Self.context(in: s.receivedApplicationContext)
        Task { @MainActor in
            if let context { self.apply(context) } else { self.resendPending() }
        }
    }

    nonisolated func session(_ s: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let context = Self.context(in: applicationContext) else { return }
        Task { @MainActor in self.apply(context) }
    }
}
