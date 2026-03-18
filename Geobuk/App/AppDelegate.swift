import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    /// 소켓 서버 인스턴스
    private var socketServer: SocketServer?

    /// 세션 매니저 인스턴스
    @MainActor
    private(set) lazy var sessionManager = SessionManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        startSocketServer()
    }

    /// SwiftUI에서 applicationDidFinishLaunching이 호출되지 않는 경우를 대비
    func applicationDidBecomeActive(_ notification: Notification) {
        startSocketServer()
    }

    private var socketServerStarted = false

    private func startSocketServer() {
        guard !socketServerStarted else { return }
        socketServerStarted = true

        Task {
            do {
                let manager = await sessionManager
                let server = SocketServer(sessionManager: manager)
                await MainActor.run { self.socketServer = server }
                try await server.start()
                await MainActor.run { AppState.shared.isSocketServerRunning = true }
            } catch {
                fputs("[Geobuk] Socket server failed: \(error)\n", stderr)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task {
            await socketServer?.stop()
        }
        Task { @MainActor in
            sessionManager.destroyAllSessions()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
