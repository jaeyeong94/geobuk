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

    /// surface 존재 여부
    var hasSurface: Bool { surface != nil }

    /// C surface 핸들 (클립보드 콜백 등에서 사용)
    var surfaceHandle: ghostty_surface_t? { surface }

    // MARK: - Initialization

    /// GhosttyApp으로부터 새 surface 생성
    init(app: GhosttyApp, cwd: String? = nil, command: String? = nil) {
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
            // ZDOTDIR로 커스텀 .zshrc 로드 → 프롬프트 테마 비활성화
            ("ZDOTDIR", BlockModeZshSetup.zdotdir),
        ]

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
        ]

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

        GeobukLogger.debug(.terminal, "Surface created (inherited config)", context: ["viewId": viewId.uuidString])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        // close()에서 이미 해제하고 nil로 설정했으므로 deinit에서는 해제하지 않는다.
        // nonisolated(unsafe) 속성은 다른 스레드에서 nil 상태가 보이지 않을 수 있어
        // double-free 위험이 있다. 호출부에서 반드시 close()를 먼저 호출해야 한다.
    }

    // MARK: - View Lifecycle

    /// 명령 실행 중 (TUI 모드 — 워크스페이스 전환에도 유지)
    var isCommandRunning: Bool = false

    /// 블록 입력창 텍스트 (워크스페이스 전환에도 유지)
    var pendingInputText: String = ""

    /// 명령 제출 후 prompt 대기 중 (500ms 타이머 취소용)
    var pendingCommandSubmitted: Bool = false

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
        // Command 키 조합은 항상 메뉴 시스템으로 전달
        // (Cmd+D → Split, Cmd+T → New Tab, Cmd+W → Close 등)
        if event.modifierFlags.contains(.command) {
            return super.performKeyEquivalent(with: event)
        }
        return false
    }

    override func keyDown(with event: NSEvent) {
        guard !blockInputMode else { return }
        guard let surface else { return }

        // Ghostty 패턴: keyDown 중에만 accumulator 활성화
        keyTextAccumulator = []
        defer { keyTextAccumulator = nil }

        // marked text 상태 기억 (composing 판별용)
        let markedTextBefore = markedText.length > 0

        interpretKeyEvents([event])

        // preedit 동기화 (한글 조합 중 상태 반영)
        syncPreedit(clearIfNeeded: markedTextBefore)

        if let list = keyTextAccumulator, !list.isEmpty {
            // 조합 완료된 텍스트 전달
            for text in list {
                text.withCString { ptr in
                    ghostty_surface_text(surface, ptr, UInt(text.utf8.count))
                }
            }
        } else {
            // 일반 키 이벤트 (화살표, Enter, Backspace 등)
            var keyEvent = event.ghosttyKeyEvent(action: GHOSTTY_ACTION_PRESS)
            keyEvent.composing = markedText.length > 0 || markedTextBefore
            _ = ghostty_surface_key(surface, keyEvent)
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
        guard let surface else { return }
        let mods = event.modifierFlags.ghosttyMods
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_RIGHT, mods)
    }

    override func rightMouseUp(with event: NSEvent) {
        guard let surface else { return }
        let mods = event.modifierFlags.ghosttyMods
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_RIGHT, mods)
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
        let mods = event.modifierFlags.ghosttyMods
        ghostty_surface_mouse_pos(surface, -1, -1, mods)
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
    func executeAction(_ action: String) {
        guard let surface else { return }
        action.withCString { ptr in
            _ = ghostty_surface_binding_action(surface, ptr, UInt(action.utf8.count))
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
        NSRange(location: NSNotFound, length: 0)
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
        nil
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
