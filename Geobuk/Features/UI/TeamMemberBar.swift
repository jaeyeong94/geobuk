import SwiftUI

/// 리더 패널 하단에 표시되는 팀원 바
/// 1~3명: 미니 터미널, 4명+: 라벨 카드 (스크롤)
struct TeamMemberBar: View {
    let teammates: [TeamPaneTracker.Teammate]
    let teamSurfaceViews: [String: GhosttySurfaceView]
    let expandedSurfaceId: String?
    let leaderSurfaceId: String
    let onSelect: (String) -> Void

    private var useMiniTerminals: Bool {
        teammates.count <= 3 && expandedSurfaceId == nil
    }

    var body: some View {
        if useMiniTerminals {
            // 1~3명: 미니 터미널 가로 배치
            HStack(spacing: 2) {
                ForEach(teammates, id: \.surfaceId) { mate in
                    TeamMemberMiniTerminal(
                        teammate: mate,
                        surfaceView: teamSurfaceViews[mate.surfaceId]
                    )
                    .onTapGesture { onSelect(mate.surfaceId) }
                }
            }
        } else {
            // 4명+ 또는 확대 모드: 라벨 카드 스크롤
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // 확대 모드일 때 리더 카드
                    if expandedSurfaceId != nil {
                        TeamMemberLabel(name: "leader", color: "white", isExpanded: false)
                            .onTapGesture { onSelect(leaderSurfaceId) }
                    }

                    ForEach(teammates, id: \.surfaceId) { mate in
                        let isExpanded = expandedSurfaceId == mate.surfaceId
                        TeamMemberLabel(name: mate.name, color: mate.color, isExpanded: isExpanded)
                            .onTapGesture { onSelect(mate.surfaceId) }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        }
    }
}

/// 라벨 카드 (확대/축소 상태 또는 4명+ 모드)
struct TeamMemberLabel: View {
    let name: String
    let color: String
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(TeamMemberMiniTerminal.colorForAgent(color))
                .frame(width: 8, height: 8)
            Text(name)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary.opacity(0.8))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
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

/// 개별 팀원 미니 터미널 (1~3명일 때)
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
