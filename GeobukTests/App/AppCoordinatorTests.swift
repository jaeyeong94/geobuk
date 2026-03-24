import Testing
import AppKit
@testable import Geobuk

@Suite("AppCoordinator - ContentView 로직 추출")
@MainActor
struct AppCoordinatorTests {

    // MARK: - 초기화

    @Test("init_매니저초기화_모두nil아님")
    func init_managersInitialized_allNonNil() {
        let coordinator = AppCoordinator()

        #expect(coordinator.workspaceManager.workspaces.isEmpty == false)
        // @Observable class 타입은 항상 non-nil (let 프로퍼티)
        #expect(coordinator.sessionManager !== nil as AnyObject?)
        #expect(coordinator.claudeMonitor !== nil as AnyObject?)
        #expect(coordinator.claudeFileWatcher !== nil as AnyObject?)
        #expect(coordinator.processMonitor !== nil as AnyObject?)
        #expect(coordinator.systemMonitor !== nil as AnyObject?)
        #expect(coordinator.pricingManager !== nil as AnyObject?)
        #expect(coordinator.shellStateManager !== nil as AnyObject?)
        #expect(coordinator.notificationCoordinator !== nil as AnyObject?)
        #expect(coordinator.terminalProcessProvider !== nil as AnyObject?)
        #expect(coordinator.claudeLaunchSettings !== nil as AnyObject?)
    }

    @Test("init_surfaceViews_빈딕셔너리")
    func init_surfaceViews_emptyDictionary() {
        let coordinator = AppCoordinator()
        #expect(coordinator.surfaceViews.isEmpty)
    }

    @Test("init_isInitialized_false")
    func init_isInitialized_false() {
        let coordinator = AppCoordinator()
        #expect(coordinator.isInitialized == false)
    }

    @Test("init_activeManager_notNil")
    func init_activeManager_notNil() {
        let coordinator = AppCoordinator()
        #expect(coordinator.activeManager != nil)
    }

    @Test("init_워크스페이스_기본1개")
    func init_workspace_defaultOne() {
        let coordinator = AppCoordinator()
        #expect(coordinator.workspaceManager.workspaces.count == 1)
    }

    @Test("init_커스텀워크스페이스_주입가능")
    func init_customWorkspace_injectable() {
        let ws1 = Workspace(name: "Test1", cwd: "/tmp")
        let ws2 = Workspace(name: "Test2", cwd: "/tmp")
        let wm = WorkspaceManager(workspaces: [ws1, ws2], activeIndex: 1)
        let coordinator = AppCoordinator(workspaceManager: wm)

        #expect(coordinator.workspaceManager.workspaces.count == 2)
        #expect(coordinator.workspaceManager.activeWorkspace?.name == "Test2")
    }

    // MARK: - splitFocusedPane (로직 테스트 - GhosttyApp 불필요)

    @Test("splitPane_미초기화시_무시")
    func splitPane_notInitialized_ignored() {
        let coordinator = AppCoordinator()
        coordinator.splitFocusedPane(direction: .horizontal)

        // isInitialized == false이므로 surfaceViews가 비어있어야 함
        #expect(coordinator.surfaceViews.isEmpty)
    }

    @Test("splitPane_activeManagerNil_크래시없음")
    func splitPane_noActiveManager_noCrash() {
        let emptyManager = WorkspaceManager(workspaces: [], activeIndex: 0)
        let coordinator = AppCoordinator(workspaceManager: emptyManager)
        coordinator.isInitialized = true

        // activeManager가 nil이어도 크래시하면 안 됨
        coordinator.splitFocusedPane(direction: .horizontal)
        #expect(coordinator.surfaceViews.isEmpty)
    }

    // MARK: - closePane (로직 테스트)

    @Test("closeFocusedPane_미초기화_무시")
    func closeFocusedPane_notInitialized_ignored() {
        let coordinator = AppCoordinator()
        // isInitialized == false
        coordinator.closeFocusedPane()
        // 크래시 없이 통과하면 성공
    }

    @Test("closePane_activeManagerNil_크래시없음")
    func closePane_noActiveManager_noCrash() {
        let emptyManager = WorkspaceManager(workspaces: [], activeIndex: 0)
        let coordinator = AppCoordinator(workspaceManager: emptyManager)
        coordinator.isInitialized = true

        coordinator.closePane(id: UUID())
        // 크래시 없이 통과하면 성공
    }

    // MARK: - 워크스페이스 (로직 테스트)

    @Test("createNewWorkspace_미초기화_무시")
    func createNewWorkspace_notInitialized_ignored() {
        let coordinator = AppCoordinator()
        let countBefore = coordinator.workspaceManager.workspaces.count
        coordinator.createNewWorkspace()

        #expect(coordinator.workspaceManager.workspaces.count == countBefore)
    }

    @Test("closeActiveWorkspace_미초기화_무시")
    func closeActiveWorkspace_notInitialized_ignored() {
        let coordinator = AppCoordinator()
        let countBefore = coordinator.workspaceManager.workspaces.count
        coordinator.closeActiveWorkspace()

        #expect(coordinator.workspaceManager.workspaces.count == countBefore)
    }

    // MARK: - focusSurfaceView (로직 테스트)

    @Test("focusSurfaceView_존재하지않는ID_크래시없음")
    func focusSurfaceView_nonExistentId_noCrash() {
        let coordinator = AppCoordinator()
        coordinator.focusSurfaceView(id: UUID())
        // 크래시 없이 통과하면 성공
    }

    @Test("focusSurfaceView_userInitiated_알림읽음처리")
    func focusSurfaceView_userInitiated_marksAsRead() {
        // focusSurfaceView는 surfaceViews에 해당 ID가 없으면 early return
        // 실제 동작 확인은 통합 테스트에서
        let coordinator = AppCoordinator()
        coordinator.focusSurfaceView(id: UUID(), userInitiated: true)
        // 크래시 없이 통과
    }

    // MARK: - startNewClaudeSession (로직 테스트)

    @Test("startNewClaudeSession_미초기화_무시")
    func startNewClaudeSession_notInitialized_ignored() {
        let coordinator = AppCoordinator()
        coordinator.startNewClaudeSession()
        // 크래시 없이 통과
    }

    @Test("startNewClaudeSession_surfaceView없음_무시")
    func startNewClaudeSession_noSurfaceView_ignored() {
        let coordinator = AppCoordinator()
        coordinator.isInitialized = true
        coordinator.startNewClaudeSession()
        // surfaceViews 비어있으므로 early return
    }

    // MARK: - terminateHandler

    @Test("terminateHandler_기본nil")
    func terminateHandler_defaultNil() {
        let coordinator = AppCoordinator()
        #expect(coordinator.terminateHandler == nil)
    }

    @Test("terminateHandler_주입가능")
    func terminateHandler_injectable() {
        var called = false
        let coordinator = AppCoordinator()
        coordinator.terminateHandler = { called = true }
        coordinator.terminateHandler?()
        #expect(called == true)
    }

    // MARK: - ensureSurfaceForActiveWorkspace (로직 테스트)

    @Test("ensureSurface_워크스페이스없음_크래시없음")
    func ensureSurface_noWorkspace_noCrash() {
        let emptyManager = WorkspaceManager(workspaces: [], activeIndex: 0)
        let coordinator = AppCoordinator(workspaceManager: emptyManager)
        coordinator.ensureSurfaceForActiveWorkspace()
        // 크래시 없이 통과
    }
}

// MARK: - 통합 테스트 (GhosttyApp 필요 — Xcode IDE에서만 실행 가능)

@Suite("AppCoordinator - 통합 테스트", .disabled("GhosttyApp requires GPU/display — run in Xcode IDE"))
@MainActor
struct AppCoordinatorIntegrationTests {

    @Test("splitPane_surfaceView생성_딕셔너리에추가")
    func splitPane_surfaceViewCreated_addedToDictionary() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let coordinator = AppCoordinator(ghosttyApp: app)
        if let initialId = coordinator.activeManager?.focusedPaneId {
            coordinator.surfaceViews[initialId] = GhosttySurfaceView(app: app)
        }
        coordinator.isInitialized = true

        let countBefore = coordinator.surfaceViews.count
        coordinator.splitFocusedPane(direction: .horizontal)

        #expect(coordinator.surfaceViews.count == countBefore + 1)
    }

    @Test("splitPane_수직분할_surfaceView생성")
    func splitPane_vertical_surfaceViewCreated() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let coordinator = AppCoordinator(ghosttyApp: app)
        if let initialId = coordinator.activeManager?.focusedPaneId {
            coordinator.surfaceViews[initialId] = GhosttySurfaceView(app: app)
        }
        coordinator.isInitialized = true

        coordinator.splitFocusedPane(direction: .vertical)

        #expect(coordinator.surfaceViews.count == 2)
        #expect(coordinator.activeManager?.paneCount == 2)
    }

    @Test("splitPane_TUIMode_apiCreatedPane설정")
    func splitPane_tuiMode_apiCreatedPaneSet() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let coordinator = AppCoordinator(ghosttyApp: app)
        if let initialId = coordinator.activeManager?.focusedPaneId {
            coordinator.surfaceViews[initialId] = GhosttySurfaceView(app: app)
        }
        coordinator.isInitialized = true

        coordinator.splitFocusedPane(direction: .horizontal, startInTUIMode: true)

        let newSurface = coordinator.surfaceViews.values.first(where: { $0.apiCreatedPane })
        #expect(newSurface != nil)
        #expect(newSurface?.isCommandRunning == true)
        #expect(newSurface?.blockInputMode == false)
    }

    @Test("closePane_surfaceView제거_딕셔너리에서삭제")
    func closePane_surfaceViewRemoved_deletedFromDictionary() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let coordinator = AppCoordinator(ghosttyApp: app)
        let paneId1 = coordinator.activeManager!.focusedPaneId!
        coordinator.surfaceViews[paneId1] = GhosttySurfaceView(app: app)
        coordinator.isInitialized = true

        coordinator.splitFocusedPane(direction: .horizontal)
        #expect(coordinator.surfaceViews.count == 2)

        let newPaneId = coordinator.activeManager!.focusedPaneId!
        coordinator.closePane(id: newPaneId)

        #expect(coordinator.surfaceViews.count == 1)
        #expect(coordinator.surfaceViews[newPaneId] == nil)
    }

    @Test("closePane_마지막패널_종료핸들러호출")
    func closePane_lastPane_terminateHandlerCalled() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        var terminateCalled = false
        let coordinator = AppCoordinator(ghosttyApp: app)
        coordinator.terminateHandler = { terminateCalled = true }

        let paneId = coordinator.activeManager!.focusedPaneId!
        coordinator.surfaceViews[paneId] = GhosttySurfaceView(app: app)
        coordinator.isInitialized = true

        coordinator.closePane(id: paneId)

        #expect(terminateCalled == true)
    }

    @Test("closePane_마지막패널_워크스페이스여러개_워크스페이스닫기")
    func closePane_lastPane_multipleWorkspaces_closesWorkspace() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let coordinator = AppCoordinator(ghosttyApp: app)
        coordinator.terminateHandler = { }
        coordinator.isInitialized = true

        let pane1 = coordinator.activeManager!.focusedPaneId!
        coordinator.surfaceViews[pane1] = GhosttySurfaceView(app: app)

        coordinator.createNewWorkspace()
        #expect(coordinator.workspaceManager.workspaces.count == 2)

        let activePaneId = coordinator.activeManager!.focusedPaneId!
        coordinator.closePane(id: activePaneId)

        #expect(coordinator.workspaceManager.workspaces.count == 1)
    }

    @Test("createNewWorkspace_워크스페이스추가_surfaceView생성")
    func createNewWorkspace_workspaceAdded_surfaceViewCreated() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let coordinator = AppCoordinator(ghosttyApp: app)
        coordinator.isInitialized = true

        let countBefore = coordinator.workspaceManager.workspaces.count
        coordinator.createNewWorkspace()

        #expect(coordinator.workspaceManager.workspaces.count == countBefore + 1)
        if let newPaneId = coordinator.activeManager?.focusedPaneId {
            #expect(coordinator.surfaceViews[newPaneId] != nil)
        }
    }

    @Test("closeActiveWorkspace_surface정리_워크스페이스삭제")
    func closeActiveWorkspace_surfaceCleaned_workspaceDeleted() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let coordinator = AppCoordinator(ghosttyApp: app)
        coordinator.isInitialized = true

        let pane1 = coordinator.activeManager!.focusedPaneId!
        coordinator.surfaceViews[pane1] = GhosttySurfaceView(app: app)

        coordinator.createNewWorkspace()
        #expect(coordinator.workspaceManager.workspaces.count == 2)

        coordinator.closeActiveWorkspace()

        #expect(coordinator.workspaceManager.workspaces.count == 1)
    }

    @Test("registerPaneController_콜백설정_nil아님")
    func registerPaneController_callbacksSet_notNil() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let coordinator = AppCoordinator(ghosttyApp: app)
        coordinator.registerPaneController()

        let controller = PaneController.shared
        #expect(controller.onSplitPane != nil)
        #expect(controller.onSendKeys != nil)
        #expect(controller.onKillPane != nil)
    }

    @Test("closeFocusedPane_포커스패널닫기_surfaceView제거")
    func closeFocusedPane_focusedPaneClosed_surfaceViewRemoved() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let coordinator = AppCoordinator(ghosttyApp: app)
        let paneId = coordinator.activeManager!.focusedPaneId!
        coordinator.surfaceViews[paneId] = GhosttySurfaceView(app: app)
        coordinator.isInitialized = true

        coordinator.splitFocusedPane(direction: .horizontal)
        #expect(coordinator.surfaceViews.count == 2)

        coordinator.closeFocusedPane()

        #expect(coordinator.surfaceViews.count == 1)
    }

    @Test("ensureSurface_빈패널_surfaceView생성")
    func ensureSurface_emptyPane_surfaceViewCreated() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let coordinator = AppCoordinator(ghosttyApp: app)
        #expect(coordinator.surfaceViews.isEmpty)

        coordinator.ensureSurfaceForActiveWorkspace()

        let leaves = coordinator.workspaceManager.activeWorkspace!.splitManager.root.allLeaves()
        for leaf in leaves {
            #expect(coordinator.surfaceViews[leaf.id] != nil)
        }
    }
}
