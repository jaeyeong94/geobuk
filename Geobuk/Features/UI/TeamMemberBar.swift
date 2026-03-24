import SwiftUI

/// 리더 패널 하단에 표시되는 팀원 미니 터미널 바
struct TeamMemberBar: View {
    let teammates: [TeamPaneTracker.Teammate]
    let teamSurfaceViews: [String: GhosttySurfaceView]
    let onSelect: (String) -> Void  // surfaceId

    var body: some View {
        HStack(spacing: 2) {
            ForEach(teammates, id: \.surfaceId) { mate in
                TeamMemberMiniTerminal(
                    teammate: mate,
                    surfaceView: teamSurfaceViews[mate.surfaceId]
                )
                .onTapGesture { onSelect(mate.surfaceId) }
            }
        }
    }
}

/// 개별 팀원 미니 터미널 — 실제 터미널 출력이 축소 표시됨
struct TeamMemberMiniTerminal: View {
    let teammate: TeamPaneTracker.Teammate
    let surfaceView: GhosttySurfaceView?

    var body: some View {
        VStack(spacing: 0) {
            // 헤더: 색상 + 이름
            HStack(spacing: 4) {
                Circle()
                    .fill(agentColor(teammate.color))
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

            // 미니 터미널 렌더링
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
                .stroke(agentColor(teammate.color).opacity(0.4), lineWidth: 1)
        )
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
