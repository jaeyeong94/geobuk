import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 소켓 서버 인스턴스
    private var socketServer: SocketServer?

    /// 세션 매니저 인스턴스
    @MainActor
    private(set) lazy var sessionManager = SessionManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ghostty_init은 GhosttyApp.create()에서 호출됨

        // 소켓 서버 시작
        Task { @MainActor in
            let manager = sessionManager
            let server = SocketServer(sessionManager: manager)
            self.socketServer = server
            do {
                try await server.start()
                AppState.shared.isSocketServerRunning = true
            } catch {
                // 소켓 서버 시작 실패 시 앱은 계속 실행 (터미널 기능은 정상)
                print("[Geobuk] Socket server start failed: \(error)")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 소켓 서버 정리
        Task {
            await socketServer?.stop()
        }
        // 세션 정리
        Task { @MainActor in
            sessionManager.destroyAllSessions()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
