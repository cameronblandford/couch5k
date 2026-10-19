import ActivityKit
import SwiftUI
import WidgetKit

struct RunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { ctx in
            LockScreenView(ctx: ctx)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(ctx.state.finished ? "Done" : ctx.state.kind.label, systemImage: ctx.state.finished ? "checkmark.circle.fill" : icon(ctx.state.kind))
                        .font(.headline)
                        .foregroundStyle(color(ctx.state.kind))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: ctx.state)
                        .font(.title2.monospacedDigit().bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(detailLine(ctx))
                        Spacer()
                        RemainingText(state: ctx.state)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: icon(ctx.state.kind))
                    if let seg = ctx.state.segmentLabel { Text(seg).font(.caption2.weight(.semibold)).monospacedDigit() }
                }
                .foregroundStyle(color(ctx.state.kind))
            } compactTrailing: {
                Countdown(state: ctx.state).monospacedDigit().frame(width: 44)
            } minimal: {
                // When another app's activity shares the island, ours shrinks to this bubble: keep the time visible.
                Countdown(state: ctx.state)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(color(ctx.state.kind))
            }
        }
    }
}

struct Countdown: View {
    let state: RunActivityAttributes.ContentState
    var body: some View {
        if state.finished {
            Image(systemName: "checkmark")
        } else if state.paused {
            Text("Paused")
        } else {
            // A timer Text claims all offered width and left-aligns, so pin it to the trailing edge.
            Text(timerInterval: Date.now...max(Date.now, state.intervalEndDate), countsDown: true)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// "18:57 left" for the whole session. Counts down on its own; static while paused.
struct RemainingText: View {
    let state: RunActivityAttributes.ContentState
    var body: some View {
        if state.finished {
            EmptyView()
        } else if state.paused, let secs = state.sessionSecondsRemaining {
            Text("\(secs / 60):\(String(format: "%02d", secs % 60)) left").monospacedDigit()
        } else if let end = state.sessionEndDate {
            HStack(spacing: 3) {
                Text(timerInterval: Date.now...max(Date.now, end), countsDown: true)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 52, alignment: .trailing)
                Text("left")
            }
        }
    }
}

/// "Week 1, Run 1 · Run 4 of 8", or just the title during warmup and cooldown.
func detailLine(_ ctx: ActivityViewContext<RunActivityAttributes>) -> String {
    guard let n = ctx.state.segmentNumber, let c = ctx.state.segmentCount else { return ctx.attributes.title }
    return "\(ctx.attributes.title) · \(ctx.state.kind.label) \(n) of \(c)"
}

func icon(_ k: IntervalKind) -> String { k.isRunning ? "figure.run" : "figure.walk" }

func color(_ k: IntervalKind) -> Color {
    switch k {
    // Brighter than the in-app tones: these sit on the black island and the dark lock screen.
    case .run: Color(red: 0.30, green: 0.88, blue: 0.55)
    case .walk: Color(red: 0.45, green: 0.70, blue: 1.0)
    case .warmup, .cooldown: .gray
    }
}

struct LockScreenView: View {
    let ctx: ActivityViewContext<RunActivityAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ctx.state.finished ? "DONE" : ctx.state.kind.label.uppercased())
                    .font(.headline)
                    .foregroundStyle(color(ctx.state.kind))
                Text(detailLine(ctx))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Countdown(state: ctx.state)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: 130, alignment: .trailing)
                RemainingText(state: ctx.state)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.6))
    }
}
