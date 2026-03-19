import SwiftUI

// MARK: - Pane Info Model

/// 사이드바 패널 트리에 표시할 개별 패널 정보
struct PaneTreeInfo: Identifiable, Sendable {
    let id: UUID
    let index: Int
    let isFocused: Bool
    let processName: String?
    let currentDirectory: String?
    let isClaudeSession: Bool
    let claudePhase: AISessionPhase?
    let tokenCount: Int
    let costUSD: Double
    let listeningPorts: [UInt16]

    /// 프로세스가 없을 때 (idle) 여부
    var isIdle: Bool {
        processName == nil
    }

    /// Claude 상태 표시 텍스트
    var claudeStatusText: String? {
        guard isClaudeSession, let phase = claudePhase else { return nil }
        switch phase {
        case .responding: return "Responding"
        case .toolExecuting: return "ToolExecuting"
        case .waitingForInput: return "Waiting"
        case .sessionActive: return "Active"
        case .sessionComplete: return "Complete"
        default: return nil
        }
    }

    /// Claude 상태 색상
    var claudeStatusColor: Color {
        guard let phase = claudePhase else { return .gray }
        switch phase {
        case .responding: return .green
        case .toolExecuting: return .blue
        case .waitingForInput: return .yellow
        case .sessionActive: return .green
        default: return .gray
        }
    }
}

// MARK: - PaneTreeView

/// 활성 워크스페이스의 패널 트리를 표시하는 뷰
struct PaneTreeView: View {
    let panes: [PaneTreeInfo]
    let onPaneTap: ((UUID) -> Void)?

    init(panes: [PaneTreeInfo], onPaneTap: ((UUID) -> Void)? = nil) {
        self.panes = panes
        self.onPaneTap = onPaneTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(panes.enumerated()), id: \.element.id) { offset, pane in
                let isLast = offset == panes.count - 1
                PaneRowView(pane: pane, isLast: isLast)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onPaneTap?(pane.id)
                    }
            }
        }
    }
}

// MARK: - PaneRowView

/// 개별 패널 행
struct PaneRowView: View {
    let pane: PaneTreeInfo
    let isLast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 메인 행: 트리 커넥터 + 패널 번호 + 프로세스명
            HStack(spacing: 0) {
                // 트리 커넥터
                Text(isLast ? "\u{2514}\u{2500} " : "\u{251C}\u{2500} ")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))

                // 패널 번호
                Text("Pane \(pane.index):")
                    .font(.system(size: 10, weight: pane.isFocused ? .semibold : .regular))
                    .foregroundColor(pane.isFocused ? .primary : .secondary)

                Text(" ")

                // 프로세스명 + 경로
                if let processName = pane.processName {
                    Text(processName)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(pane.isClaudeSession ? .green : .secondary)
                } else if pane.currentDirectory != nil {
                    Text("zsh")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text("(starting...)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }

                if let dir = pane.currentDirectory {
                    Text(" ")
                    Text(abbreviatedPath(dir))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                // Claude 상태 인디케이터
                if pane.isClaudeSession, let statusText = pane.claudeStatusText {
                    Text(" ")
                    Text(statusText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(pane.claudeStatusColor)
                    Text(" ")
                    Circle()
                        .fill(pane.claudeStatusColor)
                        .frame(width: 6, height: 6)
                }

                Spacer()
            }
            .padding(.vertical, 1)

            // 서브 행: Claude 토큰/비용
            if pane.isClaudeSession && pane.tokenCount > 0 {
                HStack(spacing: 0) {
                    // 들여쓰기: 트리 라인 + 서브아이템 커넥터
                    Text(isLast ? "    \u{2514}\u{2500} " : "\u{2502}   \u{2514}\u{2500} ")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.6))

                    Text(PaneTreeView.formatTokenCount(pane.tokenCount))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)

                    if pane.costUSD > 0 {
                        Text(" \u{00B7} ")
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(PaneTreeView.formatCost(pane.costUSD))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 0)
            }

            // 서브 행: 리스닝 포트
            if !pane.listeningPorts.isEmpty {
                let hasTokenLine = pane.isClaudeSession && pane.tokenCount > 0
                ForEach(Array(pane.listeningPorts.enumerated()), id: \.element) { portIndex, port in
                    let isLastPort = portIndex == pane.listeningPorts.count - 1
                    let isLastSubItem = isLastPort && !hasTokenLine
                    HStack(spacing: 0) {
                        // 들여쓰기
                        if isLast {
                            Text(isLastSubItem || isLastPort ? "    \u{2514}\u{2500} " : "    \u{251C}\u{2500} ")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.6))
                        } else {
                            Text(isLastPort ? "\u{2502}   \u{2514}\u{2500} " : "\u{2502}   \u{251C}\u{2500} ")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.6))
                        }

                        Text(":\(port)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.orange)

                        Spacer()
                    }
                    .padding(.vertical, 0)
                }
            }
        }
    }

    private func abbreviatedPath(_ path: String) -> String {
        PathAbbreviator.abbreviate(path)
    }
}

// MARK: - Formatting Helpers

extension PaneTreeView {
    /// 토큰 수를 읽기 쉽게 포맷한다 (예: 12500 -> 12.5k)
    static func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM tokens", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fk tokens", Double(count) / 1_000.0)
        }
        return "\(count) tokens"
    }

    /// 비용을 포맷한다 ($0.45 형식)
    static func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.3f", cost)
        }
        return String(format: "$%.2f", cost)
    }
}

