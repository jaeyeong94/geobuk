import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var windowConfigured = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 중복 인스턴스 방지 — 이미 실행 중이면 종료
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier && $0.processIdentifier != getpid()
        }
        if !runningApps.isEmpty {
            GeobukLogger.warn(.app, "Another Geobuk instance is running, terminating this one")
            NSApp.terminate(nil)
            return
        }

        // 알림 delegate 설정
        UNUserNotificationCenter.current().delegate = self

        // 자동 탭 생성 방지
        NSWindow.allowsAutomaticWindowTabbing = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            configureWindow()
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 알림 클릭 시 — 기존 윈도우 활성화 (Window scene이 단일 윈도우를 보장)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.mainWindow?.makeKeyAndOrderFront(nil)
        completionHandler()
    }

    /// 앱이 포그라운드일 때 알림 배너 표시하지 않음
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        configureWindow()
    }

    /// Dock 클릭 시 기존 윈도우 활성화
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.mainWindow?.makeKeyAndOrderFront(nil)
        }
        return false
    }

    // MARK: - Window Configuration

    private func configureWindow() {
        guard !windowConfigured, let window = NSApp.mainWindow else { return }
        windowConfigured = true

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarSeparatorStyle = .none
        window.toolbar = nil
        window.isMovableByWindowBackground = false

        addRightAccessory(to: window)
    }

    private func addRightAccessory(to window: NSWindow) {
        let buttonView = TitleBarAccessoryView()
        let hostingView = NonDraggableHostingView(rootView: buttonView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 100, height: 28)

        let accessoryVC = NSTitlebarAccessoryViewController()
        accessoryVC.layoutAttribute = .trailing
        accessoryVC.view = hostingView

        window.addTitlebarAccessoryViewController(accessoryVC)
    }

    func applicationWillTerminate(_ notification: Notification) {}

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

// MARK: - Title Bar Accessory View

private struct TitleBarAccessoryView: View {
    var body: some View {
        HStack(spacing: 4) {
            accessoryButton(icon: "sidebar.left") {
                NotificationCenter.default.post(name: .toggleSidebar, object: nil)
            }
            accessoryButton(icon: "plus.square") {
                NotificationCenter.default.post(name: .newWorkspace, object: nil)
            }
            accessoryButton(icon: "gearshape") {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
        }
        .padding(.trailing, 6)
    }

    private func accessoryButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Non-Draggable Hosting View

private class NonDraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { false }
}
