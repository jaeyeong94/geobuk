import SwiftUI

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
    @State private var isClaudePanelExpanded = false
    @State private var processMonitor = PaneProcessMonitor()

    var body: some View {
        Group {
            if isInitialized {
                HStack(spacing: 0) {
                    if isSidebarVisible {
                        SidebarView(
                            workspaceManager: workspaceManager,
                            claudeMonitor: claudeMonitor,
                            claudeFileWatcher: claudeFileWatcher,
                            processMonitor: processMonitor,
                            onWorkspaceSwitch: { ensureSurfaceForActiveWorkspace() },
                            onCreateWorkspace: { createNewWorkspace() },
                            onNewClaudeSession: { startNewClaudeSession() }
                        )
                        Divider()
                    }

                    VStack(spacing: 0) {
                        workspaceContentView
                            .id(workspaceManager.activeWorkspace?.id)

                        if claudeMonitor.isMonitoring || claudeMonitor.sessionState.phase != .idle {
                            Divider()
                            ClaudeSessionPanel(
                                monitor: claudeMonitor,
                                isExpanded: $isClaudePanelExpanded,
                                onNewSession: { startNewClaudeSession() }
                            )
                        }
                    }
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
        .frame(minWidth: 600, minHeight: 400)
        .background(Color.black)
        .task {
            await initializeTerminal()
        }
        .onReceive(NotificationCenter.default.publisher(for: .splitHorizontally)) { _ in
            splitFocusedPane(direction: .horizontal)
        }
        .onReceive(NotificationCenter.default.publisher(for: .splitVertically)) { _ in
            splitFocusedPane(direction: .vertical)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleMaximize)) { _ in
            activeManager?.toggleMaximize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusPaneDirection)) { notification in
            if let direction = notification.object as? NavigationDirection {
                activeManager?.focusPane(direction: direction)
                if let id = activeManager?.focusedPaneId { focusSurfaceView(id: id) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .closePane)) { _ in
            closeFocusedPane()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newWorkspace)) { _ in
            createNewWorkspace()
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeWorkspace)) { _ in
            closeActiveWorkspace()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            isSidebarVisible.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchWorkspaceByNumber)) { notification in
            if let number = notification.object as? Int {
                workspaceManager.switchToWorkspace(at: number - 1)
                ensureSurfaceForActiveWorkspace()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newClaudeSession)) { _ in
            startNewClaudeSession()
        }
        .onDisappear {
            autoSaveTimer?.invalidate()
            processMonitor.stopMonitoring()
            claudeMonitor.stopAll()
            claudeFileWatcher.stopWatching()
            SessionPersistence.save(manager: workspaceManager)
            Task { await socketServer?.stop() }
            sessionManager.destroyAllSessions()
            for surfaceView in surfaceViews.values {
                surfaceView.close()
            }
            surfaceViews.removeAll()
            ghosttyApp.destroy()
        }
    }

    // MARK: - Active Workspace Helpers

    private var activeManager: SplitTreeManager? {
        workspaceManager.activeWorkspace?.splitManager
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
                    surfaceViewProvider: { id in surfaceViews[id] }
                )
            } else {
                SplitContainerView(
                    node: splitManager.root,
                    focusedPaneId: splitManager.focusedPaneId,
                    onFocusPane: { id in
                        splitManager.setFocusedPane(id: id)
                        focusSurfaceView(id: id)
                    },
                    surfaceViewProvider: { id in
                        surfaceViews[id]
                    }
                )
            }
        } else {
            Color.black
        }
    }

    // MARK: - Terminal Initialization

    @MainActor
    private func initializeTerminal() async {
        do {
            try ghosttyApp.create()

            // 세션 복원 시도
            if let state = SessionPersistence.restore() {
                restoreFromPersistedState(state)
            }

            // 모든 워크스페이스의 초기 패널에 surface 생성
            for workspace in workspaceManager.workspaces {
                for leaf in workspace.splitManager.root.allLeaves() {
                    if surfaceViews[leaf.id] == nil {
                        let surfaceView = GhosttySurfaceView(app: ghosttyApp)
                        surfaceViews[leaf.id] = surfaceView
                    }
                }
            }

            isInitialized = true

            // 초기 패널에 포커스
            if let focusedId = activeManager?.focusedPaneId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusSurfaceView(id: focusedId)
                }
            }

            // 소켓 서버 시작
            Task { await startSocketServer() }

            // 프로세스 모니터 시작
            processMonitor.startMonitoring()

            // Claude 세션 파일 감시 시작
            claudeFileWatcher.onTranscriptEvent = { sessionId, event in
                claudeMonitor.processTranscriptEvent(event)
            }
            claudeFileWatcher.startWatching()

            // 자동 저장 타이머 시작 (30초마다)
            startAutoSaveTimer()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Session Restore

    @MainActor
    private func restoreFromPersistedState(_ state: PersistedState) {
        guard !state.workspaces.isEmpty else { return }

        var restoredWorkspaces: [Workspace] = []
        for persistedWs in state.workspaces {
            let workspace = Workspace(name: persistedWs.name, cwd: persistedWs.cwd)
            // splitManager의 root를 복원된 레이아웃으로 교체
            let restoredRoot = SessionPersistence.splitNode(from: persistedWs.splitLayout)
            let leaves = restoredRoot.allLeaves()
            let focusedId = leaves.first?.id

            // SplitTreeManager를 복원된 트리로 재생성
            let manager = SplitTreeManager(root: restoredRoot, focusedPaneId: focusedId)
            // workspace의 splitManager는 let이므로 새 workspace를 만들 수 없음
            // 대신 WorkspaceManager를 새로 생성
            // Workspace init에서 splitManager가 생성되므로, 복원용 init 필요

            // 워크스페이스를 복원된 splitManager로 생성
            let restoredWs = Workspace(name: persistedWs.name, cwd: persistedWs.cwd, splitManager: manager)
            restoredWorkspaces.append(restoredWs)
        }

        let activeIndex = min(state.activeIndex, restoredWorkspaces.count - 1)
        workspaceManager = WorkspaceManager(workspaces: restoredWorkspaces, activeIndex: max(0, activeIndex))
    }

    // MARK: - Split Operations

    @MainActor
    private func splitFocusedPane(direction: SplitDirection) {
        guard isInitialized, let splitManager = activeManager else { return }

        splitManager.splitFocusedPane(direction: direction)

        if let newPaneId = splitManager.focusedPaneId,
           surfaceViews[newPaneId] == nil {
            let surfaceView = GhosttySurfaceView(app: ghosttyApp)
            surfaceViews[newPaneId] = surfaceView

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
            SessionPersistence.save(manager: workspaceManager)
            NSApplication.shared.terminate(nil)
            return
        }

        // 패널이 1개이고 워크스페이스가 여러 개면 워크스페이스 닫기
        if splitManager.paneCount <= 1 && workspaceManager.workspaces.count > 1 {
            closeActiveWorkspace()
            return
        }

        if let closingId = splitManager.focusedPaneId {
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

    // MARK: - Workspace Operations

    @MainActor
    private func createNewWorkspace() {
        guard isInitialized else { return }

        // 1. Workspace를 먼저 만들되 아직 active로 전환하지 않음
        let workspace = Workspace(name: workspaceManager.nextWorkspaceName(), cwd: NSHomeDirectory())
        let initialPaneId = workspace.splitManager.focusedPaneId!

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

        isClaudePanelExpanded = true

        // 현재 활성 터미널에 claude 명령어 전송 및 PTY 로그 모니터링 시작
        if let focusedId = activeManager?.focusedPaneId,
           let surfaceView = surfaceViews[focusedId] {
            // PTY 로그 파일을 통한 모니터링 시작
            claudeMonitor.monitor(surfaceViewId: surfaceView.viewId)

            let command = "claude --output-format stream-json"
            surfaceView.sendText(command + "\r")
        }
    }

    // MARK: - Auto Save

    @MainActor
    private func startAutoSaveTimer() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                SessionPersistence.save(manager: workspaceManager)
            }
        }
    }

    // MARK: - Socket Server

    @MainActor
    private func startSocketServer() async {
        let server = SocketServer(sessionManager: sessionManager)
        self.socketServer = server
        do {
            try await server.start()
            AppState.shared.isSocketServerRunning = true
        } catch {
            // 소켓 서버 실패해도 터미널 기능은 정상
        }
    }

    // MARK: - Focus

    @MainActor
    private func focusSurfaceView(id: UUID) {
        guard let surfaceView = surfaceViews[id] else { return }
        surfaceView.window?.makeFirstResponder(surfaceView)
    }
}

#Preview {
    ContentView()
}
