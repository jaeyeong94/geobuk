import SwiftUI

/// 워크스페이스 목록을 표시하는 사이드바 뷰
struct SidebarView: View {
    @Bindable var workspaceManager: WorkspaceManager
    var claudeMonitor: ClaudeSessionMonitor?
    var claudeFileWatcher: ClaudeSessionFileWatcher?
    var processMonitor: PaneProcessMonitor?
    var shellStateManager: ShellStateManager?
    var surfaceViews: [UUID: GhosttySurfaceView] = [:]
    var onWorkspaceSwitch: (() -> Void)?
    var onCreateWorkspace: (() -> Void)?
    var onNewClaudeSession: (() -> Void)?
    var onPaneFocus: ((UUID) -> Void)?
    @State private var editingIndex: Int? = nil
    @State private var editingName: String = ""
    @State private var expandedWorkspaces: Set<Int> = []

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
                        let isActive = index == workspaceManager.activeIndex

                        VStack(spacing: 0) {
                            // 포커스 패널의 실제 cwd (없으면 workspace.cwd)
                            let focusedDir: String = {
                                if let focusedId = workspace.splitManager.focusedPaneId,
                                   let dir = surfaceViews[focusedId]?.currentDirectory {
                                    return dir
                                }
                                return workspace.cwd
                            }()

                            WorkspaceTabView(
                                workspace: workspace,
                                displayCwd: focusedDir,
                                index: index,
                                isActive: isActive,
                                isEditing: editingIndex == index,
                                claudeSessionCount: isActive ? 0 : (processMonitor?.claudeSessionCount(for: workspace) ?? 0),
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
                                },
                                isTreeExpanded: isActive,
                                onToggleTree: nil
                            )

                            // 활성 워크스페이스: 패널 트리 표시
                            if isActive {
                                let panes = workspace.splitManager.root.allLeaves()
                                if panes.count > 0 {
                                    PaneTreeView(
                                        panes: buildPaneInfoList(for: workspace),
                                        onPaneTap: { paneId in
                                            workspace.splitManager.setFocusedPane(id: paneId)
                                            onPaneFocus?(paneId)
                                        }
                                    )
                                    .padding(.leading, 24)
                                    .padding(.trailing, 8)
                                    .padding(.bottom, 4)
                                }
                            }
                        }
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

            // 파일 기반 Claude 세션 감지
            if let watcher = claudeFileWatcher, !watcher.activeSessions.isEmpty {
                Divider()
                fileWatcherSection(watcher: watcher)
                    .padding(.bottom, 16)
            }
        }
        .frame(minWidth: 160, idealWidth: 200, maxWidth: 280)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Pane Info Builder

    /// 워크스페이스의 패널 정보를 빌드한다
    private func buildPaneInfoList(for workspace: Workspace) -> [PaneTreeInfo] {
        let panes = workspace.splitManager.root.allLeaves()
        let focusedPaneId = workspace.splitManager.focusedPaneId

        return panes.enumerated().map { index, pane in
            let isFocused = pane.id == focusedPaneId

            // Claude 프로세스 정보
            let claudeInfo = processMonitor?.claudeProcesses.values.first(where: { $0.paneId == pane.id })
            let isClaudeSession = claudeInfo != nil

            // SurfaceView에서 현재 디렉토리 + 프로세스 정보 가져오기
            let surfaceView = surfaceViews[pane.id]
            let currentDir = surfaceView?.currentDirectory

            // 프로세스명: Claude이면 "claude", 셸 통합에서 running이면 command, 그 외 nil
            let shellProcessName = surfaceView.map { shellStateManager?.displayProcessName(for: $0.viewId.uuidString) } ?? nil
            let processName: String? = isClaudeSession
                ? (claudeInfo?.processName ?? "claude")
                : shellProcessName

            // Claude 상태
            let claudePhase: AISessionPhase? = isClaudeSession ? (claudeMonitor?.sessionState.phase ?? .sessionActive) : nil
            let tokenCount = isClaudeSession ? (claudeMonitor?.sessionState.tokenUsage.totalTokens ?? 0) : 0
            let costUSD = isClaudeSession ? (claudeMonitor?.sessionState.costUSD ?? 0) : 0

            return PaneTreeInfo(
                id: pane.id,
                index: index + 1,
                isFocused: isFocused,
                processName: processName,
                currentDirectory: currentDir,
                isClaudeSession: isClaudeSession,
                claudePhase: claudePhase,
                tokenCount: tokenCount,
                costUSD: costUSD,
                listeningPorts: []
            )
        }
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
        let matchingWorkspace = workspaceManager.workspaces.first { ws in
            abbreviatedPath(ws.cwd) == abbreviatedPath(session.cwd)
                || ws.cwd == session.cwd
        }

        VStack(alignment: .leading, spacing: 3) {
            // 라인 1: 상태 인디케이터 + 모델 이름
            HStack(spacing: 5) {
                Circle()
                    .fill(sessionStatusColor(for: session))
                    .frame(width: 7, height: 7)
                Text(claudeMonitor?.sessionModels[session.sessionId] ?? "claude")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            // 라인 2: Phase + 현재 도구
            if let monitor = claudeMonitor,
               let state = monitor.getState(for: session.sessionId) {
                Text(phaseText(state.phase, toolName: state.currentToolName))
                    .font(.system(size: 9))
                    .foregroundColor(state.phase == .waitingForInput ? .yellow : .secondary)
            }

            // 라인 3: 턴 시간 + 토큰 + 비용
            HStack(spacing: 6) {
                if let durationMs = claudeMonitor?.sessionTurnDurations[session.sessionId] {
                    Text(formatDuration(durationMs))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                if let state = claudeMonitor?.getState(for: session.sessionId),
                   state.tokenUsage.totalTokens > 0 {
                    Text(formatTokenCount(state.tokenUsage.totalTokens))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                if let state = claudeMonitor?.getState(for: session.sessionId),
                   state.costUSD > 0 {
                    Text(String(format: "$%.2f", state.costUSD))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }

            // 라인 4: Git 브랜치 + 경로
            HStack(spacing: 4) {
                if let branch = claudeMonitor?.sessionBranches[session.sessionId] {
                    Text(branch)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.green)
                }
                Text(abbreviatedPath(session.cwd))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            // 해당 워크스페이스로 전환 + 포커싱
            if let ws = matchingWorkspace,
               let idx = workspaceManager.workspaces.firstIndex(where: { $0.id == ws.id }) {
                workspaceManager.switchToWorkspace(at: idx)
                onWorkspaceSwitch?()
            }
        }
    }

    /// 세션 상태에 따른 색상 (세션별 독립)
    private func sessionStatusColor(for session: ClaudeFileSession) -> Color {
        guard let monitor = claudeMonitor,
              let state = monitor.getState(for: session.sessionId) else { return .green }
        switch state.phase {
        case .responding: return .green
        case .toolExecuting: return .blue
        case .waitingForInput: return .yellow
        case .sessionComplete: return .gray
        default: return .green
        }
    }

    /// phase를 표시 텍스트로 변환
    private func phaseText(_ phase: AISessionPhase, toolName: String?) -> String {
        switch phase {
        case .responding: return "Responding..."
        case .toolExecuting:
            if let tool = toolName { return "Tool: \(tool)" }
            return "Executing tool"
        case .toolComplete: return "Tool complete"
        case .waitingForInput: return "⚠ Waiting for input"
        case .sessionActive: return "Active"
        case .sessionComplete: return "Complete"
        case .idle: return "Idle"
        }
    }

    /// 토큰 수를 읽기 쉽게 포맷한다 (예: 12500 -> 12.5k)
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000.0)
        }
        return "\(count)"
    }

    /// 밀리초를 읽기 쉽게 포맷 (12345 → "12.3s", 65432 → "1m 5s")
    private func formatDuration(_ ms: Int) -> String {
        let seconds = Double(ms) / 1000.0
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes)m \(secs)s"
    }

    private func abbreviatedPath(_ path: String) -> String {
        PathAbbreviator.abbreviate(path)
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
    var displayCwd: String? = nil
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
    /// 패널 트리가 펼쳐져 있는지 (활성 워크스페이스에서 트리 표시 여부)
    var isTreeExpanded: Bool = false
    /// 트리 접기/펼치기 토글 (nil이면 토글 불가)
    var onToggleTree: (() -> Void)? = nil

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            // 트리 접기/펼치기 인디케이터 또는 숫자 인덱스
            if isActive {
                Text(isTreeExpanded ? "\u{25BC}" : "\u{25B6}")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .frame(width: 14)
            } else {
                Text("\(index + 1)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 14)
            }

            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Name", text: $editingName, onCommit: onCommitRename)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .focused($isTextFieldFocused)
                        .onExitCommand(perform: onCancelRename)
                        .onAppear { isTextFieldFocused = true }
                } else {
                    HStack(spacing: 4) {
                        Text(workspace.name)
                            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        // 활성 워크스페이스: 경로를 같은 줄에 표시
                        if isActive {
                            Text(abbreviatedPath(displayCwd ?? workspace.cwd))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }

                // 비활성 워크스페이스: 상세 정보를 인라인으로 표시
                if !isActive {
                    // 경로
                    Text(abbreviatedPath(displayCwd ?? workspace.cwd))
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

                    // Claude 세션 수 + 비용 (요약)
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

                    // 리스닝 포트 (요약)
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
        PathAbbreviator.abbreviate(path)
    }

    /// 비용을 포맷한다 ($0.45 형식)
    static func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.3f", cost)
        }
        return String(format: "$%.2f", cost)
    }
}
