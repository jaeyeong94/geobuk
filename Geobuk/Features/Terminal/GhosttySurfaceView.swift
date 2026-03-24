import AppKit

/// libghostty의 Metal 렌더링 터미널 surface를 호스팅하는 NSView
/// ghostty_surface_t를 생성하고 키보드/마우스 이벤트를 전달
@MainActor
final class GhosttySurfaceView: NSView, @preconcurrency NSTextInputClient {
    // MARK: - Properties

    /// surface 식별용 고유 ID (PTY 로그 파일 연결에 사용)
    let viewId = UUID()

    nonisolated(unsafe) private var surface: ghostty_surface_t?
    private weak var ghosttyApp: GhosttyApp?

    /// IME marked text (한글 조합 등)
    private var markedText = NSMutableAttributedString()

    /// keyDown 중 insertText로부터 누적된 텍스트 (nil = keyDown 밖)
    private var keyTextAccumulator: [String]?

    /// 셸의 현재 작업 디렉토리 (OSC 7 → action_cb PWD로 업데이트)
    var currentDirectory: String?

    /// 검색 상태
    var searchActive: Bool = false
    var searchNeedle: String = ""
    var searchTotal: Int = -1
    var searchSelected: Int = -1

    /// 검색 종료
    func endSearch() {
        executeAction("end_search")
        searchActive = false
        searchNeedle = ""
        searchTotal = -1
        searchSelected = -1
        NotificationCenter.default.post(name: .geobukSearchStateChanged, object: self)
    }

    /// 검색 쿼리 전송
    func submitSearch(_ needle: String) {
        searchNeedle = needle
        executeAction("search:\(needle)")
    }

    /// 검색 결과 탐색
    func navigateSearch(direction: String) {
        executeAction("navigate_search:\(direction)")
    }

    /// surface 존재 여부
    var hasSurface: Bool { surface != nil }

    /// C surface 핸들 (클립보드 콜백 등에서 사용)
    var surfaceHandle: ghostty_surface_t? { surface }

    // MARK: - Initialization

    /// GhosttyApp으로부터 새 surface 생성
    /// skipBlockMode: true이면 ZDOTDIR 미적용 (Team 패널 등 일반 셸 사용)
    init(app: GhosttyApp, cwd: String? = nil, command: String? = nil, skipBlockMode: Bool = false) {
        self.ghosttyApp = app
        // 초기 프레임을 0이 아닌 크기로 설정하여 빈 화면 방지
        // Metal 렌더링이 시작될 때 유효한 크기가 필요함
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        guard let appHandle = app.appHandle else { return }

        var surfaceConfig = ghostty_surface_config_new()
        surfaceConfig.platform_tag = GHOSTTY_PLATFORM_MACOS
        surfaceConfig.platform = ghostty_platform_u(
            macos: ghostty_platform_macos_s(
                nsview: Unmanaged.passUnretained(self).toOpaque()
            )
        )
        surfaceConfig.userdata = Unmanaged.passUnretained(self).toOpaque()
        surfaceConfig.scale_factor = Double(NSScreen.main?.backingScaleFactor ?? 2.0)
        surfaceConfig.font_size = 0 // 0 = config default
        surfaceConfig.context = GHOSTTY_SURFACE_CONTEXT_WINDOW

        // 환경 변수 준비: 셸 통합 스크립트가 사용할 surface ID와 소켓 경로
        var envVarDefs: [(String, String)] = [
            ("GEOBUK_SURFACE_ID", viewId.uuidString),
            ("GEOBUK_SOCKET_PATH", SocketServer.defaultSocketPath),
            // Claude Code Team split-pane: iTerm2 백엔드로 인식시킴
            ("TERM_PROGRAM", "iTerm.app"),
            ("ITERM_SESSION_ID", "geobuk-\(viewId.uuidString)"),
        ]

        // 일반 패널은 ZDOTDIR로 블록 모드 셸 사용, Team 패널은 일반 셸
        if !skipBlockMode {
            envVarDefs.append(("ZDOTDIR", BlockModeZshSetup.zdotdir))
        }

        // it2 shim을 PATH 앞에 배치 (실제 iTerm2의 it2보다 먼저 실행)
        let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        envVarDefs.append(("PATH", "\(AppPath.binDir.path):\(currentPath)"))

        // C 문자열 포인터를 ghostty_surface_new 호출 전까지 유지해야 함
        // withCString 중첩 대신, 명시적으로 strdup하여 수명을 관리
        var cKeys: [UnsafeMutablePointer<CChar>] = []
        var cValues: [UnsafeMutablePointer<CChar>] = []
        var envVars: [ghostty_env_var_s] = []

        for (key, value) in envVarDefs {
            let cKey = strdup(key)!
            let cValue = strdup(value)!
            cKeys.append(cKey)
            cValues.append(cValue)
            envVars.append(ghostty_env_var_s(key: cKey, value: cValue))
        }

        // 셸 통합 스크립트 경로도 환경 변수로 설정
        if let integrationPath = Bundle.main.path(
            forResource: "geobuk-zsh-integration",
            ofType: "zsh"
        ) {
            let cKey = strdup("GEOBUK_SHELL_INTEGRATION")!
            let cValue = strdup(integrationPath)!
            cKeys.append(cKey)
            cValues.append(cValue)
            envVars.append(ghostty_env_var_s(key: cKey, value: cValue))
        }

        // initial_input 불필요 — ZDOTDIR의 .zshrc에서 clear + 배너 출력

        envVars.withUnsafeMutableBufferPointer { buffer in
            surfaceConfig.env_vars = buffer.baseAddress
            surfaceConfig.env_var_count = buffer.count

            // 작업 디렉토리 설정
            if let cwd {
                cwd.withCString { ptr in
                    surfaceConfig.working_directory = ptr
                    self.surface = ghostty_surface_new(appHandle, &surfaceConfig)
                }
            } else {
                self.surface = ghostty_surface_new(appHandle, &surfaceConfig)
            }
        }

        // C 문자열 해제 (surface 생성 완료 후 안전)
        for ptr in cKeys { free(ptr) }
        for ptr in cValues { free(ptr) }

        // 드래그 & 드롭 타입 등록 (파일, URL, 텍스트)
        registerForDraggedTypes([.string, .fileURL, .URL])

        GeobukLogger.debug(.terminal, "Surface created", context: ["viewId": viewId.uuidString])
    }

    /// 기존 surface의 설정을 상속받아 새 surface 생성 (분할 시 사용)
    /// 폰트 크기, 색상 테마 등 현재 surface의 설정이 새 패널에 그대로 적용됨
    init(app: GhosttyApp, inheritFrom existingSurface: GhosttySurfaceView) {
        self.ghosttyApp = app
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        guard let appHandle = app.appHandle,
              let sourceSurface = existingSurface.surfaceHandle else { return }

        // 기존 surface에서 설정 상속
        var surfaceConfig = ghostty_surface_inherited_config(sourceSurface, GHOSTTY_SURFACE_CONTEXT_SPLIT)
        surfaceConfig.platform_tag = GHOSTTY_PLATFORM_MACOS
        surfaceConfig.platform = ghostty_platform_u(
            macos: ghostty_platform_macos_s(
                nsview: Unmanaged.passUnretained(self).toOpaque()
            )
        )
        surfaceConfig.userdata = Unmanaged.passUnretained(self).toOpaque()
        surfaceConfig.scale_factor = Double(NSScreen.main?.backingScaleFactor ?? 2.0)

        // 환경 변수 준비 (메인 init와 동일)
        var envVarDefs: [(String, String)] = [
            ("GEOBUK_SURFACE_ID", viewId.uuidString),
            ("GEOBUK_SOCKET_PATH", SocketServer.defaultSocketPath),
            ("ZDOTDIR", BlockModeZshSetup.zdotdir),
            ("TERM_PROGRAM", "iTerm.app"),
            ("ITERM_SESSION_ID", "geobuk-\(viewId.uuidString)"),
        ]

        if let shimPath = Bundle.main.path(forResource: "geobuk-it2-shim", ofType: nil) {
            let shimDir = (shimPath as NSString).deletingLastPathComponent
            let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
            envVarDefs.append(("PATH", "\(shimDir):\(currentPath)"))
        }

        var cKeys: [UnsafeMutablePointer<CChar>] = []
        var cValues: [UnsafeMutablePointer<CChar>] = []
        var envVars: [ghostty_env_var_s] = []

        for (key, value) in envVarDefs {
            let cKey = strdup(key)!
            let cValue = strdup(value)!
            cKeys.append(cKey)
            cValues.append(cValue)
            envVars.append(ghostty_env_var_s(key: cKey, value: cValue))
        }

        if let integrationPath = Bundle.main.path(
            forResource: "geobuk-zsh-integration",
            ofType: "zsh"
        ) {
            let cKey = strdup("GEOBUK_SHELL_INTEGRATION")!
            let cValue = strdup(integrationPath)!
            cKeys.append(cKey)
            cValues.append(cValue)
            envVars.append(ghostty_env_var_s(key: cKey, value: cValue))
        }

        // initial_input 불필요 — ZDOTDIR의 .zshrc에서 clear + 배너 출력

        // 기존 surface의 작업 디렉토리 상속
        let inheritedCwd = existingSurface.currentDirectory

        envVars.withUnsafeMutableBufferPointer { buffer in
            surfaceConfig.env_vars = buffer.baseAddress
            surfaceConfig.env_var_count = buffer.count

            if let cwd = inheritedCwd {
                cwd.withCString { ptr in
                    surfaceConfig.working_directory = ptr
                    self.surface = ghostty_surface_new(appHandle, &surfaceConfig)
                }
            } else {
                self.surface = ghostty_surface_new(appHandle, &surfaceConfig)
            }
        }

        for ptr in cKeys { free(ptr) }
        for ptr in cValues { free(ptr) }

        registerForDraggedTypes([.string, .fileURL, .URL])

        GeobukLogger.debug(.terminal, "Surface created (inherited config)", context: ["viewId": viewId.uuidString])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        if surface != nil {
            GeobukLogger.warn(.terminal, "Surface not closed before dealloc — releasing on main thread",
                context: ["viewId": viewId.uuidString])
            let s = surface
            surface = nil
            if let s {
                DispatchQueue.main.async { ghostty_surface_free(s) }
            }
        }
    }

    // MARK: - View Lifecycle

    /// 명령 실행 중 (TUI 모드 — 워크스페이스 전환에도 유지)
    var isCommandRunning: Bool = false

    /// 블록 입력창 텍스트 (워크스페이스 전환에도 유지)
    var pendingInputText: String = ""

    /// 셸이 preexec를 보고한 후 아직 precmd가 오지 않은 상태 (명령 실행 중)
    var shellRunning: Bool = false

    /// TUI 전환 대기 태스크 (precmd가 오면 취소)
    var tuiTransitionTask: Task<Void, Never>?

    /// API(pane.split)로 생성된 패널 — 블록 모드 대신 TUI 모드로 시작
    var apiCreatedPane: Bool = false

    /// 블록 입력 모드일 때 터미널 직접 입력 비활성화
    var blockInputMode: Bool = false {
        didSet {
            if blockInputMode {
                // 포커스 해제 + 커서 비활성화
                window?.makeFirstResponder(nil)
                setFocusState(false)
            }
        }
    }

    override var acceptsFirstResponder: Bool { !blockInputMode }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }

        // Retina 스케일 팩터 설정
        layer?.contentsScale = window.backingScaleFactor
        updateContentScale()

        // 트래킹 영역 설정 — mouseMoved/mouseEntered/mouseExited 이벤트 수신에 필요
        updateTrackingAreas()
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: frame,
            options: [
                .mouseEnteredAndExited,
                .mouseMoved,
                .inVisibleRect,
                .activeAlways,
            ],
            owner: self,
            userInfo: nil
        ))
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: currentCursor)
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        guard let window else { return }
        layer?.contentsScale = window.backingScaleFactor
        updateContentScale()
    }

    // MARK: - Terminal Size

    /// 현재 터미널 크기 (columns/rows) 조회
    var terminalSize: (columns: UInt16, rows: UInt16)? {
        guard let surface else { return nil }
        let size = ghostty_surface_size(surface)
        return (size.columns, size.rows)
    }

    // MARK: - Size & Scale

    /// SurfaceContainerView.layout()에서 호출
    func sizeDidChange(_ size: CGSize) {
        guard let surface else { return }
        guard size.width > 0 && size.height > 0 else { return }
        let backingSize = convertToBacking(size)
        ghostty_surface_set_size(
            surface,
            UInt32(backingSize.width),
            UInt32(backingSize.height)
        )
    }

    /// 포커스 상태 변경
    func setFocusState(_ focused: Bool) {
        guard let surface else { return }
        ghostty_surface_set_focus(surface, focused)
    }

    /// 콘텐츠 스케일 업데이트
    func updateContentScale() {
        guard let surface, let window else { return }
        let scale = window.backingScaleFactor
        ghostty_surface_set_content_scale(surface, scale, scale)
    }

    // MARK: - Keyboard Input

    /// NSResponder 기본 동작 방지 (화살표 키, Delete 등)
    /// interpretKeyEvents가 moveUp:, moveDown: 등의 셀렉터를 호출할 때
    /// 기본 NSView 동작 대신 ghostty_surface_key로 처리되도록 빈 구현
    override func doCommand(by selector: Selector) {
        // Intentionally empty — prevents NSResponder default handling
        // Arrow keys, delete, etc. are handled via ghostty_surface_key
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }

        // Esc 키: 팀원 확대 상태이면 축소
        if event.keyCode == 53 { // 53 = Escape
            let sid = viewId.uuidString
            let tracker = TeamPaneTracker.shared
            // 이 surfaceView가 확대된 팀원이거나 팀원을 가진 리더이면 축소 알림
            if tracker.isTeammate(surfaceId: sid) || tracker.isLeader(surfaceId: sid) {
                NotificationCenter.default.post(name: .teamCollapseExpanded, object: nil)
                return true
            }
        }

        // Cmd+F: 터미널 내 검색 토글 (직접 상태 변경 — Ghostty 왕복 없이 즉시 반응)
        if event.modifierFlags.contains(.command) && event.keyCode == 3 {
            if searchActive {
                endSearch()
            } else {
                searchActive = true
                NotificationCenter.default.post(name: .geobukSearchStateChanged, object: self)
            }
            return true
        }

        // Command 키 조합은 항상 메뉴 시스템으로 전달
        // (Cmd+D → Split, Cmd+T → New Tab, Cmd+W → Close 등)
        if event.modifierFlags.contains(.command) {
            return super.performKeyEquivalent(with: event)
        }

        // Control 키 조합을 터미널로 직접 전달 (TUI 앱에서 Ctrl+C, Ctrl+D 등 필수)
        // AppKit이 일부 Control 조합을 가로채는 것을 방지
        // 단, Ctrl+숫자(0~9)는 우측 패널 탭 전환 단축키이므로 메뉴 시스템으로 전달
        if event.modifierFlags.contains(.control) {
            if let chars = event.charactersIgnoringModifiers,
               let scalar = chars.unicodeScalars.first,
               scalar >= "0" && scalar <= "9" {
                return super.performKeyEquivalent(with: event)
            }
            self.keyDown(with: event)
            return true
        }

        return false
    }

    override func keyDown(with event: NSEvent) {
        guard !blockInputMode else { return }
        guard let surface else { return }

        let action = event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS

        // Option-as-Alt: Ghostty 코어에 modifier 변환을 질의하여
        // Option 키를 Alt로 변환할지 결정 (터미널 앱에서 Alt 시퀀스 전송 필요)
        let translationMods = resolveTranslationMods(for: event)

        // modifier가 변환되었으면 변환된 modifier로 새 이벤트 생성
        // 한글 IME 호환: modifier가 같으면 원본 이벤트 재사용 (AppKit 내부 동등성 보존)
        let translationEvent: NSEvent
        if translationMods == event.modifierFlags {
            translationEvent = event
        } else {
            translationEvent = NSEvent.keyEvent(
                with: event.type,
                location: event.locationInWindow,
                modifierFlags: translationMods,
                timestamp: event.timestamp,
                windowNumber: event.windowNumber,
                context: nil,
                characters: event.characters(byApplyingModifiers: translationMods) ?? "",
                charactersIgnoringModifiers: event.charactersIgnoringModifiers ?? "",
                isARepeat: event.isARepeat,
                keyCode: event.keyCode
            ) ?? event
        }

        // Ghostty 패턴: keyDown 중에만 accumulator 활성화
        keyTextAccumulator = []
        defer { keyTextAccumulator = nil }

        // marked text 상태 기억 (composing 판별용)
        let markedTextBefore = markedText.length > 0

        // 키보드 레이아웃 감지: 한영 전환 시 레이아웃만 변경되는 이벤트를 무시
        let keyboardIdBefore: String? = markedTextBefore ? nil : KeyboardLayout.id

        interpretKeyEvents([translationEvent])

        // 키보드 레이아웃이 변경되었으면 IME가 이벤트를 소비한 것 → 무시
        if !markedTextBefore, let before = keyboardIdBefore, before != KeyboardLayout.id {
            return
        }

        // preedit 동기화 (한글 조합 중 상태 반영)
        syncPreedit(clearIfNeeded: markedTextBefore)

        if let list = keyTextAccumulator, !list.isEmpty {
            // 조합 완료된 텍스트를 키 이벤트에 첨부하여 원자적으로 전달
            for text in list {
                _ = sendKeyWithText(
                    action, event: event,
                    translationMods: translationMods,
                    text: text
                )
            }
        } else {
            // 일반 키 이벤트 (화살표, Enter, Backspace 등)
            _ = sendKeyWithText(
                action, event: event,
                translationMods: translationMods,
                text: translationEvent.ghosttyCharacters,
                composing: markedText.length > 0 || markedTextBefore
            )
        }
    }

    /// Option-as-Alt 변환을 위한 modifier 해석
    /// Ghostty 코어에 질의하여 Option을 Alt로 변환할지 결정
    private func resolveTranslationMods(for event: NSEvent) -> NSEvent.ModifierFlags {
        guard let surface else { return event.modifierFlags }

        let translatedGhostty = ghostty_surface_key_translation_mods(
            surface,
            event.modifierFlags.ghosttyMods
        )

        // Ghostty가 반환한 modifier를 NSEvent.ModifierFlags로 복원
        // 단, NSEvent의 hidden bit를 보존하기 위해 개별 플래그만 변경
        var result = event.modifierFlags
        let mapping: [(NSEvent.ModifierFlags, UInt32)] = [
            (.shift, GHOSTTY_MODS_SHIFT.rawValue),
            (.control, GHOSTTY_MODS_CTRL.rawValue),
            (.option, GHOSTTY_MODS_ALT.rawValue),
            (.command, GHOSTTY_MODS_SUPER.rawValue),
        ]
        for (flag, ghosttyFlag) in mapping {
            if translatedGhostty.rawValue & ghosttyFlag != 0 {
                result.insert(flag)
            } else {
                result.remove(flag)
            }
        }
        return result
    }

    /// 키 이벤트와 텍스트를 ghostty_surface_key로 원자적으로 전달
    /// Ghostty 코어가 PRESS/RELEASE 쌍을 올바르게 추적할 수 있도록 보장
    private func sendKeyWithText(
        _ action: ghostty_input_action_e,
        event: NSEvent,
        translationMods: NSEvent.ModifierFlags? = nil,
        text: String? = nil,
        composing: Bool = false
    ) -> Bool {
        guard let surface else { return false }
        var keyEvent = event.ghosttyKeyEvent(
            action: action,
            translationMods: translationMods
        )
        keyEvent.composing = composing

        // 텍스트가 있고 제어문자(< 0x20)가 아니면 키 이벤트에 첨부
        if let text, !text.isEmpty,
           let codepoint = text.utf8.first, codepoint >= 0x20 {
            return text.withCString { ptr in
                keyEvent.text = ptr
                return ghostty_surface_key(surface, keyEvent)
            }
        } else {
            return ghostty_surface_key(surface, keyEvent)
        }
    }

    override func keyUp(with event: NSEvent) {
        guard !blockInputMode else { return }
        guard let surface else { return }
        var keyEvent = event.ghosttyKeyEvent(action: GHOSTTY_ACTION_RELEASE)
        _ = ghostty_surface_key(surface, keyEvent)
    }

    override func flagsChanged(with event: NSEvent) {
        guard let surface else { return }

        // 한글 조합(preedit) 중에는 modifier 이벤트를 무시 — 조합 상태가 깨지는 것 방지
        if hasMarkedText() { return }

        // Modifier 키 변경은 press/release를 구분해야 함
        let action: ghostty_input_action_e = event.modifierFlags.contains(
            Self.modifierForKeyCode(event.keyCode)
        ) ? GHOSTTY_ACTION_PRESS : GHOSTTY_ACTION_RELEASE

        var keyEvent = event.ghosttyKeyEvent(action: action)
        _ = ghostty_surface_key(surface, keyEvent)
    }

    /// keyCode로 해당하는 modifier flag 반환
    private static func modifierForKeyCode(_ keyCode: UInt16) -> NSEvent.ModifierFlags {
        switch keyCode {
        case 56, 60: return .shift       // left/right shift
        case 59, 62: return .control     // left/right control
        case 58, 61: return .option      // left/right option
        case 55, 54: return .command     // left/right command
        case 57:     return .capsLock
        case 63:     return .function
        default:     return []
        }
    }

    // MARK: - Mouse Input

    override func mouseDown(with event: NSEvent) {
        guard let surface else { return }
        let mods = event.modifierFlags.ghosttyMods
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_LEFT, mods)
    }

    override func mouseUp(with event: NSEvent) {
        guard let surface else { return }
        let mods = event.modifierFlags.ghosttyMods
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_LEFT, mods)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let surface else { return super.rightMouseDown(with: event) }
        let mods = event.modifierFlags.ghosttyMods
        // 반환값이 true면 Ghostty 코어가 이벤트를 소비 (마우스 캡처 모드 등)
        if ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_RIGHT, mods) {
            return
        }
        // 소비되지 않으면 AppKit으로 전달 → menu(for:) 호출 → 컨텍스트 메뉴 표시
        super.rightMouseDown(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        guard let surface else { return super.rightMouseUp(with: event) }
        let mods = event.modifierFlags.ghosttyMods
        if ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_RIGHT, mods) {
            return
        }
        super.rightMouseUp(with: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        guard let surface else { return }
        let mods = event.modifierFlags.ghosttyMods
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, event.buttonNumber.ghosttyMouseButton, mods)
    }

    override func otherMouseUp(with event: NSEvent) {
        guard let surface else { return }
        let mods = event.modifierFlags.ghosttyMods
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, event.buttonNumber.ghosttyMouseButton, mods)
    }

    override func otherMouseDragged(with event: NSEvent) {
        mouseMoved(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        guard let surface else { return }
        let pos = convert(event.locationInWindow, from: nil)
        let mods = event.modifierFlags.ghosttyMods
        // Y축 반전: AppKit은 bottom-left, Ghostty는 top-left
        ghostty_surface_mouse_pos(surface, pos.x, frame.height - pos.y, mods)
    }

    override func mouseDragged(with event: NSEvent) {
        mouseMoved(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface else { return }
        // ghostty_input_scroll_mods_t는 packed int: bit 0 = precision
        var scrollMods: ghostty_input_scroll_mods_t = 0
        if event.hasPreciseScrollingDeltas {
            scrollMods |= 0b0000_0001
        }
        ghostty_surface_mouse_scroll(
            surface,
            event.scrollingDeltaX * 2,
            event.scrollingDeltaY * 2,
            scrollMods
        )
    }

    override func mouseEntered(with event: NSEvent) {
        guard let surface else { return }
        let pos = convert(event.locationInWindow, from: nil)
        let mods = event.modifierFlags.ghosttyMods
        ghostty_surface_mouse_pos(surface, pos.x, frame.height - pos.y, mods)
    }

    override func mouseExited(with event: NSEvent) {
        guard let surface else { return }

        // 드래그 중에는 좌표를 리셋하지 않는다 — 뷰 밖으로 드래그해도 선택이 유지됨
        if NSEvent.pressedMouseButtons != 0 { return }

        let mods = event.modifierFlags.ghosttyMods
        ghostty_surface_mouse_pos(surface, -1, -1, mods)
    }

    // MARK: - Context Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        switch event.type {
        case .rightMouseDown:
            break
        case .leftMouseDown:
            // Ctrl+클릭은 마우스 캡처가 비활성일 때만 컨텍스트 메뉴로 처리
            guard event.modifierFlags.contains(.control) else { return nil }
        default:
            return nil
        }

        let menu = NSMenu()

        // 선택 영역이 있으면 복사 항목 추가
        if let selected = readSelectedText(), !selected.isEmpty {
            menu.addItem(withTitle: "복사", action: #selector(copySelection(_:)), keyEquivalent: "")
        }
        menu.addItem(withTitle: "붙여넣기", action: #selector(pasteFromClipboard(_:)), keyEquivalent: "")

        return menu
    }

    @objc private func copySelection(_ sender: Any?) {
        executeAction("copy_to_clipboard")
    }

    @objc private func pasteFromClipboard(_ sender: Any?) {
        executeAction("paste_from_clipboard")
    }

    // MARK: - Drag & Drop

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let validTypes: Set<NSPasteboard.PasteboardType> = [.string, .fileURL, .URL]
        guard let types = sender.draggingPasteboard.types,
              !Set(types).isDisjoint(with: validTypes) else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let surface else { return false }
        let pb = sender.draggingPasteboard

        let text: String
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            // 파일/URL 드롭: 셸 이스케이프 처리
            text = urls.map { url in
                if url.isFileURL {
                    return Self.shellEscape(url.path)
                } else {
                    return url.absoluteString
                }
            }.joined(separator: " ")
        } else if let str = pb.string(forType: .string) {
            // 텍스트 드롭: 그대로 전달
            text = str
        } else {
            return false
        }

        text.withCString { ptr in
            ghostty_surface_text(surface, ptr, UInt(text.utf8.count))
        }
        return true
    }

    /// 셸 특수 문자를 백슬래시로 이스케이프
    private static func shellEscape(_ path: String) -> String {
        var result = ""
        let specialChars: Set<Character> = [" ", "(", ")", "[", "]", "{", "}", "<", ">",
                                             "\"", "'", "`", "!", "#", "$", "&", ";", "|",
                                             "*", "?", "\\", "\t"]
        for char in path {
            if specialChars.contains(char) {
                result.append("\\")
            }
            result.append(char)
        }
        return result
    }

    // MARK: - Text Input

    /// 터미널에 텍스트를 직접 전송한다 (프로그래밍 방식으로 명령 입력 시 사용)
    func sendText(_ text: String) {
        guard let surface else { return }
        text.withCString { ptr in
            ghostty_surface_text(surface, ptr, UInt(text.utf8.count))
        }
        // 블록 모드에서는 커서를 숨기기 위해 unfocus 유지
        if blockInputMode { setFocusState(false) }
    }

    /// macOS 하드웨어 키코드로 키를 press+release 전송
    /// - keyCode: macOS 키코드 (36=Enter, 48=Tab 등)
    /// - char: 해당 키의 문자 (unshifted codepoint용)
    func sendKeyPress(keyCode: UInt32, char: String = "", mods: ghostty_input_mods_e = GHOSTTY_MODS_NONE) {
        guard let surface else { return }

        let codepoint = char.unicodeScalars.first?.value ?? 0

        // Press
        var event = ghostty_input_key_s()
        event.action = GHOSTTY_ACTION_PRESS
        event.mods = mods
        event.keycode = keyCode
        event.text = nil
        event.unshifted_codepoint = codepoint
        event.composing = false
        _ = ghostty_surface_key(surface, event)

        // Release
        event.action = GHOSTTY_ACTION_RELEASE
        _ = ghostty_surface_key(surface, event)

        // 블록 모드에서는 커서를 숨기기 위해 unfocus 유지
        if blockInputMode { setFocusState(false) }
    }

    // MARK: - Binding Actions

    /// Ghostty 내장 액션 실행 (예: "increase_font_size:1", "reset_font_size")
    @discardableResult
    func executeAction(_ action: String) -> Bool {
        guard let surface else { return false }
        return action.withCString { ptr in
            ghostty_surface_binding_action(surface, ptr, UInt(action.utf8.count))
        }
    }

    // MARK: - Text Reading (스크롤백 복원 인프라)

    /// 선택 영역의 텍스트를 읽는다 (향후 스크롤백 저장/복원에 사용)
    /// 현재는 ghostty_surface_read_selection을 통해 선택된 텍스트만 읽을 수 있음
    /// 전체 스크롤백 버퍼 읽기는 ghostty API 확장이 필요하여 향후 구현 예정
    func readSelectedText() -> String? {
        guard let surface else { return nil }
        var text = ghostty_text_s()
        guard ghostty_surface_read_selection(surface, &text) else { return nil }
        defer { ghostty_surface_free_text(surface, &text) }
        guard let data = text.text else { return nil }
        return String(cString: data)
    }

    // MARK: - Cursor Shape

    /// Ghostty 코어가 요청한 커서 모양으로 변경
    func setCursorShape(_ shape: ghostty_action_mouse_shape_e) {
        let cursor: NSCursor
        switch shape {
        case GHOSTTY_MOUSE_SHAPE_TEXT:
            cursor = .iBeam
        case GHOSTTY_MOUSE_SHAPE_POINTER:
            cursor = .pointingHand
        case GHOSTTY_MOUSE_SHAPE_EW_RESIZE:
            cursor = .resizeLeftRight
        case GHOSTTY_MOUSE_SHAPE_NS_RESIZE:
            cursor = .resizeUpDown
        case GHOSTTY_MOUSE_SHAPE_NOT_ALLOWED:
            cursor = .operationNotAllowed
        case GHOSTTY_MOUSE_SHAPE_CROSSHAIR:
            cursor = .crosshair
        default:
            cursor = .iBeam  // 터미널에서는 기본이 I-beam
        }
        // 다음 resetCursorRects에서 적용되도록 캐시
        currentCursor = cursor
        window?.invalidateCursorRects(for: self)
    }

    private var currentCursor: NSCursor = .iBeam

    // MARK: - Cleanup

    /// Surface 리소스 해제
    func close() {
        guard let surface else { return }
        GeobukLogger.debug(.terminal, "Surface closed", context: ["viewId": viewId.uuidString])
        ghostty_surface_free(surface)
        self.surface = nil
    }

    /// Surface 닫기 요청 (프로세스가 실행 중이면 확인 필요할 수 있음)
    func requestClose() {
        guard let surface else { return }
        ghostty_surface_request_close(surface)
    }

    // MARK: - NSTextInputClient (IME 지원)

    func insertText(_ string: Any, replacementRange: NSRange) {
        guard NSApp.currentEvent != nil else { return }

        let chars: String
        switch string {
        case let v as NSAttributedString: chars = v.string
        case let v as String: chars = v
        default: return
        }

        // insertText → preedit 종료
        unmarkText()

        // keyDown 중이면 accumulate, 아니면 직접 전달
        if keyTextAccumulator != nil {
            keyTextAccumulator?.append(chars)
        } else {
            guard let surface else { return }
            chars.withCString { ptr in
                ghostty_surface_text(surface, ptr, UInt(chars.utf8.count))
            }
        }
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        switch string {
        case let v as NSAttributedString:
            markedText = NSMutableAttributedString(attributedString: v)
        case let v as String:
            markedText = NSMutableAttributedString(string: v)
        default: return
        }

        // keyDown 밖에서 호출되면 즉시 preedit 동기화 (입력기 전환 등)
        if keyTextAccumulator == nil {
            syncPreedit()
        }
    }

    func unmarkText() {
        if markedText.length > 0 {
            markedText.mutableString.setString("")
            syncPreedit()
        }
    }

    func selectedRange() -> NSRange {
        guard let surface else { return NSRange() }
        var text = ghostty_text_s()
        guard ghostty_surface_read_selection(surface, &text) else { return NSRange() }
        defer { ghostty_surface_free_text(surface, &text) }
        return NSRange(location: Int(text.offset_start), length: Int(text.offset_len))
    }

    func markedRange() -> NSRange {
        if markedText.length > 0 {
            return NSRange(location: 0, length: markedText.length)
        }
        return NSRange(location: NSNotFound, length: 0)
    }

    func hasMarkedText() -> Bool { markedText.length > 0 }

    /// marked text ↔ ghostty_surface_preedit 동기화 (Ghostty 패턴)
    private func syncPreedit(clearIfNeeded: Bool = true) {
        guard let surface else { return }

        if markedText.length > 0 {
            let str = markedText.string
            str.withCString { ptr in
                // utf8CString은 null terminator 포함, -1로 제외
                ghostty_surface_preedit(surface, ptr, UInt(max(str.utf8CString.count - 1, 0)))
            }
        } else if clearIfNeeded {
            ghostty_surface_preedit(surface, nil, 0)
        }
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        guard let surface else { return nil }
        guard range.length > 0 else { return nil }
        var text = ghostty_text_s()
        guard ghostty_surface_read_selection(surface, &text) else { return nil }
        defer { ghostty_surface_free_text(surface, &text) }

        var attributes: [NSAttributedString.Key: Any] = [:]
        if let fontRaw = ghostty_surface_quicklook_font(surface) {
            let font = Unmanaged<CTFont>.fromOpaque(fontRaw)
            attributes[.font] = font.takeUnretainedValue()
            font.release()
        }
        return NSAttributedString(string: String(cString: text.text), attributes: attributes)
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] { [] }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let surface else { return .zero }
        var x: Double = 0, y: Double = 0, w: Double = 0, h: Double = 0
        ghostty_surface_ime_point(surface, &x, &y, &w, &h)
        let viewPoint = NSPoint(x: x, y: frame.height - y)
        guard let window else { return NSRect(origin: viewPoint, size: NSSize(width: w, height: h)) }
        let windowPoint = convert(viewPoint, to: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)
        return NSRect(origin: screenPoint, size: NSSize(width: w, height: h))
    }

    func characterIndex(for point: NSPoint) -> Int {
        NSNotFound
    }
}
