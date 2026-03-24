import SwiftUI

/// 리더 패널 하단에 표시되는 팀원 미니 카드 바
struct TeamMemberBar: View {
    let teammates: [TeamPaneTracker.Teammate]
    let onSelect: (String) -> Void  // surfaceId

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(teammates, id: \.surfaceId) { mate in
                    TeamMemberCard(teammate: mate)
                        .onTapGesture { onSelect(mate.surfaceId) }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    }
}

/// 개별 팀원 미니 카드
struct TeamMemberCard: View {
    let teammate: TeamPaneTracker.Teammate

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(agentColor(teammate.color))
                .frame(width: 7, height: 7)
            Text(teammate.name)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.primary.opacity(0.8))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(4)
    }

    private func agentColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "yellow": return .yellow
        case "purple": return .purple
        case "orange": return .orange
        case "cyan": return .cyan
        case "pink": return .pink
        default: return .gray
        }
    }
}
