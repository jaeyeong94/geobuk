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

    /// 명령 실행 중 (SwiftUI 반응용 — surfaceView.isCommandRunning과 동기화)
    @State private var isRunning = false

    /// 입력창 포커스 트리거 (토글할 때마다 포커스)
    @State private var inputFocusTrigger = false

    /// 현재 작업 디렉토리 (surfaceView.currentDirectory를 SwiftUI에서 추적)
    @State private var currentDir: String? = nil

    var body: some View {
        ZStack {
            switch content {
            case .terminal:
                if let surfaceView = surfaceViewProvider(content.id) {
                    VStack(spacing: 0) {
                        ZStack(alignment: .topTrailing) {
                            TerminalSurfaceRepresentable(
                                surfaceView: surfaceView
                            )
                            .onAppear {
                                if !surfaceView.isCommandRunning { surfaceView.blockInputMode = true }; isRunning = surfaceView.isCommandRunning
                                currentDir = surfaceView.currentDirectory
                            }

                            // 패널 닫기 버튼 (우측 상단, 포커스 시에만 표시)
                            if isFocused {
                                Button(action: {
                                    NotificationCenter.default.post(name: .closePane, object: nil)
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.secondary.opacity(0.6))
                                        .padding(6)
                                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                .help("Close Pane (Cmd+W)")
                                .padding(6)
                            }

                            // 스크롤 이벤트를 차단하지 않도록 오버레이 제거
                            // 탭 처리는 외부 컨테이너의 onTapGesture에서 처리

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
                                        currentDir = surfaceView.currentDirectory
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            showInitOverlay = false
                                        }
                                    }
                            }
                        }

                        BlockInputBar(
                            paneFocused: isFocused,
                            focusTrigger: inputFocusTrigger,
                            persistentText: Binding(
                                get: { surfaceView.pendingInputText },
                                set: { surfaceView.pendingInputText = $0 }
                            ),
                            currentDirectory: currentDir,
                            onSubmit: { command in
                                // 명령만 전송. 모드 전환은 소켓 알림 기반으로 처리
                                surfaceView.sendText(command)
                                surfaceView.sendKeyPress(keyCode: 36, char: "\r")
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
                        .opacity(isRunning ? 0 : 1)
                        .frame(height: isRunning ? 0 : nil)
                        .animation(.easeInOut(duration: 0.15), value: isRunning)
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
        .onTapGesture {
            onTap()
            if let surfaceView = surfaceViewProvider(content.id) {
                if isRunning {
                    surfaceView.window?.makeFirstResponder(surfaceView)
                } else {
                    inputFocusTrigger.toggle()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .geobukShellCommandStarted)) { notification in
            // 셸이 preexec를 보고 → 명령 시작됨
            guard case .terminal = content,
                  let surfaceView = surfaceViewProvider(content.id),
                  let sid = notification.userInfo?["surfaceId"] as? String,
                  sid == surfaceView.viewId.uuidString else { return }

            let cmd = notification.userInfo?["command"] as? String ?? ""
            GeobukLogger.debug(.shell, "SplitPaneView received commandStarted", context: ["command": cmd, "surfaceId": sid])
            surfaceView.shellRunning = true

            // 기존 TUI 전환 대기 취소 (빠르게 연속 입력 시)
            surfaceView.tuiTransitionTask?.cancel()

            // 2초 후에도 prompt가 안 오면 TUI 모드로 전환 (느린 명령)
            surfaceView.tuiTransitionTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, surfaceView.shellRunning else { return }

                // 아직 running → 느린 명령 (next dev, vim 등)
                surfaceView.isCommandRunning = true; isRunning = true
                surfaceView.blockInputMode = false
                surfaceView.window?.makeFirstResponder(surfaceView)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .geobukShellPromptReady)) { notification in
            // 셸이 precmd를 보고 → 명령 완료됨
            guard case .terminal = content,
                  let surfaceView = surfaceViewProvider(content.id),
                  let sid = notification.userInfo?["surfaceId"] as? String,
                  sid == surfaceView.viewId.uuidString else { return }

            GeobukLogger.debug(.shell, "SplitPaneView received promptReady", context: ["surfaceId": sid, "wasRunning": "\(surfaceView.isCommandRunning)", "cwd": surfaceView.currentDirectory ?? "nil"])
            surfaceView.shellRunning = false

            // TUI 전환 대기 취소 (빠른 명령이 완료됨)
            surfaceView.tuiTransitionTask?.cancel()
            surfaceView.tuiTransitionTask = nil

            if surfaceView.isCommandRunning {
                // TUI → 블록 모드 복귀
                surfaceView.isCommandRunning = false; isRunning = false
                surfaceView.blockInputMode = true
                currentDir = surfaceView.currentDirectory
                inputFocusTrigger.toggle()
            } else {
                // 빠른 명령 — CWD만 갱신
                currentDir = surfaceView.currentDirectory
            }
        }
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
