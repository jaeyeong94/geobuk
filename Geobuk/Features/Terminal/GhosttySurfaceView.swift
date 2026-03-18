import AppKit

/// libghostty의 Metal 렌더링 터미널 surface를 호스팅하는 NSView
/// ghostty_surface_t를 생성하고 키보드/마우스 이벤트를 전달
@MainActor
final class GhosttySurfaceView: NSView, @preconcurrency NSTextInputClient {
    // MARK: - Properties

    nonisolated(unsafe) private var surface: ghostty_surface_t?
    private weak var ghosttyApp: GhosttyApp?

    /// IME marked text (한글 조합 등)
    private var markedText = NSMutableAttributedString()

    /// keyDown 중 insertText로부터 누적된 텍스트 (nil = keyDown 밖)
    private var keyTextAccumulator: [String]?

    /// surface 존재 여부
    var hasSurface: Bool { surface != nil }

    /// C surface 핸들 (클립보드 콜백 등에서 사용)
    var surfaceHandle: ghostty_surface_t? { surface }

    // MARK: - Initialization

    /// GhosttyApp으로부터 새 surface 생성
    init(app: GhosttyApp, cwd: String? = nil, command: String? = nil) {
        self.ghosttyApp = app
        super.init(frame: .zero)

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

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        // Surface 해제는 반드시 main thread에서
        if let surface {
            ghostty_surface_free(surface)
        }
    }

    // MARK: - View Lifecycle

    override var acceptsFirstResponder: Bool { true }

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
    }

    // MARK: - Cleanup

    /// Surface 리소스 해제
    func close() {
        guard let surface else { return }
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
