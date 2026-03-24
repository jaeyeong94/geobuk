import SwiftUI
import UserNotifications

/// ContentView에서 추출한 앱 코디네이터
/// 모든 매니저, surfaceView 관리, 패널/워크스페이스 조작 로직을 담당한다.
@MainActor @Observable
final class AppCoordinator {

    // MARK: - Managers

    private(set) var ghosttyApp: GhosttyApp
    var workspaceManager: WorkspaceManager
    var surfaceViews: [UUID: GhosttySurfaceView] = [:]
    let sessionManager: SessionManager
    var socketServer: SocketServer?
    let shellStateManager: ShellStateManager
    let claudeMonitor: ClaudeSessionMonitor
    let claudeFileWatcher: ClaudeSessionFileWatcher
    let pricingManager: ClaudePricingManager
    let processMonitor: PaneProcessMonitor
    let systemMonitor: SystemMonitor
    let terminalProcessProvider: TerminalProcessProvider
    let notificationCoordinator: NotificationCoordinator
    let claudeLaunchSettings: ClaudeLaunchSettings

    // MARK: - State

    var isInitialized = false
    var errorMessage: String?
    var autoSaveTask: Task<Void, Never>?
    var focusedDirectory: String?

    /// 패널별 CWD 매핑 (복원 시 surface 생성에 사용)
    private var restoredCwdMap: [UUID: String] = [:]

    /// 테스트용 종료 핸들러. nil이면 NSApplication.shared.terminate(nil) 호출.
    var terminateHandler: (() -> Void)?

    // MARK: - Init

    init(
        ghosttyApp: GhosttyApp = GhosttyApp(),
        workspaceManager: WorkspaceManager = WorkspaceManager(),
        sessionManager: SessionManager = SessionManager(),
        claudeMonitor: ClaudeSessionMonitor = ClaudeSessionMonitor(),
        claudeFileWatcher: ClaudeSessionFileWatcher = ClaudeSessionFileWatcher(),
        pricingManager: ClaudePricingManager = ClaudePricingManager(),
        processMonitor: PaneProcessMonitor = PaneProcessMonitor(),
        systemMonitor: SystemMonitor = SystemMonitor(),
        shellStateManager: ShellStateManager = ShellStateManager(),
        notificationCoordinator: NotificationCoordinator = NotificationCoordinator(),
        terminalProcessProvider: TerminalProcessProvider = TerminalProcessProvider(),
        claudeLaunchSettings: ClaudeLaunchSettings = ClaudeLaunchSettings()
    ) {
        self.ghosttyApp = ghosttyApp
        self.workspaceManager = workspaceManager
        self.sessionManager = sessionManager
        self.claudeMonitor = claudeMonitor
        self.claudeFileWatcher = claudeFileWatcher
        self.pricingManager = pricingManager
        self.processMonitor = processMonitor
        self.systemMonitor = systemMonitor
        self.shellStateManager = shellStateManager
        self.notificationCoordinator = notificationCoordinator
        self.terminalProcessProvider = terminalProcessProvider
        self.claudeLaunchSettings = claudeLaunchSettings
    }

    // MARK: - Active Workspace Helpers

    var activeManager: SplitTreeManager? {
        workspaceManager.activeWorkspace?.splitManager
    }

    // MARK: - Initialization

    func initialize() async {
        GeobukLogger.info(.app, "App initializing")
        BlockModeZshSetup.initialize()
        AppPath.installShims()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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
                        let cwd = restoredCwdMap[leaf.id]
                        let surfaceView = GhosttySurfaceView(app: ghosttyApp, cwd: cwd)
                        surfaceViews[leaf.id] = surfaceView
                    }
                }
            }
            restoredCwdMap.removeAll()

            isInitialized = true
            GeobukLogger.info(.app, "App initialized", context: ["workspaces": "\(workspaceManager.workspaces.count)"])

            registerPaneController()

            // 초기 패널에 포커스
            if let focusedId = activeManager?.focusedPaneId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.focusSurfaceView(id: focusedId)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.updateFocusedDirectory()
                }
            }

            Task { await startSocketServer() }

            processMonitor.startMonitoring()
            systemMonitor.startMonitoring()
            shellStateManager.startPortPolling()
            terminalProcessProvider.startMonitoring()

            claudeMonitor.pricingManager = pricingManager
            claudeLaunchSettings.pricingManager = pricingManager
            Task { await pricingManager.fetchPricing() }

            claudeFileWatcher.onTranscriptEvent = { [weak self] sessionId, event in
                self?.claudeMonitor.processTranscriptEvent(event, sessionId: sessionId)
            }
            claudeFileWatcher.onSessionEnded = { [weak self] sessionId in
                self?.claudeMonitor.removeSession(sessionId)
            }
            GeobukLogger.info(.claude, "Claude file watcher starting")
            claudeFileWatcher.startWatching()

            startAutoSaveTimer()
        } catch {
            GeobukLogger.error(.app, "App initialization failed", error: error)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Session Restore

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

            restoredCwdMap.merge(cwdMap) { _, new in new }
        }

        let activeIndex = min(state.activeIndex, restoredWorkspaces.count - 1)
        workspaceManager = WorkspaceManager(workspaces: restoredWorkspaces, activeIndex: max(0, activeIndex))
    }

    // MARK: - Socket Server

    private func startSocketServer() async {
        let server = SocketServer(sessionManager: sessionManager, shellStateManager: shellStateManager)
        self.socketServer = server
        do {
            try await server.start()
            AppState.shared.markSocketServerRunning(true)
            GeobukLogger.info(.socket, "Socket server started", context: ["path": SocketServer.defaultSocketPath])
        } catch {
            GeobukLogger.error(.socket, "Socket server failed to start", error: error)
        }
    }

    // MARK: - Auto Save

    func startAutoSaveTimer() {
        autoSaveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                guard let self else { break }
                SessionPersistence.save(manager: self.workspaceManager, surfaceViews: self.surfaceViews)
            }
        }
    }

    // MARK: - Focus Directory

    func updateFocusedDirectory() {
        focusedDirectory = activeManager?.focusedPaneId.flatMap { surfaceViews[$0]?.currentDirectory }
    }

    // MARK: - Split Operations

    func splitFocusedPane(direction: SplitDirection, startInTUIMode: Bool = false) {
        guard isInitialized, let splitManager = activeManager else { return }

        let existingSurfaceView: GhosttySurfaceView? = {
            guard let focusedId = splitManager.focusedPaneId else { return nil }
            return surfaceViews[focusedId]
        }()

        splitManager.splitFocusedPane(direction: direction)

        if let newPaneId = splitManager.focusedPaneId,
           surfaceViews[newPaneId] == nil {
            let surfaceView: GhosttySurfaceView
            if startInTUIMode {
                surfaceView = GhosttySurfaceView(app: ghosttyApp, skipBlockMode: true)
            } else if let existing = existingSurfaceView {
                surfaceView = GhosttySurfaceView(app: ghosttyApp, inheritFrom: existing)
            } else {
                surfaceView = GhosttySurfaceView(app: ghosttyApp)
            }

            if startInTUIMode {
                surfaceView.apiCreatedPane = true
                surfaceView.blockInputMode = false
                surfaceView.isCommandRunning = true
                GeobukLogger.info(.app, "API pane TUI mode set", context: ["surfaceId": surfaceView.viewId.uuidString, "apiCreated": "\(surfaceView.apiCreatedPane)"])
            }

            surfaceViews[newPaneId] = surfaceView
            GeobukLogger.info(.workspace, "Pane split", context: ["direction": "\(direction)", "paneId": newPaneId.uuidString, "startInTUI": "\(startInTUIMode)"])
        }
    }

    // MARK: - Close Operations

    func closeFocusedPane() {
        guard isInitialized, let focusedId = activeManager?.focusedPaneId else { return }
        closePane(id: focusedId)
    }

    func closePane(for surfaceView: GhosttySurfaceView) {
        guard let paneId = surfaceViews.first(where: { $0.value === surfaceView })?.key else { return }
        closePane(id: paneId)
    }

    func closePane(id paneId: UUID) {
        guard let splitManager = activeManager else { return }

        // 패널이 1개이고 워크스페이스도 1개면 앱 종료
        if splitManager.paneCount <= 1 && workspaceManager.workspaces.count <= 1 {
            SessionPersistence.save(manager: workspaceManager, surfaceViews: surfaceViews)
            if let handler = terminateHandler {
                handler()
            } else {
                NSApplication.shared.terminate(nil)
            }
            return
        }

        // 패널이 1개이고 워크스페이스가 여러 개면 워크스페이스 닫기
        if splitManager.paneCount <= 1 && workspaceManager.workspaces.count > 1 {
            closeActiveWorkspace()
            return
        }

        GeobukLogger.info(.workspace, "Pane closing", context: ["paneId": paneId.uuidString])

        splitManager.setFocusedPane(id: paneId)
        splitManager.closeFocusedPane()

        if let removed = surfaceViews.removeValue(forKey: paneId) {
            let sid = removed.viewId.uuidString
            claudeMonitor.stopMonitoring(surfaceViewId: removed.viewId)
            TeamPaneTracker.shared.remove(surfaceId: sid)
            TeamPaneTracker.shared.removeAllForLeader(surfaceId: sid)
            removed.close()
        }
    }

    // MARK: - Workspace Operations

    func createNewWorkspace() {
        guard isInitialized else { return }

        let workspace = Workspace(name: workspaceManager.nextWorkspaceName(), cwd: NSHomeDirectory())
        guard let initialPaneId = workspace.splitManager.focusedPaneId else { return }
        GeobukLogger.info(.workspace, "Workspace creating", context: ["name": workspace.name])

        let surfaceView = GhosttySurfaceView(app: ghosttyApp)
        surfaceViews[initialPaneId] = surfaceView

        workspaceManager.addAndActivate(workspace)
    }

    func closeActiveWorkspace() {
        guard isInitialized else { return }
        let index = workspaceManager.activeIndex

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

    func ensureSurfaceForActiveWorkspace() {
        guard let workspace = workspaceManager.activeWorkspace else { return }
        for leaf in workspace.splitManager.root.allLeaves() {
            if surfaceViews[leaf.id] == nil {
                let surfaceView = GhosttySurfaceView(app: ghosttyApp)
                surfaceViews[leaf.id] = surfaceView
            }
        }
    }

    // MARK: - Focus

    func focusSurfaceView(id: UUID, userInitiated: Bool = false) {
        guard let surfaceView = surfaceViews[id] else { return }
        if surfaceView.isCommandRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                surfaceView.window?.makeFirstResponder(surfaceView)
            }
        }
        updateFocusedDirectory()

        if userInitiated {
            let sid = surfaceView.viewId.uuidString
            notificationCoordinator.markAllAsRead(source: sid)
            NotificationCenter.default.post(name: .geobukDismissRing, object: sid)
        }
    }

    // MARK: - Claude Session

    func startNewClaudeSession() {
        guard isInitialized else { return }
        guard let focusedId = activeManager?.focusedPaneId,
              let surfaceView = surfaceViews[focusedId] else { return }

        claudeMonitor.monitor(surfaceViewId: surfaceView.viewId)
        let command = claudeLaunchSettings.buildCommand()
        surfaceView.sendText(command)
        surfaceView.sendKeyPress(keyCode: 36, char: "\r")
    }

    // MARK: - PaneController (Claude Code Team 통합)

    func registerPaneController() {
        let controller = PaneController.shared

        controller.onSplitPane = { [weak self] sourcePaneId, direction in
            guard let self else { return nil }
            let surfaceView = GhosttySurfaceView(app: self.ghosttyApp, skipBlockMode: true)
            surfaceView.apiCreatedPane = true
            surfaceView.blockInputMode = false
            surfaceView.isCommandRunning = true

            let newSurfaceId = surfaceView.viewId.uuidString
            TeamPaneTracker.shared.teamSurfaceViews[newSurfaceId] = surfaceView

            GeobukLogger.info(.app, "Team pane created", context: ["source": sourcePaneId, "new": newSurfaceId])
            return newSurfaceId
        }

        controller.onSendKeys = { [weak self] surfaceId, text in
            guard let self else { return false }
            for (_, sv) in self.surfaceViews where sv.viewId.uuidString == surfaceId {
                sv.sendText(text)
                sv.sendKeyPress(keyCode: 36, char: "\r")
                return true
            }
            if let sv = TeamPaneTracker.shared.teamSurfaceViews[surfaceId] {
                sv.sendText(text)
                sv.sendKeyPress(keyCode: 36, char: "\r")
                return true
            }
            return false
        }

        controller.onKillPane = { [weak self] surfaceId in
            guard let self else { return false }
            if let paneEntry = self.surfaceViews.first(where: { $0.value.viewId.uuidString == surfaceId }) {
                self.closePane(id: paneEntry.key)
                return true
            }
            if TeamPaneTracker.shared.teamSurfaceViews[surfaceId] != nil {
                TeamPaneTracker.shared.remove(surfaceId: surfaceId)
                return true
            }
            return false
        }
    }

    // MARK: - Font

    func adjustFontSize(delta: Double, currentFontSize: inout Double) {
        currentFontSize = max(8, min(32, currentFontSize + delta))
        setFontSizeForAllSurfaces(currentFontSize)
    }

    func setFontSizeForAllSurfaces(_ targetSize: Double) {
        for surfaceView in surfaceViews.values {
            surfaceView.executeAction("reset_font_size")
        }
        let defaultSize: Double = 13
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

    // MARK: - Cleanup

    func cleanup() {
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
