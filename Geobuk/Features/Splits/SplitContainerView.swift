import SwiftUI

/// 분할 트리를 재귀적으로 렌더링하는 뷰
struct SplitContainerView: View {
    let node: SplitNode
    let focusedPaneId: UUID?
    let onFocusPane: (UUID) -> Void
    let surfaceViewProvider: (UUID) -> GhosttySurfaceView?

    var body: some View {
        switch node {
        case .leaf(let content):
            SplitPaneView(
                content: content,
                isFocused: content.id == focusedPaneId,
                onTap: { onFocusPane(content.id) },
                surfaceViewProvider: surfaceViewProvider
            )

        case .split(let container):
            SplitDividerView(
                direction: container.direction,
                ratio: container.ratio,
                first: {
                    SplitContainerView(
                        node: container.first,
                        focusedPaneId: focusedPaneId,
                        onFocusPane: onFocusPane,
                        surfaceViewProvider: surfaceViewProvider
                    )
                },
                second: {
                    SplitContainerView(
                        node: container.second,
                        focusedPaneId: focusedPaneId,
                        onFocusPane: onFocusPane,
                        surfaceViewProvider: surfaceViewProvider
                    )
                }
            )
        }
    }
}

// MARK: - Pane View

/// 단일 패널 뷰
struct SplitPaneView: View {
    let content: PaneContent
    let isFocused: Bool
    let onTap: () -> Void
    let surfaceViewProvider: (UUID) -> GhosttySurfaceView?

    var body: some View {
        ZStack {
            switch content {
            case .terminal:
                if let surfaceView = surfaceViewProvider(content.id) {
                    GeometryReader { geo in
                        TerminalSurfaceRepresentable(
                            surfaceView: surfaceView,
                            size: geo.size
                        )
                    }
                } else {
                    Color.black
                        .overlay {
                            ProgressView("Loading terminal...")
                                .foregroundColor(.white)
                        }
                }
            case .browser:
                Color.gray
                    .overlay {
                        Text("Browser (Phase 7)")
                            .foregroundColor(.white)
                    }
            }
        }
        .border(isFocused ? Color.accentColor : Color.clear, width: 2)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Divider View

/// GeometryReader 기반 분할 뷰 (드래그 핸들 포함)
struct SplitDividerView<First: View, Second: View>: View {
    let direction: SplitDirection
    @State private var ratio: CGFloat
    let first: () -> First
    let second: () -> Second

    private let dividerThickness: CGFloat = 4
    private let minRatio: CGFloat = 0.1
    private let maxRatio: CGFloat = 0.9

    init(
        direction: SplitDirection,
        ratio: CGFloat,
        @ViewBuilder first: @escaping () -> First,
        @ViewBuilder second: @escaping () -> Second
    ) {
        self.direction = direction
        self._ratio = State(initialValue: ratio)
        self.first = first
        self.second = second
    }

    var body: some View {
        GeometryReader { geo in
            let totalSize = direction == .horizontal ? geo.size.width : geo.size.height

            if direction == .horizontal {
                HStack(spacing: 0) {
                    first()
                        .frame(width: totalSize * ratio - dividerThickness / 2)

                    dividerHandle(totalSize: totalSize)

                    second()
                        .frame(width: totalSize * (1 - ratio) - dividerThickness / 2)
                }
            } else {
                VStack(spacing: 0) {
                    first()
                        .frame(height: totalSize * ratio - dividerThickness / 2)

                    dividerHandle(totalSize: totalSize)

                    second()
                        .frame(height: totalSize * (1 - ratio) - dividerThickness / 2)
                }
            }
        }
    }

    @ViewBuilder
    private func dividerHandle(totalSize: CGFloat) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(
                width: direction == .horizontal ? dividerThickness : nil,
                height: direction == .vertical ? dividerThickness : nil
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let position = direction == .horizontal
                            ? value.location.x
                            : value.location.y
                        let newRatio = (totalSize * ratio + position - dividerThickness / 2) / totalSize
                        ratio = min(max(newRatio, minRatio), maxRatio)
                    }
            )
            .onHover { isHovered in
                if isHovered {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
