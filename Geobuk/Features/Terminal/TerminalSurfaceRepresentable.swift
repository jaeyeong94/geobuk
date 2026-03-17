import SwiftUI
import AppKit

/// GhosttySurfaceView를 SwiftUI에서 사용하기 위한 래퍼
/// Ghostty 패턴: SurfaceView는 외부에서 생성하여 전달 (SwiftUI 리빌드에서 살아남도록)
struct TerminalSurfaceRepresentable: NSViewRepresentable {
    let surfaceView: GhosttySurfaceView
    let size: CGSize

    func makeNSView(context: Context) -> NSView {
        surfaceView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // 즉시 동기 리사이즈 — Metal 렌더링과 뷰 프레임 동기화 필수
        surfaceView.sizeDidChange(size)
    }
}
