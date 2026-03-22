import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var ghosttyApp = GhosttyApp()
    @State private var workspaceManager = WorkspaceManager()
    @State private var surfaceViews: [UUID: GhosttySurfaceView] = [:]
    @State private var sessionManager = SessionManager()
    @State private var socketServer: SocketServer?
    @State private var errorMessage: String?
    @State private var isInitialized = false
    @State private var isSidebarVisible = true
    @State private var autoSaveTimer: Timer?
    @State private var claudeMonitor = ClaudeSessionMonitor()
    @State private var claudeFileWatcher = ClaudeSessionFileWatcher()
    @State private var isSettingsOpen = false
    @State private var fontSize: Double = 14
    @State private var paddingX: Double = 8
    @State private var paddingY: Double = 4
    @State private var lineHeight: Double = 1.0
    @State private var fontFamily: String = ""
    @State private var processMonitor = PaneProcessMonitor()
    @State private var systemMonitor = SystemMonitor()
    @State private var claudeLaunchSettings = ClaudeLaunchSettings()
    @State private var pricingManager = ClaudePricingManager()
    @State private var shellStateManager = ShellStateManager()
    @State private var notificationCoordinator = NotificationCoordinator()
    @State private var terminalProcessProvider = TerminalProcessProvider()
    @State private var isRightPanelVisible = true
    /// 우측 패널에 전달할 현재 디렉토리 (셸 프롬프트 복귀 시 갱신)
    @State private var focusedDirectory: String?
    /// 사이드바 드래그 리사이즈 너비
    @AppStorage("leftSidebarWidth") private var leftSidebarWidth: Double = 200
    @AppStorage("rightSidebarWidth") private var rightSidebarWidth: Double = 350
    /// 패널 포커스 전환 시 우측 패널 강제 갱신용 카운터
    @State private var rightPanelRefreshTrigger: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            customTitleBar
            mainContent
        }
        .frame(minWidth: 600, minHeight: 400)
        .ignoresSafeArea(.all, edges: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
                await initializeTerminal()
            }
            .modifier(PaneNotificationModifier(
                onSplitHorizontally: { withAnimation(.easeInOut(duration: 0.15)) { splitFocusedPane(direction: .horizontal) } },
                onSplitVertically: { withAnimation(.easeInOut(duration: 0.15)) { splitFocusedPane(direction: .vertical) } },
                onToggleMaximize: { withAnimation(.easeInOut(duration: 0.15)) { activeManager?.toggleMaximize() } },
                onFocusDirection: { notification in
                    if let direction = notification.object as? NavigationDirection {
                        activeManager?.focusPane(direction: direction)
                        if let id = activeManager?.focusedPaneId { focusSurfaceView(id: id, userInitiated: true) }
                    }
                },
                onClosePane: { withAnimation(.easeInOut(duration: 0.15)) { closeFocusedPane() } },
                onChildExited: { notification in
                    if let surfaceView = notification.object as? GhosttySurfaceView {
                        closePane(for: surfaceView)
                    }
                }
            ))
            .modifier(WorkspaceNotificationModifier(
                onNewWorkspace: { createNewWorkspace() },
                onCloseWorkspace: { closeActiveWorkspace() },
                onToggleSidebar: { isSidebarVisible.toggle() },
                onSwitchWorkspace: { notification in
                    if let number = notification.object as? Int {
                        workspaceManager.switchToWorkspace(at: number - 1)
                        ensureSurfaceForActiveWorkspace()
                    }
                },
                onNewClaudeSession: { startNewClaudeSession() },
                onOpenSettings: { isSettingsOpen.toggle() },
                onToggleRightPanel: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRightPanelVisible.toggle()
                    }
                },
                onIncreaseFontSize: { adjustFontSize(delta: 1) },
                onDecreaseFontSize: { adjustFontSize(delta: -1) },
                onSwitchRightPanelTab: { _ in
                    // RightSidebarView의 onReceive에서 isPanelExpanded 바인딩으로 직접 처리
                }
            ))
            .popover(isPresented: $isSettingsOpen, arrowEdge: .trailing) {
                TerminalSettingsView(
                    fontSize: $fontSize,
                    paddingX: $paddingX,
                    paddingY: $paddingY,
                    lineHeight: $lineHeight,
                    fontFamily: $fontFamily,
                    claudeSettings: claudeLaunchSettings,
                    notificationCoordinator: notificationCoordinator,
                    onFontSizeChange: { newSize in
                        setFontSizeForAllSurfaces(newSize)
                    },
                    onConfigChanged: {
                        ghosttyApp.updateSettings(
                            fontSize: fontSize,
                            paddingX: paddingX,
                            paddingY: paddingY,
                            lineHeight: lineHeight,
                            fontFamily: fontFamily
                        )
                    }
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .geobukShellCommandStarted)) { notification in
                if let surfaceId = notification.userInfo?["surfaceId"] as? String {
                    notificationCoordinator.commandStarted(surfaceId: surfaceId)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .geobukShellPromptReady)) { notification in
                updateFocusedDirectory()
                if let surfaceId = notification.userInfo?["surfaceId"] as? String {
                    let command = shellStateManager.shellStates[surfaceId]?.command
                    notificationCoordinator.commandFinished(surfaceId: surfaceId, command: command)
                }
            }
            .onChange(of: claudeMonitor.sessionState.phase) { _, newPhase in
                guard let sessionId = claudeMonitor.sessionState.sessionId else { return }
                let state = claudeMonitor.getState(for: sessionId)
                notificationCoordinator.handleClaudeEvent(
                    phase: newPhase,
                    sessionId: sessionId,
                    toolName: state?.currentToolName,
                    costUSD: state?.costUSD ?? 0
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .geobukPWDChanged)) { notification in
                // PWD 변경 시 포커스된 패널의 디렉토리인지 확인 후 갱신
                if let sv = notification.object as? GhosttySurfaceView,
                   let focusedId = activeManager?.focusedPaneId,
                   surfaceViews[focusedId] === sv {
                    focusedDirectory = sv.currentDirectory
                }
            }
            .onDisappear {
                autoSaveTimer?.invalidate()
                processMonitor.stopMonitoring()
                systemMonitor.stopMonitoring()
                claudeMonitor.stopAll()
                claudeFileWatcher.stopWatching()
                SessionPersistence.save(manager: workspaceManager, surfaceViews: surfaceViews)
                Task { await socketServer?.stop() }
                sessionManager.destroyAllSessions()
                for surfaceView in surfaceViews.values {
                    surfaceView.close()
                }
                surfaceViews.removeAll()
                ghosttyApp.destroy()
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            if isInitialized {
                HStack(spacing: 0) {
                    if isSidebarVisible {
                        SidebarView(
                            workspaceManager: workspaceManager,
                            claudeMonitor: claudeMonitor,
                            claudeFileWatcher: claudeFileWatcher,
                            processMonitor: processMonitor,
                            shellStateManager: shellStateManager,
                            systemMonitor: systemMonitor,
                            notificationCoordinator: notificationCoordinator,
                            surfaceViews: surfaceViews,
                            onWorkspaceSwitch: { ensureSurfaceForActiveWorkspace() },
                            onCreateWorkspace: { createNewWorkspace() },
                            onNewClaudeSession: { startNewClaudeSession() },
                            onClose: { isSidebarVisible = false }
                        )
                        .frame(width: leftSidebarWidth)

                        // 드래그 리사이즈 핸들
                        Rectangle()
                            .fill(Color.gray.opacity(0.01))
                            .frame(width: 4)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        leftSidebarWidth = min(700, max(160, leftSidebarWidth + value.translation.width))
                                    }
                            )
                            .onHover { isHovered in
                                if isHovered { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                            }
                    }

                    workspaceContentView
                        .id(workspaceManager.activeWorkspace?.id)

                    // 드래그 리사이즈 핸들 (패널 열려있을 때만)
                    if isRightPanelVisible {
                        Rectangle()
                            .fill(Color.gray.opacity(0.01))
                            .frame(width: 4)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        rightSidebarWidth = min(700, max(350, rightSidebarWidth - value.translation.width))
                                    }
                            )
                            .onHover { isHovered in
                                if isHovered { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                            }
                    }

                    // 아이콘 바는 항상 표시, 패널 콘텐츠만 토글
                    RightSidebarView(
                            provider: terminalProcessProvider,
                            systemMonitor: systemMonitor,
                            surfaceView: activeManager?.focusedPaneId.flatMap { surfaceViews[$0] },
                            claudeMonitor: claudeMonitor,
                            claudeFileWatcher: claudeFileWatcher,
                            currentDirectory: focusedDirectory,
                            notificationCoordinator: notificationCoordinator,
                            refreshTrigger: rightPanelRefreshTrigger,
                            isPanelExpanded: $isRightPanelVisible,
                            onExecuteCommand: { command in
                                // 현재 포커스된 터미널에 명령어 전송
                                if let focusedId = activeManager?.focusedPaneId,
                                   let sv = surfaceViews[focusedId] {
                                    sv.sendText(command)
                                    sv.sendKeyPress(keyCode: 36, char: "\r")
                                }
                            }
                        )
                        .frame(width: isRightPanelVisible ? rightSidebarWidth : nil)
                }
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("Terminal Error")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Initializing terminal...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Active Workspace Helpers

    private var activeManager: SplitTreeManager? {
        workspaceManager.activeWorkspace?.splitManager
    }



    /// 타이틀바에 표시할 동적 제목
    // MARK: - Custom Title Bar

    /// 트래픽 라이트와 같은 줄에 배치되는 커스텀 타이틀바
    /// hiddenTitleBar + fullSizeContentView에서 트래픽 라이트가 이 영역 위에 오버레이됨
    private var customTitleBar: some View {
        HStack(spacing: 0) {
            // 트래픽 라이트 버튼 영역
            Color.clear
                .frame(width: 72, height: 28)

            // 가운데: 드래그 가능 영역 + 더블클릭 줌
            HStack(spacing: 6) {
                Text("GEOBUK")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.green.opacity(0.8))

                if let ws = workspaceManager.activeWorkspace {
                    Text("·")
                        .foregroundColor(.secondary.opacity(0.3))
                    Text(ws.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.7))
                }

                if (activeManager?.paneCount ?? 1) > 1 {
                    Text("·")
                        .foregroundColor(.secondary.opacity(0.3))
                    Text(verbatim: "\(activeManager?.paneCount ?? 1) panes")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                }

                if claudeFileWatcher.activeSessions.count > 0 {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                }

                Text(dynamicTitle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.4))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(TitleBarDragGesture())
            .onTapGesture(count: 2) {
                NSApp.mainWindow?.zoom(nil)
            }

            // 우측: 빈 공간 (실제 아이콘은 NSTitlebarAccessoryViewController로 배치)
            Spacer()
                .frame(width: 100)
        }
        .frame(height: 28)
    }


    private var dynamicTitle: String {
        guard let workspace = workspaceManager.activeWorkspace else { return "Geobuk" }

        let focusedSurface: GhosttySurfaceView? = {
            guard let id = workspace.splitManager.focusedPaneId else { return nil }
            return surfaceViews[id]
        }()

        // Claude 실행 중인지 확인
        if let surface = focusedSurface, surface.isCommandRunning {
            // Claude 세션 정보가 있으면 표시
            for session in claudeFileWatcher.activeSessions {
                if let state = claudeMonitor.getState(for: session.sessionId),
                   state.phase != .idle {
                    let model = claudeMonitor.sessionModels[session.sessionId] ?? "claude"
                    let phase = phaseTextForTitle(state.phase, toolName: state.currentToolName)
                    var title = "\(model) · \(phase)"
                    if state.costUSD > 0 {
                        title += String(format: " · $%.2f", state.costUSD)
                    }
                    return title
                }
            }
        }

        // 일반 모드: 셸 정보
        let dir = focusedSurface?.currentDirectory.map { PathAbbreviator.abbreviate($0) } ?? "~"
        let paneCount = workspace.splitManager.paneCount

        if paneCount > 1 {
            return "\(workspace.name) · \(paneCount) panes · \(dir)"
        }
        return "zsh \(dir)"
    }

    private func phaseTextForTitle(_ phase: AISessionPhase, toolName: String?) -> String {
        switch phase {
        case .responding: return "Responding..."
        case .toolExecuting:
            if let tool = toolName { return "Tool: \(tool)" }
            return "Executing"
        case .waitingForInput: return "Waiting for input"
        case .sessionComplete: return "Complete"
        default: return "Active"
        }
    }

    // MARK: - Workspace Content View

    @ViewBuilder
    private var workspaceContentView: some View {
        if let workspace = workspaceManager.activeWorkspace {
            let splitManager = workspace.splitManager
            if splitManager.isMaximized, let focusedId = splitManager.focusedPaneId {
                SplitPaneView(
                    content: splitManager.root.allLeaves().first(where: { $0.id == focusedId })
                        ?? splitManager.root.allLeaves()[0],
                    isFocused: true,
                    onTap: {},
                    surfaceViewProvider: { id in surfaceViews[id] },
                    notificationCoordinator: notificationCoordinator
                )
                .transition(.opacity)
            } else {
                SplitContainerView(
                    node: splitManager.root,
                    focusedPaneId: splitManager.focusedPaneId,
                    onFocusPane: { id in
                        splitManager.setFocusedPane(id: id)
                        focusSurfaceView(id: id, userInitiated: true)
                    },
                    surfaceViewProvider: { id in
                        surfaceViews[id]
                    },
                    notificationCoordinator: notificationCoordinator
                )
                .transition(.opacity)
            }
        } else {
            Color.black
        }
    }

    // MARK: - Terminal Initialization

    @MainActor
    private func initializeTerminal() async {
        GeobukLogger.info(.app, "App initializing")
        BlockModeZshSetup.initialize()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        do {
            try ghosttyApp.create()

            // 세션 복원 시도
            if let state = SessionPersistence.restore() {
                GeobukLogger.info(.app, "Restoring session", context: ["workspaces": "\(state.workspaces.count)"])
                restoreFromPersistedState(state)
            }

            // 모든 워크스페이스의 초기 패널에 surface 생성
            for workspace in workspaceManager.workspaces {
                for leaf in workspace.splitManager.root.allLeaves() {
                    if surfaceViews[leaf.id] == nil {
                        // 복원된 CWD가 있으면 해당 디렉토리에서 셸 시작
                        let cwd = restoredCwdMap[leaf.id]
                        let surfaceView = GhosttySurfaceView(app: ghosttyApp, cwd: cwd)
                        surfaceViews[leaf.id] = surfaceView
                    }
                }
            }
            restoredCwdMap.removeAll()

            isInitialized = true
            GeobukLogger.info(.app, "App initialized", context: ["workspaces": "\(workspaceManager.workspaces.count)"])

            // 초기 패널에 포커스
            if let focusedId = activeManager?.focusedPaneId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusSurfaceView(id: focusedId)
                }
                // 셸 초기화 후 디렉토리 갱신 (OSC 7 응답 대기)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    updateFocusedDirectory()
                }
            }

            // 소켓 서버 시작
            Task { await startSocketServer() }

            // 프로세스 모니터 시작
            processMonitor.startMonitoring()

            // 시스템 모니터 시작
            systemMonitor.startMonitoring()

            // 셸 포트 폴링 시작
            shellStateManager.startPortPolling()

            // 터미널 프로세스 모니터 시작
            terminalProcessProvider.startMonitoring()

            // Claude 가격 fetch + 모니터/설정 연결
            claudeMonitor.pricingManager = pricingManager
            claudeLaunchSettings.pricingManager = pricingManager
            Task { await pricingManager.fetchPricing() }

            // Claude 세션 파일 감시 시작
            claudeFileWatcher.onTranscriptEvent = { sessionId, event in
                claudeMonitor.processTranscriptEvent(event, sessionId: sessionId)
            }
            claudeFileWatcher.onSessionEnded = { sessionId in
                claudeMonitor.removeSession(sessionId)
            }
            GeobukLogger.info(.claude, "Claude file watcher starting")
            claudeFileWatcher.startWatching()

            // 자동 저장 타이머 시작 (30초마다)
            startAutoSaveTimer()
        } catch {
            GeobukLogger.error(.app, "App initialization failed", error: error)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Session Restore

    /// 패널별 CWD 매핑 (복원 시 surface 생성에 사용)
    @State private var restoredCwdMap: [UUID: String] = [:]

    @MainActor
    private func restoreFromPersistedState(_ state: PersistedState) {
        guard !state.workspaces.isEmpty else { return }

        var restoredWorkspaces: [Workspace] = []
        for persistedWs in state.workspaces {
            var cwdMap: [UUID: String] = [:]
            let restoredRoot = SessionPersistence.splitNode(from: persistedWs.splitLayout, cwdMap: &cwdMap)
            let leaves = restoredRoot.allLeaves()
            let focusedId = leaves.first?.id

            let manager = SplitTreeManager(root: restoredRoot, focusedPaneId: focusedId)
            let restoredWs = Workspace(name: persistedWs.name, cwd: persistedWs.cwd, splitManager: manager)
            restoredWorkspaces.append(restoredWs)

            // 패널별 CWD 저장 (surface 생성 시 사용)
            restoredCwdMap.merge(cwdMap) { _, new in new }
        }

        let activeIndex = min(state.activeIndex, restoredWorkspaces.count - 1)
        workspaceManager = WorkspaceManager(workspaces: restoredWorkspaces, activeIndex: max(0, activeIndex))
    }

    // MARK: - Split Operations

    @MainActor
    private func splitFocusedPane(direction: SplitDirection) {
        guard isInitialized, let splitManager = activeManager else { return }

        // 분할 전 현재 포커스된 패널의 surfaceView를 캡처 (설정 상속용)
        let existingSurfaceView: GhosttySurfaceView? = {
            guard let focusedId = splitManager.focusedPaneId else { return nil }
            return surfaceViews[focusedId]
        }()

        splitManager.splitFocusedPane(direction: direction)

        if let newPaneId = splitManager.focusedPaneId,
           surfaceViews[newPaneId] == nil {
            // 기존 surface가 있으면 설정 상속, 없으면 기본 생성
            let surfaceView: GhosttySurfaceView
            if let existing = existingSurfaceView {
                surfaceView = GhosttySurfaceView(app: ghosttyApp, inheritFrom: existing)
            } else {
                surfaceView = GhosttySurfaceView(app: ghosttyApp)
            }
            surfaceViews[newPaneId] = surfaceView
            GeobukLogger.info(.workspace, "Pane split", context: ["direction": "\(direction)", "paneId": newPaneId.uuidString])

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusSurfaceView(id: newPaneId)
            }
        }
    }

    // MARK: - Close Operations

    @MainActor
    private func closeFocusedPane() {
        guard isInitialized, let splitManager = activeManager else { return }

        // 패널이 1개이고 워크스페이스도 1개면 앱 종료
        if splitManager.paneCount <= 1 && workspaceManager.workspaces.count <= 1 {
            SessionPersistence.save(manager: workspaceManager, surfaceViews: surfaceViews)
            NSApplication.shared.terminate(nil)
            return
        }

        // 패널이 1개이고 워크스페이스가 여러 개면 워크스페이스 닫기
        if splitManager.paneCount <= 1 && workspaceManager.workspaces.count > 1 {
            closeActiveWorkspace()
            return
        }

        if let closingId = splitManager.focusedPaneId {
            GeobukLogger.info(.workspace, "Pane closing", context: ["paneId": closingId.uuidString])
            splitManager.closeFocusedPane()

            if let surfaceView = surfaceViews.removeValue(forKey: closingId) {
                claudeMonitor.stopMonitoring(surfaceViewId: surfaceView.viewId)
                surfaceView.close()
            }

            if let newFocusId = splitManager.focusedPaneId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusSurfaceView(id: newFocusId)
                }
            }
        }
    }

    // MARK: - Auto-close Pane (child exited)

    /// surfaceView에 해당하는 패널을 자동으로 닫는다 (자식 프로세스 종료 시)
    @MainActor
    private func closePane(for surfaceView: GhosttySurfaceView) {
        // surfaceView의 viewId가 아닌, surfaceViews 딕셔너리의 key(paneId)를 찾아야 함
        guard let paneId = surfaceViews.first(where: { $0.value === surfaceView })?.key else { return }
        guard let splitManager = activeManager else { return }

        // 패널이 1개이고 워크스페이스도 1개면 앱 종료
        if splitManager.paneCount <= 1 && workspaceManager.workspaces.count <= 1 {
            SessionPersistence.save(manager: workspaceManager, surfaceViews: surfaceViews)
            NSApplication.shared.terminate(nil)
            return
        }

        // 패널이 1개이고 워크스페이스가 여러 개면 워크스페이스 닫기
        if splitManager.paneCount <= 1 && workspaceManager.workspaces.count > 1 {
            closeActiveWorkspace()
            return
        }

        GeobukLogger.info(.workspace, "Pane auto-closing (child exited)", context: ["paneId": paneId.uuidString])

        // 해당 패널에 포커스를 맞추고 닫기
        splitManager.setFocusedPane(id: paneId)
        splitManager.closeFocusedPane()

        if let removed = surfaceViews.removeValue(forKey: paneId) {
            claudeMonitor.stopMonitoring(surfaceViewId: removed.viewId)
            removed.close()
        }

        if let newFocusId = splitManager.focusedPaneId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusSurfaceView(id: newFocusId)
            }
        }
    }

    // MARK: - Workspace Operations

    @MainActor
    private func createNewWorkspace() {
        guard isInitialized else { return }

        // 1. Workspace를 먼저 만들되 아직 active로 전환하지 않음
        let workspace = Workspace(name: workspaceManager.nextWorkspaceName(), cwd: NSHomeDirectory())
        guard let initialPaneId = workspace.splitManager.focusedPaneId else { return }
        GeobukLogger.info(.workspace, "Workspace creating", context: ["name": workspace.name])

        // 2. Surface를 먼저 생성 (SwiftUI re-render 전에 준비)
        let surfaceView = GhosttySurfaceView(app: ghosttyApp)
        surfaceViews[initialPaneId] = surfaceView

        // 3. 이제 workspace를 추가하고 활성화 → re-render 시 surface가 이미 준비됨
        workspaceManager.addAndActivate(workspace)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusSurfaceView(id: initialPaneId)
        }
    }

    @MainActor
    private func closeActiveWorkspace() {
        guard isInitialized else { return }
        let index = workspaceManager.activeIndex

        // 닫을 워크스페이스의 모든 surface 정리
        if let workspace = workspaceManager.activeWorkspace {
            GeobukLogger.info(.workspace, "Workspace closing", context: ["name": workspace.name, "index": "\(index)"])
            for leaf in workspace.splitManager.root.allLeaves() {
                if let surfaceView = surfaceViews.removeValue(forKey: leaf.id) {
                    claudeMonitor.stopMonitoring(surfaceViewId: surfaceView.viewId)
                    surfaceView.close()
                }
            }
        }

        workspaceManager.closeWorkspace(at: index)
        ensureSurfaceForActiveWorkspace()
    }

    /// 활성 워크스페이스의 surface가 존재하는지 확인하고 포커스 설정
    @MainActor
    private func ensureSurfaceForActiveWorkspace() {
        guard let workspace = workspaceManager.activeWorkspace else { return }
        for leaf in workspace.splitManager.root.allLeaves() {
            if surfaceViews[leaf.id] == nil {
                let surfaceView = GhosttySurfaceView(app: ghosttyApp)
                surfaceViews[leaf.id] = surfaceView
            }
        }
        if let focusedId = workspace.splitManager.focusedPaneId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusSurfaceView(id: focusedId)
            }
        }
    }

    // MARK: - Claude Session

    @MainActor
    private func startNewClaudeSession() {
        guard isInitialized else { return }

        // 현재 활성 터미널에 claude 명령어 전송
        guard let focusedId = activeManager?.focusedPaneId,
              let surfaceView = surfaceViews[focusedId] else { return }

        // PTY 로그 파일을 통한 모니터링 시작
        claudeMonitor.monitor(surfaceViewId: surfaceView.viewId)

        let command = claudeLaunchSettings.buildCommand()

        // 명령만 전송 — 모드 전환은 소켓 알림 기반으로 자동 처리
        // (preexec → 2초 후 TUI 전환, precmd → 블록 복귀)
        surfaceView.sendText(command)
        surfaceView.sendKeyPress(keyCode: 36, char: "\r")
    }

    // MARK: - Auto Save

    @MainActor
    private func startAutoSaveTimer() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                SessionPersistence.save(manager: workspaceManager, surfaceViews: surfaceViews)
            }
        }
    }

    // MARK: - Socket Server

    @MainActor
    private func startSocketServer() async {
        let server = SocketServer(sessionManager: sessionManager, shellStateManager: shellStateManager)
        self.socketServer = server
        do {
            try await server.start()
            AppState.shared.isSocketServerRunning = true
            GeobukLogger.info(.socket, "Socket server started", context: ["path": SocketServer.defaultSocketPath])
        } catch {
            GeobukLogger.error(.socket, "Socket server failed to start", error: error)
            // 소켓 서버 실패해도 터미널 기능은 정상
        }
    }

    // MARK: - Focus

    @MainActor
    /// userInitiated: true = 사용자 클릭/키보드로 포커스 전환 (알림 읽음 처리)
    ///                false = 시스템 자동 포커스 (명령 완료 후 블록 복귀 등, 알림 유지)
    private func focusSurfaceView(id: UUID, userInitiated: Bool = false) {
        guard let surfaceView = surfaceViews[id] else { return }
        if surfaceView.isCommandRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                surfaceView.window?.makeFirstResponder(surfaceView)
            }
        }
        updateFocusedDirectory()

        // 사용자가 직접 포커스한 경우에만 알림 읽음 처리
        if userInitiated {
            notificationCoordinator.markAllAsRead(source: surfaceView.viewId.uuidString)
        }
    }

    /// 현재 포커스된 패널의 디렉토리를 우측 패널용으로 갱신
    @MainActor
    private func updateFocusedDirectory() {
        focusedDirectory = activeManager?.focusedPaneId.flatMap { surfaceViews[$0]?.currentDirectory }
        rightPanelRefreshTrigger += 1
    }

    /// Cmd+/Cmd- 로 폰트 크기 1pt 증감
    @MainActor
    private func adjustFontSize(delta: Double) {
        fontSize = max(8, min(32, fontSize + delta))
        setFontSizeForAllSurfaces(fontSize)
    }

    /// 모든 surface의 폰트 크기를 binding action으로 변경
    @MainActor
    private func setFontSizeForAllSurfaces(_ targetSize: Double) {
        // reset 후 target까지 증가/감소
        for surfaceView in surfaceViews.values {
            surfaceView.executeAction("reset_font_size")
        }
        // Ghostty 기본 폰트 크기로 reset 후, 차이만큼 increase/decrease
        let defaultSize: Double = 13 // Ghostty 기본값
        let diff = targetSize - defaultSize
        if diff > 0 {
            for surfaceView in surfaceViews.values {
                surfaceView.executeAction("increase_font_size:\(diff)")
            }
        } else if diff < 0 {
            for surfaceView in surfaceViews.values {
                surfaceView.executeAction("decrease_font_size:\(abs(diff))")
            }
        }
    }
}

// MARK: - Notification ViewModifiers (타입 체커 부하 분산)

/// 패널 관련 알림을 처리하는 ViewModifier
private struct PaneNotificationModifier: ViewModifier {
    let onSplitHorizontally: () -> Void
    let onSplitVertically: () -> Void
    let onToggleMaximize: () -> Void
    let onFocusDirection: (Notification) -> Void
    let onClosePane: () -> Void
    let onChildExited: (Notification) -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .splitHorizontally)) { _ in
                onSplitHorizontally()
            }
            .onReceive(NotificationCenter.default.publisher(for: .splitVertically)) { _ in
                onSplitVertically()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleMaximize)) { _ in
                onToggleMaximize()
            }
            .onReceive(NotificationCenter.default.publisher(for: .focusPaneDirection)) { notification in
                onFocusDirection(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .closePane)) { _ in
                onClosePane()
            }
            .onReceive(NotificationCenter.default.publisher(for: .ghosttySurfaceChildExited)) { notification in
                onChildExited(notification)
            }
    }
}

/// 워크스페이스 관련 알림을 처리하는 ViewModifier
private struct WorkspaceNotificationModifier: ViewModifier {
    let onNewWorkspace: () -> Void
    let onCloseWorkspace: () -> Void
    let onToggleSidebar: () -> Void
    let onSwitchWorkspace: (Notification) -> Void
    let onNewClaudeSession: () -> Void
    let onOpenSettings: () -> Void
    let onToggleRightPanel: () -> Void
    let onIncreaseFontSize: () -> Void
    let onDecreaseFontSize: () -> Void
    let onSwitchRightPanelTab: (Notification) -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .newWorkspace)) { _ in
                onNewWorkspace()
            }
            .onReceive(NotificationCenter.default.publisher(for: .closeWorkspace)) { _ in
                onCloseWorkspace()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
                onToggleSidebar()
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchWorkspaceByNumber)) { notification in
                onSwitchWorkspace(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .newClaudeSession)) { _ in
                onNewClaudeSession()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                onOpenSettings()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleRightPanel)) { _ in
                onToggleRightPanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .increaseFontSize)) { _ in
                onIncreaseFontSize()
            }
            .onReceive(NotificationCenter.default.publisher(for: .decreaseFontSize)) { _ in
                onDecreaseFontSize()
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchRightPanelTab)) { notification in
                onSwitchRightPanelTab(notification)
            }
    }
}

#Preview {
    ContentView()
}
