import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // ghostty_init은 GhosttyApp.create()에서 호출됨
    }

    func applicationWillTerminate(_ notification: Notification) {
        // cleanup은 ContentView.onDisappear에서 처리
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
