import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowConfigured = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            configureWindow()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        configureWindow()
    }

    private func configureWindow() {
        guard !windowConfigured, let window = NSApp.mainWindow else { return }
        windowConfigured = true

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarSeparatorStyle = .none
        window.toolbar = nil
        // 타이틀바 영역의 자동 드래그를 비활성화 → 버튼 클릭 가능
        window.isMovableByWindowBackground = false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // cleanup은 ContentView.onDisappear에서 처리
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
