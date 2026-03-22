import SwiftUI

/// JetBrains 스타일 커스텀 타이틀바
/// 트래픽 라이트 영역 + 앱 정보 + 우측 아이콘
struct CustomTitleBar: View {
    let title: String
    let workspaceName: String?
    let paneCount: Int
    let claudeActive: Bool

    var onToggleSidebar: (() -> Void)?
    var onNewWorkspace: (() -> Void)?
    var onSettings: (() -> Void)?

    /// 타이틀바 높이
    private static let barHeight: CGFloat = 38

    /// 트래픽 라이트 버튼 영역 너비
    private static let trafficLightWidth: CGFloat = 78

    var body: some View {
        HStack(spacing: 0) {
            // 트래픽 라이트 영역 (시스템 버튼 공간 확보)
            Color.clear
                .frame(width: Self.trafficLightWidth)

            // 중앙: 타이틀 정보
            titleContent
                .frame(maxWidth: .infinity)

            // 우측: 아이콘 버튼들
            rightIcons
        }
        .frame(height: Self.barHeight)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        // 드래그로 윈도우 이동 가능하도록
        .gesture(WindowDragGesture())
    }

    // MARK: - Title Content

    private var titleContent: some View {
        HStack(spacing: 8) {
            // 앱 로고
            Text("GEOBUK")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.green.opacity(0.8))

            if let ws = workspaceName {
                Text("·")
                    .foregroundColor(.secondary.opacity(0.4))

                Text(ws)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            if paneCount > 1 {
                Text("·")
                    .foregroundColor(.secondary.opacity(0.4))

                Text("\(paneCount) panes")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            // Claude 상태 인디케이터
            if claudeActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }

            // 동적 타이틀 (경로 등)
            Text(title)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Right Icons

    private var rightIcons: some View {
        HStack(spacing: 2) {
            titleBarButton(icon: "sidebar.left", help: "Toggle Sidebar (Cmd+B)") {
                onToggleSidebar?()
            }

            titleBarButton(icon: "plus.square", help: "New Workspace (Cmd+T)") {
                onNewWorkspace?()
            }

            titleBarButton(icon: "gearshape", help: "Settings (Cmd+,)") {
                onSettings?()
            }
        }
        .padding(.trailing, 12)
    }

    private func titleBarButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            // 호버 효과는 SwiftUI가 자동 처리
        }
    }
}

// MARK: - Window Drag Gesture

/// 타이틀바 드래그로 윈도우 이동
private struct WindowDragGesture: Gesture {
    var body: some Gesture {
        DragGesture()
            .onChanged { _ in
                NSApp.mainWindow?.performDrag(with: NSApp.currentEvent!)
            }
    }
}
