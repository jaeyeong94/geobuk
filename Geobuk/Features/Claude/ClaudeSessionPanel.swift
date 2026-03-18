import SwiftUI

/// 터미널 영역 하단에 표시되는 Claude 세션 상세 패널
/// 세션 상태, 최근 이벤트 로그, "New Claude Session" 버튼을 포함한다
struct ClaudeSessionPanel: View {
    let monitor: ClaudeSessionMonitor
    @Binding var isExpanded: Bool
    var onNewSession: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 토글 헤더
            panelHeader

            if isExpanded {
                Divider()
                panelContent
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 10)

                    let phaseInfo = PhaseDisplayInfo.from(phase: monitor.sessionState.phase)
                    Image(systemName: phaseInfo.systemImage)
                        .font(.system(size: 9))
                        .foregroundColor(phaseColor(phaseInfo.colorName))

                    Text("Claude")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)

                    if monitor.sessionState.phase != .idle {
                        Text(phaseInfo.label)
                            .font(.system(size: 10))
                            .foregroundColor(phaseColor(phaseInfo.colorName))
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if monitor.sessionState.phase != .idle {
                Text(SessionFormatter.formatCost(monitor.sessionState.costUSD))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Button(action: { onNewSession?() }) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("New Claude Session")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Content

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 상세 상태 뷰
            ClaudeStatusView(sessionState: monitor.sessionState)
                .padding(.horizontal, 8)

            // 새 세션 버튼 (세션이 없을 때)
            if monitor.sessionState.phase == .idle {
                Button(action: { onNewSession?() }) {
                    HStack {
                        Image(systemName: "terminal")
                            .font(.system(size: 12))
                        Text("New Claude Session")
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func phaseColor(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "gray": return .gray
        default: return .gray
        }
    }
}
