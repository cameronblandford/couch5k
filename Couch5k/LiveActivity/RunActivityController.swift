import ActivityKit

/// `Activity` is not Sendable but its async methods run off the caller's actor,
/// so the handle lives in an unchecked box owned by this main-actor controller.
private final class ActivityBox: @unchecked Sendable {
    var activity: Activity<RunActivityAttributes>?
}

@MainActor
final class RunActivityController {
    private let box = ActivityBox()
    /// Highest priority for the Dynamic Island. The system still decides between different apps.
    nonisolated static let relevance = 100.0

    func start(title: String, intervalCount: Int, state: RunActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        box.activity = try? Activity.request(attributes: .init(title: title, intervalCount: intervalCount),
                                             content: .init(state: state, staleDate: nil, relevanceScore: Self.relevance))
    }

    func update(_ state: RunActivityAttributes.ContentState) {
        let box = box
        Task { await box.activity?.update(.init(state: state, staleDate: nil, relevanceScore: Self.relevance)) }
    }

    func end() {
        let box = box
        Task {
            await box.activity?.end(nil, dismissalPolicy: .immediate)
            box.activity = nil
        }
    }
}
