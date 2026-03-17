import SwiftUI
import AppKit

/// GhosttySurfaceView를 SwiftUI에서 사용하기 위한 래퍼
/// Ghostty 패턴: SurfaceContainerView가 layout()에서 프레임을 관리
struct TerminalSurfaceRepresentable: NSViewRepresentable {
    let surfaceView: GhosttySurfaceView

    func makeNSView(context: Context) -> SurfaceContainerView {
        SurfaceContainerView(surfaceView: surfaceView)
    }

    func updateNSView(_ containerView: SurfaceContainerView, context: Context) {
        // SurfaceContainerView.layout()이 프레임 동기화를 처리
    }
}
