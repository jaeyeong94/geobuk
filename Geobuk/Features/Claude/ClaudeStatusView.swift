import SwiftUI

/// 사이드바 또는 패널에 표시되는 Claude 세션 상태 뷰
/// 세션 단계, 도구, 토큰 사용량, 비용, 경과 시간을 컴팩트하게 보여준다
struct ClaudeStatusView: View {
    let sessionState: ClaudeSessionState
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        let phaseInfo = PhaseDisplayInfo.from(phase: sessionState.phase)

        VStack(alignment: .leading, spacing: 6) {
            // 헤더: 상태 표시
            HStack(spacing: 6) {
                Image(systemName: phaseInfo.systemImage)
                    .foregroundColor(phaseInfo.color)
                    .font(.system(size: 10))

                Text("Claude Session")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)

                if sessionState.phase != .idle {
                    Text(phaseInfo.label)
                        .font(.system(size: 10))
                        .foregroundColor(phaseInfo.color)
                }

                Spacer()
            }

            if sessionState.phase != .idle {
                // 현재 도구
                if let toolName = sessionState.currentToolName {
                    HStack(spacing: 4) {
                        Image(systemName: "wrench.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(toolName)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                // 토큰 사용량
                HStack(spacing: 8) {
                    Label {
                        Text("\(SessionFormatter.formatTokenCount(sessionState.tokenUsage.inputTokens)) in")
                            .font(.system(size: 10))
                    } icon: {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)

                    Label {
                        Text("\(SessionFormatter.formatTokenCount(sessionState.tokenUsage.outputTokens)) out")
                            .font(.system(size: 10))
                    } icon: {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                }

                // 비용 + 경과 시간
                HStack(spacing: 8) {
                    Label {
                        Text(SessionFormatter.formatCost(sessionState.costUSD))
                            .font(.system(size: 10))
                    } icon: {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)

                    Label {
                        Text(SessionFormatter.formatElapsedTime(elapsedTime))
                            .font(.system(size: 10))
                    } icon: {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                }

                // 팀원 목록
                if !sessionState.teammates.isEmpty {
                    Divider()
                        .padding(.vertical, 2)

                    Text("Team Members:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)

                    ForEach(sessionState.teammates) { teammate in
                        TeammateRow(teammate: teammate)
                    }

                    // 팀 총 비용
                    let totalCost = sessionState.costUSD + sessionState.teammates.reduce(0.0) { sum, t in
                        sum + Double(t.tokenUsage.inputTokens) * 3.0 / 1_000_000.0
                            + Double(t.tokenUsage.outputTokens) * 15.0 / 1_000_000.0
                    }
                    HStack {
                        Spacer()
                        Text("Total: \(SessionFormatter.formatCost(totalCost))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                )
        )
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if let startedAt = sessionState.startedAt {
                    elapsedTime = Date().timeIntervalSince(startedAt)
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

}

// MARK: - Teammate Row

/// 팀원 상태를 표시하는 행
private struct TeammateRow: View {
    let teammate: TeammateState

    var body: some View {
        let phaseInfo = PhaseDisplayInfo.from(phase: teammate.phase)

        HStack(spacing: 4) {
            Image(systemName: phaseInfo.systemImage)
                .foregroundColor(phaseInfo.color)
                .font(.system(size: 8))

            Text(teammate.name)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Text(phaseInfo.label)
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.7))

            if let tool = teammate.currentTool {
                Text("(\(tool))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            if teammate.tokenUsage.totalTokens > 0 {
                Text("(\(SessionFormatter.formatTokenCount(teammate.tokenUsage.totalTokens)))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.5))
            }

            if teammate.phase == .waitingForInput {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.yellow)
            }
        }
    }

}
