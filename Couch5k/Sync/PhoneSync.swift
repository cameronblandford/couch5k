import Foundation
import SwiftData
import WatchConnectivity
import os

/// The phone side of the link to the watch app. It stores the runs that the watch sends,
/// and it tells the watch which runs the phone has, so the watch knows the next session.
@MainActor
final class PhoneSync: NSObject {
    static let shared = PhoneSync()
    nonisolated private static let log = Logger(subsystem: "com.example.Couch5k", category: "PhoneSync")
    private static let receivedKey = "watchRunsReceived"

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Ids of the newest watch runs that arrived. The watch stops its own copy of a run when it sees the id here.
    private var received: [UUID] {
        get { (UserDefaults.standard.stringArray(forKey: Self.receivedKey) ?? []).compactMap(UUID.init) }
        set { UserDefaults.standard.set(newValue.suffix(50).map(\.uuidString), forKey: Self.receivedKey) }
    }

    /// Sends the list of runs to the watch. Safe to call at any time: it does nothing with no watch app.
    func pushContext() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let runs = (try? Persistence.shared.mainContext.fetch(FetchDescriptor<CompletedRun>())) ?? []
        let context = SyncContext(runs: runs.map(\.summary), received: received)
        guard let data = try? JSONEncoder().encode(context) else { return }
        do {
            try WCSession.default.updateApplicationContext([SyncContext.key: data])
        } catch {
            Self.log.info("No context sent: \(error.localizedDescription)")
        }
    }

    /// Stores a run from the watch. The same run can arrive twice; the id stops a second copy.
    func store(_ payload: RunPayload) {
        let context = Persistence.shared.mainContext
        let id = payload.id
        let known = (try? context.fetchCount(FetchDescriptor<CompletedRun>(predicate: #Predicate { $0.id == id }))) ?? 0
        if known == 0, !received.contains(id) {
            context.insert(CompletedRun(payload: payload))
            if payload.completed { UserProgress.fetchOrCreate(in: context).advance(from: payload.sessionID) }
            try? context.save()
        }
        if !received.contains(id) { received.append(id) }
        pushContext()
    }
}

extension PhoneSync: WCSessionDelegate {
    nonisolated func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.pushContext() }
    }

    nonisolated func sessionDidBecomeInactive(_ s: WCSession) {}

    nonisolated func sessionDidDeactivate(_ s: WCSession) { s.activate() }

    nonisolated func session(_ s: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[SyncContext.runKey] as? Data,
              let payload = try? JSONDecoder().decode(RunPayload.self, from: data) else { return }
        Task { @MainActor in self.store(payload) }
    }
}
