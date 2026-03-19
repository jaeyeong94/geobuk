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
                containerId: container.id,
                direction: container.direction,
                modelRatio: container.ratio,
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

struct SplitPaneView: View {
    let content: PaneContent
    let isFocused: Bool
    let onTap: () -> Void
    let surfaceViewProvider: (UUID) -> GhosttySurfaceView?

    /// 셸 초기화 오버레이 표시 여부
    @State private var showInitOverlay = true

    /// 명령 실행 중 (TUI 모드 — 터미널 직접 입력)
    @State private var isCommandRunning = false

    /// 입력창 포커스 트리거 (토글할 때마다 포커스)
    @State private var inputFocusTrigger = false

    var body: some View {
        ZStack {
            switch content {
            case .terminal:
                if let surfaceView = surfaceViewProvider(content.id) {
                    VStack(spacing: 0) {
                        ZStack {
                            TerminalSurfaceRepresentable(
                                surfaceView: surfaceView
                            )
                            .onAppear {
                                if !isCommandRunning { surfaceView.blockInputMode = true }
                            }

                            // 셸 영역 클릭 처리
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onTap()
                                    if isCommandRunning {
                                        // 인터렉티브 모드: 터미널에 포커스 복원 (앱 전환 후 복귀 대응)
                                        surfaceView.window?.makeFirstResponder(surfaceView)
                                    } else {
                                        // 블록 모드: 입력창에 포커스
                                        inputFocusTrigger.toggle()
                                    }
                                }

                            // 셸 초기화 완료 전까지 오버레이
                            if showInitOverlay {
                                Color.black
                                    .overlay {
                                        VStack(spacing: 8) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Initializing shell...")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .transition(.opacity)
                                    .task {
                                        // 셸 준비 대기: currentDirectory가 설정될 때까지 폴링
                                        // 또는 최대 2초 후 강제 제거
                                        for _ in 0..<40 {  // 50ms x 40 = 2초
                                            try? await Task.sleep(nanoseconds: 50_000_000)
                                            if surfaceView.currentDirectory != nil { break }
                                        }
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            showInitOverlay = false
                                        }
                                    }
                            }
                        }

                        BlockInputBar(
                            paneFocused: isFocused,
                            focusTrigger: inputFocusTrigger,
                            currentDirectory: surfaceView.currentDirectory,
                            onSubmit: { command in
                                surfaceView.sendText(command)
                                surfaceView.sendKeyPress(keyCode: 36, char: "\r")

                                // precmd 복귀 감지
                                let signalFile = "/tmp/geobuk-precmd-\(surfaceView.viewId.uuidString)"
                                try? FileManager.default.removeItem(atPath: signalFile)

                                Task { @MainActor in
                                    // 500ms 대기 — 빠른 명령이면 이미 완료됨
                                    try? await Task.sleep(nanoseconds: 500_000_000)

                                    if FileManager.default.fileExists(atPath: signalFile) {
                                        // 빠른 명령: 이미 완료 → 입력창 유지
                                        try? FileManager.default.removeItem(atPath: signalFile)
                                        return
                                    }

                                    // 느린 명령: TUI 모드로 전환
                                    isCommandRunning = true
                                    surfaceView.blockInputMode = false
                                    surfaceView.window?.makeFirstResponder(surfaceView)

                                    // 완료 대기
                                    for _ in 0..<6000 {
                                        try? await Task.sleep(nanoseconds: 100_000_000)
                                        if FileManager.default.fileExists(atPath: signalFile) {
                                            try? FileManager.default.removeItem(atPath: signalFile)
                                            break
                                        }
                                    }

                                    // 블록 입력 모드 복귀
                                    isCommandRunning = false
                                    surfaceView.blockInputMode = true
                                    // 입력창에 포커스 복귀
                                    inputFocusTrigger.toggle()
                                }
                            },
                            onTab: {
                                // macOS Tab keycode = 48
                                surfaceView.sendKeyPress(keyCode: 48, char: "\t")
                            },
                            onInterrupt: {
                                // Ctrl+C: keycode 8 (c) + ctrl mod
                                surfaceView.sendKeyPress(keyCode: 8, char: "c", mods: GHOSTTY_MODS_CTRL)
                            }
                        )
                        .opacity(isCommandRunning ? 0 : 1)
                        .frame(height: isCommandRunning ? 0 : nil)
                        .animation(.easeInOut(duration: 0.15), value: isCommandRunning)
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
        .border(isFocused ? Color.blue.opacity(0.6) : Color.gray.opacity(0.2), width: 1)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Divider View

struct SplitDividerView<First: View, Second: View>: View {
    let containerId: UUID
    let direction: SplitDirection
    let modelRatio: CGFloat
    @State private var ratio: CGFloat
    let first: () -> First
    let second: () -> Second

    private let dividerThickness: CGFloat = 1
    private let minRatio: CGFloat = 0.1
    private let maxRatio: CGFloat = 0.9

    init(
        containerId: UUID,
        direction: SplitDirection,
        modelRatio: CGFloat,
        @ViewBuilder first: @escaping () -> First,
        @ViewBuilder second: @escaping () -> Second
    ) {
        self.containerId = containerId
        self.direction = direction
        self.modelRatio = modelRatio
        self._ratio = State(initialValue: modelRatio)
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
        // 모델 ratio가 변경되면 (equalized 등) @State도 동기화
        .onChange(of: modelRatio) { _, newValue in
            ratio = newValue
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
                    let cursor: NSCursor = direction == .horizontal
                        ? .resizeLeftRight
                        : .resizeUpDown
                    cursor.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
