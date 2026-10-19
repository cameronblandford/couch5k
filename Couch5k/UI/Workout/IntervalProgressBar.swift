import SwiftUI

/// One continuous bar. Run and walk sections are distinct tones, the elapsed part is bright,
/// the remainder is dim, and a playhead marks the current position.
struct IntervalProgressBar: View {
    enum Style {
        /// For dark surfaces: run green, walk blue.
        case tinted
        /// For the full-bleed colored workout screen: run solid white, walk translucent white.
        case onColor
    }

    let intervals: [Interval]
    let elapsedSeconds: Int
    var height: CGFloat = 10
    var style: Style = .tinted
    var showsPlayhead = true
    /// A thin marker at half the session's total time.
    var showsHalfway = false

    var body: some View {
        GeometryReader { geo in
            let total = max(1, intervals.reduce(0) { $0 + $1.seconds })
            let progress = min(max(Double(elapsedSeconds) / Double(total), 0), 1)
            let width = geo.size.width

            ZStack(alignment: .leading) {
                sections(total: total, width: width).opacity(style == .onColor ? 0.38 : 0.3)
                sections(total: total, width: width)
                    .mask(alignment: .leading) { Rectangle().frame(width: width * progress) }
                if showsHalfway {
                    Capsule()
                        .fill(style == .onColor ? Color.black.opacity(0.45) : Color.white.opacity(0.7))
                        .frame(width: 2, height: height + 10)
                        .offset(x: width * 0.5 - 1)
                }
                if showsPlayhead, progress > 0, progress < 1 {
                    Capsule()
                        .fill(.white)
                        .frame(width: 3, height: height + 8)
                        .shadow(color: .black.opacity(0.35), radius: 2)
                        .offset(x: width * progress - 1.5)
                }
            }
            .frame(height: height + 8)
        }
        .frame(height: height + 8)
    }

    private func sections(total: Int, width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(intervals.enumerated()), id: \.offset) { _, iv in
                Rectangle()
                    .fill(color(for: iv.kind))
                    .frame(width: width * CGFloat(iv.seconds) / CGFloat(total))
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }

    private func color(for kind: IntervalKind) -> Color {
        switch style {
        case .tinted:
            return Theme.color(for: kind)
        case .onColor:
            return kind == .run ? .white : .white.opacity(0.45)
        }
    }
}
