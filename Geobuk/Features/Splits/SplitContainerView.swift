import SwiftUI

/// 분할 트리를 재귀적으로 렌더링하는 뷰
struct SplitContainerView: View {
    let node: SplitNode
    let focusedPaneId: UUID?
    let onFocusPane: (UUID) -> Void
    let surfaceViewProvider: (UUID) -> GhosttySurfaceView?
    var notificationCoordinator: NotificationCoordinator?
    var onResizeComplete: ((UUID, CGFloat) -> Void)?

    var body: some View {
        switch node {
        case .leaf(let content):
            SplitPaneView(
                content: content,
                isFocused: content.id == focusedPaneId,
                onTap: { onFocusPane(content.id) },
                surfaceViewProvider: surfaceViewProvider,
                notificationCoordinator: notificationCoordinator
            )

        case .split(let container):
            SplitDividerView(
                containerId: container.id,
                direction: container.direction,
                modelRatio: container.ratio,
                onResizeComplete: onResizeComplete,
                first: {
                    SplitContainerView(
                        node: container.first,
                        focusedPaneId: focusedPaneId,
                        onFocusPane: onFocusPane,
                        surfaceViewProvider: surfaceViewProvider,
                        notificationCoordinator: notificationCoordinator,
                        onResizeComplete: onResizeComplete
                    )
                },
                second: {
                    SplitContainerView(
                        node: container.second,
                        focusedPaneId: focusedPaneId,
                        onFocusPane: onFocusPane,
                        surfaceViewProvider: surfaceViewProvider,
                        notificationCoordinator: notificationCoordinator,
                        onResizeComplete: onResizeComplete
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
    var notificationCoordinator: NotificationCoordinator?

    /// 셸 초기화 오버레이 표시 여부
    @State private var showInitOverlay = true

    /// 명령 실행 중 (SwiftUI 반응용 — surfaceView.isCommandRunning과 동기화)
    @State private var isRunning = false

    /// 검색 오버레이 표시 (SwiftUI 반응용 — surfaceView.searchActive와 동기화)
    @State private var isSearching = false

    /// 확대 표시 중인 팀원 surfaceId (nil이면 리더 표시)
    @State private var expandedTeammateSurfaceId: String? = nil

    /// 입력창 포커스 트리거 (토글할 때마다 포커스)
    @State private var inputFocusTrigger = false

    /// 현재 작업 디렉토리 (surfaceView.currentDirectory를 SwiftUI에서 추적)
    @State private var currentDir: String? = nil

    /// 원격 접속 정보 (SSH 세션일 때 user@host 형태)
    @State private var remoteHost: String? = nil

    /// 알림 링 투명도 (애니메이션용)
    @State private var ringOpacity: Double = 0

    /// 현재 알림 링 색상
    @State private var ringColor: Color = .clear

    /// 링 페이드아웃 태스크 (자동 해제용)
    @State private var ringDismissTask: Task<Void, Never>? = nil

    /// 알림 링 색상 매핑
    private func color(for alertType: PaneAlertType) -> Color {
        switch alertType {
        case .permissionRequest: return .red
        case .sessionComplete: return .green
        case .commandComplete: return .blue
        case .error: return .yellow
        }
    }

    /// surfaceId 문자열 (이 패널의 식별자)
    private var surfaceId: String? {
        guard case .terminal = content,
              let surfaceView = surfaceViewProvider(content.id) else { return nil }
        return surfaceView.viewId.uuidString
    }

    /// 알림 링 애니메이션 시작 — 포커스할 때까지 유지 (자동 사라짐 없음)
    private func startRingAnimation(for alertType: PaneAlertType) {
        ringDismissTask?.cancel()
        ringColor = color(for: alertType)

        switch alertType {
        case .permissionRequest:
            // 펄싱 애니메이션: 0→1→0 반복 — 포커스할 때까지 유지
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                ringOpacity = 1.0
            }

        case .sessionComplete, .commandComplete, .error:
            // 정적 링 — 포커스할 때까지 유지
            withAnimation(.easeIn(duration: 0.2)) { ringOpacity = 1.0 }
        }
    }

    /// 알림 링 즉시 해제
    private func dismissRing() {
        ringDismissTask?.cancel()
        ringDismissTask = nil
        withAnimation(.easeOut(duration: 0.2)) {
            ringOpacity = 0
        }
    }

    /// 팀원 카드 좌우 이동 (direction: +1 다음, -1 이전)
    private func navigateTeammate(mates: [TeamPaneTracker.Teammate], direction: Int) {
        withAnimation(.easeInOut(duration: 0.15)) {
            guard !mates.isEmpty else { return }

            if let currentId = expandedTeammateSurfaceId,
               let currentIdx = mates.firstIndex(where: { $0.surfaceId == currentId }) {
                let nextIdx = (currentIdx + direction + mates.count) % mates.count
                expandedTeammateSurfaceId = mates[nextIdx].surfaceId
            } else {
                // 확대 없는 상태 → 첫 번째(→) 또는 마지막(←) 팀원 확대
                expandedTeammateSurfaceId = direction > 0 ? mates.first?.surfaceId : mates.last?.surfaceId
            }
        }
    }

    var body: some View {
        ZStack {
            switch content {
            case .terminal:
                if let surfaceView = surfaceViewProvider(content.id) {
                    let mates = TeamPaneTracker.shared.teammates(for: surfaceView.viewId.uuidString)
                    let expandedSV = expandedTeammateSurfaceId.flatMap { TeamPaneTracker.shared.teamSurfaceViews[$0] }

                    VStack(spacing: 0) {
                        ZStack(alignment: .topTrailing) {
                            Group {
                                if let expandedSV {
                                    TerminalSurfaceRepresentable(surfaceView: expandedSV)
                                        .id("team-\(expandedTeammateSurfaceId ?? "")")
                                } else {
                                    TerminalSurfaceRepresentable(surfaceView: surfaceView)
                                        .id("leader-\(surfaceView.viewId)")
                                }
                            }
                            .onAppear {
                                if surfaceView.apiCreatedPane {
                                    // API로 생성된 패널은 TUI 모드 유지
                                    isRunning = true
                                } else if !surfaceView.isCommandRunning {
                                    surfaceView.blockInputMode = true
                                }
                                isRunning = surfaceView.isCommandRunning
                                currentDir = surfaceView.currentDirectory
                            }

                            // 터미널 내 검색 오버레이 (좌측 상단 — 우측의 X 버튼과 겹치지 않도록)
                            if isSearching {
                                TerminalSearchOverlay(surfaceView: surfaceView)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                            remoteHost: remoteHost,
                            onSubmit: { command in
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
                        .opacity(isRunning || expandedTeammateSurfaceId != nil ? 0 : 1)
                        .frame(height: isRunning || expandedTeammateSurfaceId != nil ? 0 : nil)
                        .animation(.easeInOut(duration: 0.15), value: isRunning)

                        // 팀원 미니 터미널 바 (리더 패널일 때만 표시)
                        if !mates.isEmpty {
                            TeamMemberBar(
                                teammates: mates,
                                teamSurfaceViews: TeamPaneTracker.shared.teamSurfaceViews,
                                expandedSurfaceId: expandedTeammateSurfaceId,
                                leaderSurfaceId: surfaceView.viewId.uuidString
                            ) { selectedSurfaceId in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if selectedSurfaceId == surfaceView.viewId.uuidString {
                                        // 리더 카드 클릭 → 리더로 복귀
                                        expandedTeammateSurfaceId = nil
                                    } else {
                                        // 팀원 카드 클릭 → 해당 팀원으로 전환 (이미 확대 중이어도 다른 팀원으로 전환)
                                        expandedTeammateSurfaceId = selectedSurfaceId
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: mates.count) { _, _ in
                        if let expandedId = expandedTeammateSurfaceId,
                           !mates.contains(where: { $0.surfaceId == expandedId }) {
                            expandedTeammateSurfaceId = nil
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .teamCollapseExpanded)) { _ in
                        guard expandedTeammateSurfaceId != nil else { return }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            expandedTeammateSurfaceId = nil
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .teamNavigateNext)) { _ in
                        guard !mates.isEmpty else { return }
                        navigateTeammate(mates: mates, direction: 1)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .teamNavigatePrev)) { _ in
                        guard !mates.isEmpty else { return }
                        navigateTeammate(mates: mates, direction: -1)
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
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(ringColor, lineWidth: 2)
                .opacity(ringOpacity)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
            // 사용자 클릭 시 알림 읽음 처리 + 링 해제
            if let sid = surfaceId {
                notificationCoordinator?.markAllAsRead(source: sid)
                dismissRing()
            }
            if let surfaceView = surfaceViewProvider(content.id) {
                if isRunning {
                    surfaceView.window?.makeFirstResponder(surfaceView)
                } else {
                    inputFocusTrigger.toggle()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .geobukDismissRing)) { notification in
            guard let sid = notification.object as? String,
                  let mySid = surfaceId,
                  sid == mySid else { return }
            dismissRing()
        }
        .onReceive(NotificationCenter.default.publisher(for: .geobukNotificationPosted)) { notification in
            guard let geobukNotification = notification.object as? GeobukNotification,
                  let sid = surfaceId,
                  geobukNotification.source.contains(sid) else { return }

            // 알림 타입 결정 및 링 애니메이션 시작
            let alertType: PaneAlertType = {
                if let coordinator = notificationCoordinator,
                   let type = coordinator.alertColor(for: sid) {
                    return type
                }
                // 코디네이터 없을 때 제목으로 추론
                if geobukNotification.title.contains("waiting") { return .permissionRequest }
                if geobukNotification.title.contains("complete") { return .sessionComplete }
                if geobukNotification.title.contains("error") || geobukNotification.title.contains("Error") { return .error }
                return .commandComplete
            }()

            startRingAnimation(for: alertType)

            // 포커스된 패널이면 깜빡임 후 자동 해제 (1초)
            if isFocused {
                ringDismissTask?.cancel()
                ringDismissTask = Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.3)) { ringOpacity = 0 }
                    notificationCoordinator?.markAllAsRead(source: sid)
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

            // SSH 감지: 블록 모드 유지 + alternate screen 폴링만 (폴백 타이머 없음)
            let isSSH = Self.isSSHCommand(cmd)

            // SSH 감지 즉시 원격 호스트 정보 설정 (Task 밖에서 → SwiftUI 즉시 반영)
            if isSSH {
                remoteHost = Self.parseSSHHost(cmd)
                GeobukLogger.debug(.shell, "SSH detected", context: ["remoteHost": remoteHost ?? "nil", "command": cmd])
            }

            // alternate screen 폴링 + 타이머 폴백
            // 1) 50ms 간격으로 alternate screen 감지 → 즉시 TUI 전환 (vim, htop 등)
            // 2) SSH가 아닌 경우: 1초 경과 시 alternate screen 없어도 TUI 전환 (claude 등)
            // 3) SSH인 경우: alternate screen만으로 전환 판단 (블록 모드 유지)
            surfaceView.tuiTransitionTask = Task { @MainActor in
                let pollInterval: UInt64 = 50_000_000     // 50ms
                let fallbackPolls = 20                     // 50ms × 20 = 1초 (폴백 타이머)
                let maxPolls = 200                         // 50ms × 200 = 10초 (최대 대기)

                if isSSH {
                    // SSH 접속 대기 후 원격 셸에 OSC 7 보고 설정 주입
                    // 1.5초 대기: SSH 핸드셰이크 + 셸 시작 시간
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard !Task.isCancelled, surfaceView.shellRunning else { return }

                    // 원격 셸에 PROMPT_COMMAND + 프롬프트 숨김 설정
                    // PS1='' → 원격 프롬프트 완전 숨김 (블록 입력이 대신함)
                    // 웰컴 메시지는 유지 — clear 하지 않음
                    // \033[1A\033[2K → 커서 위로 + 줄 삭제 (이 명령 자체의 흔적 제거)
                    let injection = "export PROMPT_COMMAND='printf \"\\033]7;file://$(hostname)$(pwd)\\007\"'; PS1=''; printf '\\033[1A\\033[2K'"
                    surfaceView.sendText(injection)
                    surfaceView.sendKeyPress(keyCode: 36, char: "\r") // Enter

                    // SSH 모드: alternate screen 감지 시에만 TUI 전환
                    // SSH 세션 동안 계속 폴링 (precmd가 올 때까지)
                    var wasAlternate = false
                    while !Task.isCancelled && surfaceView.shellRunning {
                        try? await Task.sleep(nanoseconds: pollInterval)
                        guard !Task.isCancelled, surfaceView.shellRunning else { return }

                        let isAlt = surfaceView.surfaceHandle.map {
                            ghostty_surface_is_alternate_screen($0)
                        } ?? false

                        if isAlt && !wasAlternate {
                            // 원격 TUI 앱 시작 → TUI 모드
                            GeobukLogger.debug(.shell, "SSH: alternate screen ON → TUI mode", context: ["surfaceId": sid])
                            surfaceView.isCommandRunning = true; isRunning = true
                            surfaceView.blockInputMode = false
                            surfaceView.window?.makeFirstResponder(surfaceView)
                        } else if !isAlt && wasAlternate {
                            // 원격 TUI 앱 종료 → 블록 모드 복귀
                            GeobukLogger.debug(.shell, "SSH: alternate screen OFF → block mode", context: ["surfaceId": sid])
                            surfaceView.isCommandRunning = false; isRunning = false
                            surfaceView.blockInputMode = true
                            inputFocusTrigger.toggle()
                        }
                        wasAlternate = isAlt
                    }
                } else {
                    // 일반 명령: alternate screen 감지 + 폴백 타이머
                    for i in 0..<maxPolls {
                        try? await Task.sleep(nanoseconds: pollInterval)
                        guard !Task.isCancelled, surfaceView.shellRunning else { return }

                        if let surface = surfaceView.surfaceHandle,
                           ghostty_surface_is_alternate_screen(surface) {
                            GeobukLogger.debug(.shell, "Alternate screen detected → TUI mode", context: ["surfaceId": sid])
                            surfaceView.isCommandRunning = true; isRunning = true
                            surfaceView.blockInputMode = false
                            surfaceView.window?.makeFirstResponder(surfaceView)
                            return
                        }

                        if i == fallbackPolls - 1 {
                            GeobukLogger.debug(.shell, "Fallback timer → TUI mode", context: ["surfaceId": sid])
                            surfaceView.isCommandRunning = true; isRunning = true
                            surfaceView.blockInputMode = false
                            surfaceView.window?.makeFirstResponder(surfaceView)
                            return
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .geobukShellPromptReady)) { notification in
            // 셸이 precmd를 보고 → 명령 완료됨
            guard case .terminal = content,
                  let surfaceView = surfaceViewProvider(content.id),
                  let sid = notification.userInfo?["surfaceId"] as? String,
                  sid == surfaceView.viewId.uuidString else { return }

            GeobukLogger.debug(.shell, "SplitPaneView received promptReady", context: ["surfaceId": sid, "wasRunning": "\(surfaceView.isCommandRunning)", "apiCreated": "\(surfaceView.apiCreatedPane)", "cwd": surfaceView.currentDirectory ?? "nil"])
            surfaceView.shellRunning = false

            // SSH 종료 → 원격 호스트 정보 초기화
            remoteHost = nil

            // TUI 전환 대기 취소 (빠른 명령이 완료됨)
            surfaceView.tuiTransitionTask?.cancel()
            surfaceView.tuiTransitionTask = nil

            if surfaceView.apiCreatedPane {
                // API 생성 패널: 블록 모드 복원하지 않음 (TUI 유지)
                // isRunning을 true로 유지해야 BlockInputBar가 표시되지 않음
                // apiCreatedPane 플래그 해제 — 이후 명령은 정상 블록 모드 전환
                surfaceView.apiCreatedPane = false
                surfaceView.shellRunning = false
            } else if surfaceView.isCommandRunning {
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
        .onReceive(NotificationCenter.default.publisher(for: .geobukPWDChanged)) { notification in
            // OSC 7로 경로가 변경될 때 (SSH 원격 cd 포함) 즉시 반영
            guard case .terminal = content,
                  let surfaceView = surfaceViewProvider(content.id),
                  let sv = notification.object as? GhosttySurfaceView,
                  sv.viewId == surfaceView.viewId else { return }
            currentDir = sv.currentDirectory
        }
        .onReceive(NotificationCenter.default.publisher(for: .geobukSearchStateChanged)) { notification in
            guard case .terminal = content,
                  let surfaceView = surfaceViewProvider(content.id),
                  let sv = notification.object as? GhosttySurfaceView,
                  sv.viewId == surfaceView.viewId else { return }
            isSearching = sv.searchActive
        }
    }

    /// 명령어가 SSH 세션인지 판별
    private static func isSSHCommand(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        let first = trimmed.split(separator: " ", maxSplits: 1).first.map(String.init) ?? trimmed
        return ["ssh", "scp", "sftp", "mosh"].contains(first)
    }

    /// SSH 명령에서 user@host 또는 host를 파싱
    /// 예: "ssh user@host", "ssh -p 22 user@host", "ssh host"
    private static func parseSSHHost(_ command: String) -> String? {
        let parts = command.trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
            .map(String.init)
        guard parts.first == "ssh" || parts.first == "mosh" else { return nil }

        // 옵션을 건너뛰고 호스트 인자를 찾음
        // -p, -i, -o, -l, -L, -R, -D, -J 등은 다음 인자가 값
        let optionsWithValue: Set<String> = ["-p", "-i", "-o", "-l", "-L", "-R", "-D", "-J", "-F", "-b", "-c", "-e", "-m", "-w", "-W"]
        var i = 1
        while i < parts.count {
            let part = parts[i]
            if part.hasPrefix("-") {
                if optionsWithValue.contains(part) {
                    i += 2 // 옵션 + 값 건너뛰기
                } else {
                    i += 1 // 플래그만 건너뛰기
                }
            } else {
                // 옵션이 아닌 첫 인자 = 호스트
                return part
            }
        }
        return nil
    }
}

// MARK: - Divider View

struct SplitDividerView<First: View, Second: View>: View {
    let containerId: UUID
    let direction: SplitDirection
    let modelRatio: CGFloat
    let onResizeComplete: ((UUID, CGFloat) -> Void)?
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
        onResizeComplete: ((UUID, CGFloat) -> Void)? = nil,
        @ViewBuilder first: @escaping () -> First,
        @ViewBuilder second: @escaping () -> Second
    ) {
        self.containerId = containerId
        self.direction = direction
        self.modelRatio = modelRatio
        self.onResizeComplete = onResizeComplete
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
                    .onEnded { _ in
                        onResizeComplete?(containerId, ratio)
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
