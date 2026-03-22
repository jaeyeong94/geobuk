import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var windowConfigured = false
    /// 최초 생성된 메인 윈도우 참조 (알림 클릭 시 복귀용)
    private weak var primaryWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 알림 클릭 시 기존 윈도우를 활성화하도록 delegate 설정
        UNUserNotificationCenter.current().delegate = self

        // 새 윈도우 생성 감지 — 중복 윈도우 닫기
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            configureWindow()
        }
    }

    /// 새 윈도우가 key가 되면 중복인지 검사하여 닫기
    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        // primaryWindow 등록 (최초 1회)
        if primaryWindow == nil {
            primaryWindow = window
            return
        }

        // 이미 primary가 있는데 다른 윈도우가 key가 됨 → 중복 윈도우 닫기
        if window !== primaryWindow, !window.className.contains("Panel") {
            window.close()
            primaryWindow?.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 알림 클릭 시 호출 — 기존 윈도우를 활성화 (새 윈도우 생성 방지)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // primary 윈도우가 있으면 직접 활성화
        if let primary = primaryWindow {
            NSApp.activate(ignoringOtherApps: true)
            primary.makeKeyAndOrderFront(nil)
        } else {
            activateExistingWindow()
        }
        completionHandler()
    }

    /// 앱이 포그라운드일 때도 알림 배너 표시 허용 (선택적)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 앱이 포그라운드면 배너 표시하지 않음 (앱 내 알림 시스템 사용)
        completionHandler([])
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
        window.isMovableByWindowBackground = false

        // 우측 타이틀바 아이콘을 NSTitlebarAccessoryViewController로 배치
        // NSTitlebarContainerView 내부에 배치되므로 클릭 이벤트가 정상 전달됨
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

    func applicationWillTerminate(_ notification: Notification) {
        // cleanup은 ContentView.onDisappear에서 처리
    }

    /// 앱 재활성화 시 (Dock 클릭, 알림 클릭) 기존 윈도우를 보여줌
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 윈도우가 없으면 기존 윈도우를 찾아서 표시
            activateExistingWindow()
        }
        return false // false = SwiftUI가 새 윈도우를 만들지 않음
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// 기존 윈도우를 찾아서 활성화
    private func activateExistingWindow() {
        NSApp.activate(ignoringOtherApps: true)

        // 기존 윈도우를 찾아서 앞으로 가져오기
        if let window = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // 모든 윈도우가 숨겨진 경우 — 첫 번째 윈도우를 복원
            for window in NSApp.windows {
                if window.className.contains("AppKit") { continue }
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
    }
}

// MARK: - Title Bar Accessory View

/// 타이틀바 우측에 배치되는 아이콘 버튼들
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

/// mouseDownCanMoveWindow = false로 버튼 클릭 시 윈도우 드래그를 방지
private class NonDraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { false }
}
