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
    }

    func applicationWillTerminate(_ notification: Notification) {
        // cleanup은 ContentView.onDisappear에서 처리
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
