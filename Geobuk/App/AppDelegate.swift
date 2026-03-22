import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 타이틀바 투명화 — 앱 배경과 융합
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            configureWindow()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        configureWindow()
        suppressToolbarBackground()
    }

    /// 윈도우 활성화 시 툴바 배경 효과를 억제한다
    private func suppressToolbarBackground() {
        guard let window = NSApp.mainWindow else { return }
        // 모든 NSVisualEffectView의 state를 inactive로 설정
        suppressVisualEffects(in: window.contentView?.superview)
    }

    private func suppressVisualEffects(in view: NSView?) {
        guard let view else { return }
        if let effectView = view as? NSVisualEffectView,
           NSStringFromClass(type(of: view.superview ?? view)).contains("Toolbar") ||
           NSStringFromClass(type(of: view)).contains("Toolbar") {
            effectView.state = .inactive
            effectView.material = .titlebar
            effectView.isEmphasized = false
        }
        for subview in view.subviews {
            suppressVisualEffects(in: subview)
        }
    }

    private var windowConfigured = false

    private func configureWindow() {
        guard !windowConfigured, let window = NSApp.mainWindow else { return }
        windowConfigured = true

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none

        // 툴바 아이템의 active window 배경 제거
        if let toolbarView = findToolbarView(in: window.contentView?.superview) {
            toolbarView.wantsLayer = true
            // 툴바 영역의 vibrancy/material 효과 비활성화
            for subview in toolbarView.subviews {
                if let effectView = subview as? NSVisualEffectView {
                    effectView.state = .inactive
                }
            }
        }
    }

    /// 윈도우 뷰 계층에서 툴바 뷰를 찾는다
    private func findToolbarView(in view: NSView?) -> NSView? {
        guard let view else { return nil }
        if NSStringFromClass(type(of: view)).contains("Toolbar") {
            return view
        }
        for subview in view.subviews {
            if let found = findToolbarView(in: subview) {
                return found
            }
        }
        return nil
    }

    func applicationWillTerminate(_ notification: Notification) {
        // cleanup은 ContentView.onDisappear에서 처리
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
