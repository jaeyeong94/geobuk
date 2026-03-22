import AppKit
import SwiftUI

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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
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
