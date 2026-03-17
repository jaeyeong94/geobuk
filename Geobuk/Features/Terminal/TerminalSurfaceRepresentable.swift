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
        // 디바운스: 드래그 중 빈번한 리사이즈로 인한 텍스트 중복 방지
        context.coordinator.scheduleResize(surfaceView: surfaceView, size: size)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        private var resizeTask: Task<Void, Never>?
        /// 디바운스 간격 (나노초)
        private let debounceNanoseconds: UInt64 = 50_000_000 // 50ms

        func scheduleResize(surfaceView: GhosttySurfaceView, size: CGSize) {
            resizeTask?.cancel()
            resizeTask = Task { @MainActor [weak surfaceView] in
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
                guard !Task.isCancelled, let surfaceView else { return }
                surfaceView.sizeDidChange(size)
            }
        }
    }
}
