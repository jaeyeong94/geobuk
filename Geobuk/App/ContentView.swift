import SwiftUI

struct ContentView: View {
    @State private var coordinator = AppCoordinator()

    // MARK: - UI-only State

    @State private var isSidebarVisible = true
    @State private var isSettingsOpen = false
    @State private var isHelpOpen = false
    @State private var fontSize: Double = 14
    @State private var paddingX: Double = 8
    @State private var paddingY: Double = 4
    @State private var lineHeight: Double = 1.0
    @State private var fontFamily: String = ""
    @State private var isRightPanelVisible = true
    @AppStorage("leftSidebarWidth") private var leftSidebarWidth: Double = 200
    @AppStorage("rightSidebarWidth") private var rightSidebarWidth: Double = 350
    @State private var rightPanelRefreshTrigger: Int = 0
    @State private var isFullMaximized = false
    @State private var savedSidebarVisible: Bool?
    @State private var savedRightPanelVisible: Bool?

    var body: some View {
        VStack(spacing: 0) {
            customTitleBar
            mainContent
        }
        .frame(minWidth: 600, minHeight: 400)
        .ignoresSafeArea(.all, edges: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
                await coordinator.initialize()
            }
            .modifier(PaneNotificationModifier(
                onSplitHorizontally: { withAnimation(.easeInOut(duration: 0.15)) { coordinator.splitFocusedPane(direction: .horizontal) } },
                onSplitVertically: { withAnimation(.easeInOut(duration: 0.15)) { coordinator.splitFocusedPane(direction: .vertical) } },
                onToggleMaximize: { withAnimation(.easeInOut(duration: 0.15)) { toggleFullMaximize() } },
                onFocusDirection: { notification in
                    if let direction = notification.object as? NavigationDirection {
                        coordinator.activeManager?.focusPane(direction: direction)
                        if let id = coordinator.activeManager?.focusedPaneId { coordinator.focusSurfaceView(id: id, userInitiated: true) }
                    }
                },
                onClosePane: { withAnimation(.easeInOut(duration: 0.15)) { coordinator.closeFocusedPane() } },
                onChildExited: { notification in
                    if let surfaceView = notification.object as? GhosttySurfaceView {
                        let sid = surfaceView.viewId.uuidString
                        if TeamPaneTracker.shared.isTeammate(surfaceId: sid) {
                            TeamPaneTracker.shared.remove(surfaceId: sid)
                        } else {
                            coordinator.closePane(for: surfaceView)
                        }
                    }
                }
            ))
            .modifier(WorkspaceNotificationModifier(
                onNewWorkspace: { coordinator.createNewWorkspace() },
                onCloseWorkspace: { coordinator.closeActiveWorkspace() },
                onToggleSidebar: {
                    exitFullMaximizeIfNeeded()
                    isSidebarVisible.toggle()
                },
                onSwitchWorkspace: { notification in
                    exitFullMaximizeIfNeeded()
                    if let number = notification.object as? Int {
                        coordinator.workspaceManager.switchToWorkspace(at: number - 1)
                        coordinator.ensureSurfaceForActiveWorkspace()
                    }
                },
                onNewClaudeSession: { coordinator.startNewClaudeSession() },
                onOpenSettings: { isSettingsOpen.toggle() },
                onToggleRightPanel: {
                    exitFullMaximizeIfNeeded()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRightPanelVisible.toggle()
                    }
                },
                onIncreaseFontSize: { coordinator.adjustFontSize(delta: 1, currentFontSize: &fontSize) },
                onDecreaseFontSize: { coordinator.adjustFontSize(delta: -1, currentFontSize: &fontSize) },
                onSwitchRightPanelTab: { _ in
                    exitFullMaximizeIfNeeded()
                }
            ))
            .popover(isPresented: $isSettingsOpen, arrowEdge: .trailing) {
                TerminalSettingsView(
                    fontSize: $fontSize,
                    paddingX: $paddingX,
                    paddingY: $paddingY,
                    lineHeight: $lineHeight,
                    fontFamily: $fontFamily,
                    claudeSettings: coordinator.claudeLaunchSettings,
                    notificationCoordinator: coordinator.notificationCoordinator,
                    onFontSizeChange: { newSize in
                        coordinator.setFontSizeForAllSurfaces(newSize)
                    },
                    onConfigChanged: {
                        coordinator.ghosttyApp.updateSettings(
                            fontSize: fontSize,
                            paddingX: paddingX,
                            paddingY: paddingY,
                            lineHeight: lineHeight,
                            fontFamily: fontFamily
                        )
                    }
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .showHelp)) { _ in
                isHelpOpen.toggle()
            }
            .sheet(isPresented: $isHelpOpen) {
                HelpView(isPresented: $isHelpOpen)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                if let focusedId = coordinator.activeManager?.focusedPaneId,
                   let sv = coordinator.surfaceViews[focusedId] {
                    let sid = sv.viewId.uuidString
                    coordinator.notificationCoordinator.markAllAsRead(source: sid)
                    NotificationCenter.default.post(name: .geobukDismissRing, object: sid)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .geobukShellCommandStarted)) { notification in
                if let surfaceId = notification.userInfo?["surfaceId"] as? String {
                    coordinator.notificationCoordinator.commandStarted(surfaceId: surfaceId)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .geobukShellPromptReady)) { notification in
                coordinator.updateFocusedDirectory()
                rightPanelRefreshTrigger += 1
                if let surfaceId = notification.userInfo?["surfaceId"] as? String {
                    let command = coordinator.shellStateManager.shellStates[surfaceId]?.command
                    coordinator.notificationCoordinator.commandFinished(surfaceId: surfaceId, command: command)

                    let activePaneIds = coordinator.activeManager?.root.allLeaves().map(\.id) ?? []
                    for (paneId, sv) in coordinator.surfaceViews where sv.viewId.uuidString == surfaceId {
                        guard !activePaneIds.contains(paneId) else { continue }
                        if sv.isCommandRunning {
                            sv.isCommandRunning = false
                            sv.blockInputMode = true
                        }
                    }
                }
            }
            .onChange(of: coordinator.claudeMonitor.sessionState.phase) { _, newPhase in
                guard let sessionId = coordinator.claudeMonitor.sessionState.sessionId else { return }
                let state = coordinator.claudeMonitor.getState(for: sessionId)
                let claudeSurfaceId: String? = {
                    for (_, sv) in coordinator.surfaceViews {
                        if sv.isCommandRunning {
                            return sv.viewId.uuidString
                        }
                    }
                    return coordinator.activeManager?.focusedPaneId.flatMap { coordinator.surfaceViews[$0]?.viewId.uuidString }
                }()
                coordinator.notificationCoordinator.handleClaudeEvent(
                    phase: newPhase,
                    sessionId: sessionId,
                    toolName: state?.currentToolName,
                    costUSD: state?.costUSD ?? 0,
                    surfaceId: claudeSurfaceId
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .focusTeammatPane)) { notification in
                if let surfaceId = notification.object as? String,
                   let paneEntry = coordinator.surfaceViews.first(where: { $0.value.viewId.uuidString == surfaceId }) {
                    coordinator.activeManager?.setFocusedPane(id: paneEntry.key)
                    coordinator.focusSurfaceView(id: paneEntry.key, userInitiated: true)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .geobukPWDChanged)) { notification in
                if let sv = notification.object as? GhosttySurfaceView,
                   let focusedId = coordinator.activeManager?.focusedPaneId,
                   coordinator.surfaceViews[focusedId] === sv {
                    coordinator.focusedDirectory = sv.currentDirectory
                }
            }
            .onDisappear {
                coordinator.autoSaveTask?.cancel()
                coordinator.cleanup()
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            if coordinator.isInitialized {
                HStack(spacing: 0) {
                    if isSidebarVisible {
                        SidebarView(
                            workspaceManager: coordinator.workspaceManager,
                            claudeMonitor: coordinator.claudeMonitor,
                            claudeFileWatcher: coordinator.claudeFileWatcher,
                            processMonitor: coordinator.processMonitor,
                            shellStateManager: coordinator.shellStateManager,
                            systemMonitor: coordinator.systemMonitor,
                            notificationCoordinator: coordinator.notificationCoordinator,
                            surfaceViews: coordinator.surfaceViews,
                            onWorkspaceSwitch: { coordinator.ensureSurfaceForActiveWorkspace() },
                            onCreateWorkspace: { coordinator.createNewWorkspace() },
                            onNewClaudeSession: { coordinator.startNewClaudeSession() },
                            onClose: { isSidebarVisible = false }
                        )
                        .frame(width: leftSidebarWidth)

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
                        .id(coordinator.workspaceManager.activeWorkspace?.id)

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

                    RightSidebarView(
                            provider: coordinator.terminalProcessProvider,
                            systemMonitor: coordinator.systemMonitor,
                            surfaceView: coordinator.activeManager?.focusedPaneId.flatMap { coordinator.surfaceViews[$0] },
                            claudeMonitor: coordinator.claudeMonitor,
                            claudeFileWatcher: coordinator.claudeFileWatcher,
                            currentDirectory: coordinator.focusedDirectory,
                            notificationCoordinator: coordinator.notificationCoordinator,
                            refreshTrigger: rightPanelRefreshTrigger,
                            isPanelExpanded: $isRightPanelVisible,
                            onExecuteCommand: { command in
                                if let focusedId = coordinator.activeManager?.focusedPaneId,
                                   let sv = coordinator.surfaceViews[focusedId] {
                                    sv.sendText(command)
                                    sv.sendKeyPress(keyCode: 36, char: "\r")
                                }
                            }
                        )
                        .frame(width: isRightPanelVisible ? rightSidebarWidth : nil)
                }
            } else if let errorMessage = coordinator.errorMessage {
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

    // MARK: - Custom Title Bar

    private var customTitleBar: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 72, height: 28)

            HStack(spacing: 6) {
                Text("GEOBUK")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.green.opacity(0.8))

                if let ws = coordinator.workspaceManager.activeWorkspace {
                    Text("·")
                        .foregroundColor(.secondary.opacity(0.3))
                    Text(ws.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.7))
                }

                if (coordinator.activeManager?.paneCount ?? 1) > 1 {
                    Text("·")
                        .foregroundColor(.secondary.opacity(0.3))
                    Text(verbatim: "\(coordinator.activeManager?.paneCount ?? 1) panes")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                }

                if coordinator.claudeFileWatcher.activeSessions.count > 0 {
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

            Spacer()
                .frame(width: 100)
        }
        .frame(height: 28)
    }

    private var dynamicTitle: String {
        guard let workspace = coordinator.workspaceManager.activeWorkspace else { return "Geobuk" }

        let focusedSurface: GhosttySurfaceView? = {
            guard let id = workspace.splitManager.focusedPaneId else { return nil }
            return coordinator.surfaceViews[id]
        }()

        if let surface = focusedSurface, surface.isCommandRunning {
            for session in coordinator.claudeFileWatcher.activeSessions {
                if let state = coordinator.claudeMonitor.getState(for: session.sessionId),
                   state.phase != .idle {
                    let model = coordinator.claudeMonitor.sessionModels[session.sessionId] ?? "claude"
                    let phase = phaseTextForTitle(state.phase, toolName: state.currentToolName)
                    var title = "\(model) · \(phase)"
                    if state.costUSD > 0 {
                        title += String(format: " · $%.2f", state.costUSD)
                    }
                    return title
                }
            }
        }

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
        if let workspace = coordinator.workspaceManager.activeWorkspace {
            let splitManager = workspace.splitManager
            if splitManager.isMaximized, let focusedId = splitManager.focusedPaneId {
                SplitPaneView(
                    content: splitManager.root.allLeaves().first(where: { $0.id == focusedId })
                        ?? splitManager.root.allLeaves()[0],
                    isFocused: true,
                    onTap: {},
                    surfaceViewProvider: { id in coordinator.surfaceViews[id] },
                    notificationCoordinator: coordinator.notificationCoordinator
                )
                .transition(.opacity)
            } else {
                SplitContainerView(
                    node: splitManager.root,
                    focusedPaneId: splitManager.focusedPaneId,
                    onFocusPane: { id in
                        splitManager.setFocusedPane(id: id)
                        coordinator.focusSurfaceView(id: id, userInitiated: true)
                    },
                    surfaceViewProvider: { id in
                        coordinator.surfaceViews[id]
                    },
                    notificationCoordinator: coordinator.notificationCoordinator,
                    onResizeComplete: { containerId, ratio in
                        splitManager.resizeSplit(containerId: containerId, ratio: ratio)
                    }
                )
                .transition(.opacity)
            }
        } else {
            Color.black
        }
    }

    // MARK: - Full Maximize

    private func exitFullMaximizeIfNeeded() {
        guard isFullMaximized else { return }
        if let saved = savedSidebarVisible {
            isSidebarVisible = saved
            savedSidebarVisible = nil
        }
        if let saved = savedRightPanelVisible {
            isRightPanelVisible = saved
            savedRightPanelVisible = nil
        }
        if coordinator.activeManager?.isMaximized == true {
            coordinator.activeManager?.toggleMaximize()
        }
        isFullMaximized = false
    }

    private func toggleFullMaximize() {
        if isFullMaximized {
            if let saved = savedSidebarVisible {
                isSidebarVisible = saved
                savedSidebarVisible = nil
            }
            if let saved = savedRightPanelVisible {
                isRightPanelVisible = saved
                savedRightPanelVisible = nil
            }
            if coordinator.activeManager?.isMaximized == true {
                coordinator.activeManager?.toggleMaximize()
            }
            isFullMaximized = false
        } else {
            savedSidebarVisible = isSidebarVisible
            savedRightPanelVisible = isRightPanelVisible
            isSidebarVisible = false
            isRightPanelVisible = false
            if (coordinator.activeManager?.paneCount ?? 1) > 1 {
                coordinator.activeManager?.toggleMaximize()
            }
            isFullMaximized = true
        }
    }
}

// MARK: - Notification ViewModifiers (타입 체커 부하 분산)

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
