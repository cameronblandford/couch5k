import SwiftUI

struct SessionSheet: View {
    let session: Session
    let isCompleted: Bool
    let onStart: () -> Void
    /// Called with `true` to also mark every earlier session as done.
    let onMarkDone: (_ includingEarlier: Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmMarkDone = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Total").foregroundStyle(.secondary)
                        Spacer()
                        Text(formatClock(session.totalSeconds)).monospacedDigit()
                    }
                    if isCompleted {
                        Label("Completed", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    }
                }
                Section("Intervals") {
                    ForEach(Array(session.intervals.enumerated()), id: \.offset) { _, iv in
                        HStack {
                            Circle().fill(Theme.color(for: iv.kind)).frame(width: 10, height: 10)
                            Text(iv.kind.label)
                            Spacer()
                            Text(Session.durationWords(iv.seconds)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button { onStart() } label: {
                        Text(isCompleted ? "Run again" : "Start").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    if !isCompleted {
                        Button("Already did this one? Mark as done") { confirmMarkDone = true }
                            .font(.subheadline)
                        .confirmationDialog("Mark as done without running it here?", isPresented: $confirmMarkDone, titleVisibility: .visible) {
                            Button("Mark \(session.title) as done") { onMarkDone(false) }
                            if session.id > SessionID(week: 1, day: 1) {
                                Button("Mark this and all earlier runs as done") { onMarkDone(true) }
                            }
                        } message: {
                            Text("Nothing is saved to Health. You can undo this by deleting it from History.")
                        }
                    }
                }
                .padding()
                .background(.bar)
            }
        }
    }
}
