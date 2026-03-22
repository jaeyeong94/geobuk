import SwiftUI
import AppKit

/// 타이틀바 영역에서 윈도우 드래그를 수행하는 제스처
struct TitleBarDragGesture: Gesture {
    var body: some Gesture {
        DragGesture()
            .onChanged { _ in
                guard let event = NSApp.currentEvent else { return }
                NSApp.mainWindow?.performDrag(with: event)
            }
    }
}
