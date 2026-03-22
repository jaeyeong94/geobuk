import SwiftUI
import AppKit

/// 타이틀바 영역에서 클릭 가능한 버튼
/// hiddenTitleBar + fullSizeContentView에서 SwiftUI Button/onTapGesture가 동작하지 않으므로
/// NSButton을 직접 사용하여 클릭 이벤트를 처리한다
struct TitleBarButton: NSViewRepresentable {
    let systemName: String
    let size: CGFloat
    let color: NSColor
    let action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .inline
        button.isBordered = false
        button.title = ""
        button.image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = color
        button.target = context.coordinator
        button.action = #selector(Coordinator.clicked)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .vertical)

        // 시스템 크기 설정
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        button.image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)

        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        nsView.image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)
        nsView.contentTintColor = color
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func clicked() { action() }
    }
}
