import SwiftUI

/// 워크스페이스 목록을 표시하는 사이드바 뷰
struct SidebarView: View {
    @Bindable var workspaceManager: WorkspaceManager
    var claudeMonitor: ClaudeSessionMonitor?
    var claudeFileWatcher: ClaudeSessionFileWatcher?
    var processMonitor: PaneProcessMonitor?
    var onWorkspaceSwitch: (() -> Void)?
    var onCreateWorkspace: (() -> Void)?
    var onNewClaudeSession: (() -> Void)?
    @State private var editingIndex: Int? = nil
    @State private var editingName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("Workspaces")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button(action: {
                    onCreateWorkspace?()
                }) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Workspace")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // 워크스페이스 목록
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(workspaceManager.workspaces.enumerated()), id: \.element.id) { index, workspace in
                        WorkspaceTabView(
                            workspace: workspace,
                            index: index,
                            isActive: index == workspaceManager.activeIndex,
                            isEditing: editingIndex == index,
                            claudeSessionCount: processMonitor?.claudeSessionCount(for: workspace) ?? 0,
                            editingName: $editingName,
                            onSelect: {
                                workspaceManager.switchToWorkspace(at: index)
                                onWorkspaceSwitch?()
                            },
                            onBeginRename: {
                                editingName = workspace.name
                                editingIndex = index
                            },
                            onCommitRename: {
                                workspaceManager.renameWorkspace(at: index, name: editingName)
                                editingIndex = nil
                            },
                            onCancelRename: {
                                editingIndex = nil
                            },
                            onClose: {
                                workspaceManager.closeWorkspace(at: index)
                            }
                        )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)
            }

            // 프로세스 모니터에서 감지된 Claude 세션 섹션
            if let processMonitor, !processMonitor.claudeProcesses.isEmpty {
                Divider()
                detectedClaudeSection(processMonitor: processMonitor)
            }

            // Claude 세션 상태 섹션
            if let monitor = claudeMonitor {
                Divider()
                claudeSessionSection(monitor: monitor)
            }

            // 파일 기반 Claude 세션 감지
            if let watcher = claudeFileWatcher, !watcher.activeSessions.isEmpty {
                Divider()
                fileWatcherSection(watcher: watcher)
            }
        }
        .frame(minWidth: 160, idealWidth: 200, maxWidth: 280)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Detected Claude Sessions Section

    @ViewBuilder
    private func detectedClaudeSection(processMonitor: PaneProcessMonitor) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Claude Sessions")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Text("\(processMonitor.claudeProcesses.count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.green))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // 각 감지된 Claude 세션 목록
            ForEach(Array(processMonitor.claudeProcesses.values), id: \.claudePid) { info in
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("\(info.processName) (PID \(info.claudePid))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 2)
            }

            Text("\(processMonitor.claudeProcesses.count) sessions active")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
        }
    }

    // MARK: - File Watcher Section

    @ViewBuilder
    private func fileWatcherSection(watcher: ClaudeSessionFileWatcher) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Active Claude")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(watcher.activeSessions.count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.green))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ForEach(watcher.activeSessions) { session in
                fileWatcherSessionRow(session: session)
            }

            // 전체 비용 합계 (claudeMonitor에서 가져옴)
            if let monitor = claudeMonitor, monitor.sessionState.costUSD > 0 {
                HStack {
                    Spacer()
                    Text(String(format: "Total: $%.2f", monitor.sessionState.costUSD))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func fileWatcherSessionRow(session: ClaudeFileSession) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(sessionStatusColor(for: session))
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("Session \(session.pid)")
                        .font(.system(size: 10, weight: .medium))
                    Text(abbreviatedPath(session.cwd))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                // 세션 상태 표시 (claudeMonitor의 상태를 활용)
                if let monitor = claudeMonitor, monitor.sessionState.phase != .idle {
                    HStack(spacing: 4) {
                        Text(sessionStatusText(monitor: monitor))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        if monitor.sessionState.tokenUsage.totalTokens > 0 {
                            Text(formatTokenCount(monitor.sessionState.tokenUsage.totalTokens))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
    }

    /// 세션 상태에 따른 색상
    private func sessionStatusColor(for session: ClaudeFileSession) -> Color {
        guard let monitor = claudeMonitor else { return .green }
        switch monitor.sessionState.phase {
        case .responding: return .green
        case .toolExecuting: return .blue
        case .waitingForInput: return .yellow
        case .sessionComplete: return .gray
        default: return .green
        }
    }

    /// 세션 상태 텍스트
    private func sessionStatusText(monitor: ClaudeSessionMonitor) -> String {
        let state = monitor.sessionState
        switch state.phase {
        case .responding: return "Responding"
        case .toolExecuting:
            if let tool = state.currentToolName {
                return "ToolExecuting: \(tool)"
            }
            return "ToolExecuting"
        case .waitingForInput: return "Waiting for input"
        case .sessionActive: return "Active"
        case .sessionComplete: return "Complete"
        default: return ""
        }
    }

    /// 토큰 수를 읽기 쉽게 포맷한다 (예: 12500 -> 12.5k)
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM tokens", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fk tokens", Double(count) / 1_000.0)
        }
        return "\(count) tokens"
    }

    private func abbreviatedPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path == home { return "~" }
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }

    // MARK: - Claude Session Section

    @ViewBuilder
    private func claudeSessionSection(monitor: ClaudeSessionMonitor) -> some View {
        VStack(spacing: 0) {
            // Claude 섹션 헤더
            HStack {
                Text("Claude")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button(action: {
                    onNewClaudeSession?()
                }) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Claude Session (Cmd+Shift+C)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // 세션 상태 표시
            if monitor.sessionState.phase != .idle {
                ClaudeStatusView(sessionState: monitor.sessionState)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
            } else {
                Button(action: { onNewClaudeSession?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                            .font(.system(size: 10))
                        Text("New Session")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
        }
    }
}

// MARK: - Workspace Tab

/// 사이드바에서 개별 워크스페이스를 나타내는 탭 뷰
struct WorkspaceTabView: View {
    let workspace: Workspace
    let index: Int
    let isActive: Bool
    let isEditing: Bool
    var claudeSessionCount: Int = 0
    var totalCost: Double = 0
    var activeProcessName: String? = nil
    var listeningPorts: [UInt16] = []
    @Binding var editingName: String
    let onSelect: () -> Void
    let onBeginRename: () -> Void
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void
    let onClose: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            // 숫자 인덱스
            Text("\(index + 1)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Name", text: $editingName, onCommit: onCommitRename)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .focused($isTextFieldFocused)
                        .onExitCommand(perform: onCancelRename)
                        .onAppear { isTextFieldFocused = true }
                } else {
                    Text(workspace.name)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // 경로
                Text(abbreviatedPath(workspace.cwd))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // 활성 프로세스
                if let processName = activeProcessName {
                    HStack(spacing: 3) {
                        Text("$")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text(processName)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                // Claude 세션 수 + 비용
                if claudeSessionCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                        Text("Claude x\(claudeSessionCount)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.green)
                        if totalCost > 0 {
                            Text(WorkspaceTabView.formatCost(totalCost))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 리스닝 포트
                if !listeningPorts.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(listeningPorts.prefix(4), id: \.self) { port in
                            Text(":\(port)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                        if listeningPorts.count > 4 {
                            Text("+\(listeningPorts.count - 4)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Rename") { onBeginRename() }
            Divider()
            Button("Close") { onClose() }
        }
    }

    /// 경로를 축약하여 표시 (홈 디렉토리 -> ~)
    private func abbreviatedPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path == home {
            return "~"
        } else if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    /// 비용을 포맷한다 ($0.45 형식)
    static func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.3f", cost)
        }
        return String(format: "$%.2f", cost)
    }
}
