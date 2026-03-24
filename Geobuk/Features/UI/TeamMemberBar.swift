import SwiftUI

/// 리더 패널 하단에 표시되는 팀원 미니 터미널 바
struct TeamMemberBar: View {
    let teammates: [TeamPaneTracker.Teammate]
    let teamSurfaceViews: [String: GhosttySurfaceView]
    let expandedSurfaceId: String?
    let leaderSurfaceId: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 2) {
            // 확대 모드일 때 리더 카드 표시
            if expandedSurfaceId != nil {
                TeamMemberLabel(name: "leader", color: "white", isExpanded: false)
                    .onTapGesture { onSelect(leaderSurfaceId) }
            }

            ForEach(teammates, id: \.surfaceId) { mate in
                let isExpanded = expandedSurfaceId == mate.surfaceId
                if isExpanded {
                    TeamMemberLabel(name: mate.name, color: mate.color, isExpanded: true)
                        .onTapGesture { onSelect(mate.surfaceId) }
                } else {
                    TeamMemberMiniTerminal(
                        teammate: mate,
                        surfaceView: teamSurfaceViews[mate.surfaceId]
                    )
                    .onTapGesture { onSelect(mate.surfaceId) }
                }
            }
        }
    }
}

/// 확대/축소 상태 라벨
struct TeamMemberLabel: View {
    let name: String
    let color: String
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(TeamMemberMiniTerminal.colorForAgent(color))
                .frame(width: 6, height: 6)
            Text(name)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary.opacity(0.7))
                .lineLimit(1)
            if isExpanded {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isExpanded
                    ? TeamMemberMiniTerminal.colorForAgent(color).opacity(0.15)
                    : Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(TeamMemberMiniTerminal.colorForAgent(color).opacity(isExpanded ? 0.5 : 0.2), lineWidth: 1)
        )
    }
}

/// 개별 팀원 미니 터미널
struct TeamMemberMiniTerminal: View {
    let teammate: TeamPaneTracker.Teammate
    let surfaceView: GhosttySurfaceView?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Self.colorForAgent(teammate.color))
                    .frame(width: 6, height: 6)
                Text(teammate.name)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.7))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(nsColor: .windowBackgroundColor))

            if let sv = surfaceView {
                TerminalSurfaceRepresentable(surfaceView: sv)
                    .frame(minHeight: 80)
            } else {
                Color.black
                    .frame(minHeight: 80)
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Self.colorForAgent(teammate.color).opacity(0.4), lineWidth: 1)
        )
    }

    static func colorForAgent(_ name: String) -> Color {
        switch name.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "yellow": return .yellow
        case "purple": return .purple
        case "orange": return .orange
        case "cyan": return .cyan
        case "pink": return .pink
        case "white": return .white
        default: return .gray
        }
    }
}
