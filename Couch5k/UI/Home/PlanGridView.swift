import SwiftUI

struct PlanGridView: View {
    let completed: Set<SessionID>
    let next: SessionID?
    let onSelect: (SessionID) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(1...9, id: \.self) { week in
                HStack(spacing: 8) {
                    Text("W\(week)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .leading)
                    ForEach(1...3, id: \.self) { day in
                        let id = SessionID(week: week, day: day)
                        let done = completed.contains(id)
                        let isNext = id == next
                        Button { onSelect(id) } label: {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(done ? Theme.accent : (isNext ? Theme.accent.opacity(0.2) : Theme.surface))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isNext ? Theme.accent : .clear, lineWidth: 2))
                                .frame(height: 38)
                                .overlay(
                                    Group {
                                        if done { Image(systemName: "checkmark").font(.caption.bold()) }
                                        else { Text("\(day)").font(.caption.bold()) }
                                    }
                                    .foregroundStyle(done ? .black : .white)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
