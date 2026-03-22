import SwiftUI
import AppKit

/// 타이틀바 영역에서 윈도우 드래그를 방지하는 컨테이너
/// fullSizeContentView에서 타이틀바 높이의 뷰는 시스템이 드래그 이벤트를 가져가므로
/// 버튼이 클릭되지 않는 문제를 해결한다
struct NonDraggableButtonArea<Content: View>: NSViewRepresentable {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    func makeNSView(context: Context) -> NonDraggableNSView {
        let view = NonDraggableNSView()
        let hostingView = NSHostingView(rootView: content())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        return view
    }

    func updateNSView(_ nsView: NonDraggableNSView, context: Context) {
        if let hostingView = nsView.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content()
        }
    }
}

/// mouseDownCanMoveWindow = false로 윈도우 드래그를 방지하는 NSView
class NonDraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}
