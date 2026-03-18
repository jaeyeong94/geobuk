import SwiftUI

struct ContentView: View {
    @State private var ghosttyApp = GhosttyApp()
    @State private var splitManager = SplitTreeManager()
    @State private var surfaceViews: [UUID: GhosttySurfaceView] = [:]
    @State private var sessionManager = SessionManager()
    @State private var socketServer: SocketServer?
    @State private var errorMessage: String?
    @State private var isInitialized = false

    var body: some View {
        Group {
            if isInitialized {
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
            splitManager.toggleMaximize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusPaneDirection)) { notification in
            if let direction = notification.object as? NavigationDirection {
                splitManager.focusPane(direction: direction)
                if let id = splitManager.focusedPaneId { focusSurfaceView(id: id) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .closePane)) { _ in
            closeFocusedPane()
        }
        .onDisappear {
            Task { await socketServer?.stop() }
            sessionManager.destroyAllSessions()
            for surfaceView in surfaceViews.values {
                surfaceView.close()
            }
            surfaceViews.removeAll()
            ghosttyApp.destroy()
        }
    }

    // MARK: - Terminal Initialization

    @MainActor
    private func initializeTerminal() async {
        do {
            try ghosttyApp.create()
            let initialPaneId = splitManager.focusedPaneId!
            let surfaceView = GhosttySurfaceView(app: ghosttyApp)
            surfaceViews[initialPaneId] = surfaceView
            isInitialized = true

            // 초기 패널에 포커스
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusSurfaceView(id: initialPaneId)
            }

            // 소켓 서버 시작 (별도 Task로 — initializeTerminal이 블로킹하지 않도록)
            Task { await startSocketServer() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Split Operations

    @MainActor
    private func splitFocusedPane(direction: SplitDirection) {
        guard isInitialized else { return }

        splitManager.splitFocusedPane(direction: direction)

        if let newPaneId = splitManager.focusedPaneId,
           surfaceViews[newPaneId] == nil {
            let surfaceView = GhosttySurfaceView(app: ghosttyApp)
            surfaceViews[newPaneId] = surfaceView

            // 새 패널에 자동 포커스 (뷰 계층에 추가된 후)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusSurfaceView(id: newPaneId)
            }
        }
    }

    // MARK: - Close Operations

    @MainActor
    private func closeFocusedPane() {
        guard isInitialized else { return }

        // 패널이 1개면 앱 종료
        if splitManager.paneCount <= 1 {
            NSApplication.shared.terminate(nil)
            return
        }

        // 닫을 패널의 surface 정리
        if let closingId = splitManager.focusedPaneId {
            splitManager.closeFocusedPane()

            // surface 해제
            if let surfaceView = surfaceViews.removeValue(forKey: closingId) {
                surfaceView.close()
            }

            // 남은 패널에 포커스
            if let newFocusId = splitManager.focusedPaneId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusSurfaceView(id: newFocusId)
                }
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
