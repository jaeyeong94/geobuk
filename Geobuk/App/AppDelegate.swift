import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 소켓 서버는 ContentView에서 shellStateManager와 함께 시작
    }

    func applicationWillTerminate(_ notification: Notification) {
        // cleanup은 ContentView.onDisappear에서 처리
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
