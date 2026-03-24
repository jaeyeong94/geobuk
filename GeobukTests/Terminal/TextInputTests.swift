import Testing
import AppKit
@testable import Geobuk

// MARK: - 1. ghosttyCharacters (PUA/제어문자 필터링)

@Suite("NSEvent+ghosttyCharacters")
struct GhosttyCharactersTests {

    // MARK: 정상 경로

    @Test("일반문자_그대로반환")
    func normalCharacter_returnsAsIs() {
        let event = Self.makeKeyEvent(characters: "a")
        #expect(event.ghosttyCharacters == "a")
    }

    @Test("한글문자_그대로반환")
    func koreanCharacter_returnsAsIs() {
        let event = Self.makeKeyEvent(characters: "한")
        #expect(event.ghosttyCharacters == "한")
    }

    @Test("여러문자_그대로반환")
    func multipleCharacters_returnsAsIs() {
        let event = Self.makeKeyEvent(characters: "abc")
        #expect(event.ghosttyCharacters == "abc")
    }

    @Test("스페이스_0x20_그대로반환")
    func space_0x20_returnsAsIs() {
        let event = Self.makeKeyEvent(characters: " ")
        #expect(event.ghosttyCharacters == " ")
    }

    // MARK: 네거티브 — PUA 필터링

    @Test("PUA시작_기능키_nil반환")
    func puaStart_functionKey_returnsNil() {
        // F1 = 0xF704
        let event = Self.makeKeyEvent(characters: String(UnicodeScalar(0xF704)!))
        #expect(event.ghosttyCharacters == nil)
    }

    @Test("PUA끝_기능키_nil반환")
    func puaEnd_functionKey_returnsNil() {
        let event = Self.makeKeyEvent(characters: String(UnicodeScalar(0xF8FF)!))
        #expect(event.ghosttyCharacters == nil)
    }

    @Test("PUA경계직전_정상반환")
    func justBeforePua_returnsNormally() {
        let event = Self.makeKeyEvent(characters: String(UnicodeScalar(0xF6FF)!))
        #expect(event.ghosttyCharacters != nil)
    }

    // MARK: 네거티브 — 제어문자 필터링

    @Test("제어문자_nil이아닌값반환")
    func controlCharacter_returnsNonNil() {
        let event = Self.makeKeyEvent(
            characters: String(UnicodeScalar(0x01)!),
            modifiers: .control
        )
        let result = event.ghosttyCharacters
        #expect(result != nil)
    }

    // MARK: Helper

    private static func makeKeyEvent(
        characters: String,
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: 0
        )!
    }
}

// MARK: - 2. ghosttyKeyEvent translationMods & consumed_mods

@Suite("NSEvent+ghosttyKeyEvent")
struct GhosttyKeyEventTests {

    @Test("기본호출_consumed_mods_control제외")
    func defaultCall_consumedMods_excludesControl() {
        let event = Self.makeKeyEvent(modifiers: [.shift, .control])
        let keyEvent = event.ghosttyKeyEvent(action: GHOSTTY_ACTION_PRESS)
        let hasCtrl = (keyEvent.consumed_mods.rawValue & GHOSTTY_MODS_CTRL.rawValue) != 0
        #expect(hasCtrl == false)
    }

    @Test("기본호출_consumed_mods_command제외")
    func defaultCall_consumedMods_excludesCommand() {
        let event = Self.makeKeyEvent(modifiers: [.command])
        let keyEvent = event.ghosttyKeyEvent(action: GHOSTTY_ACTION_PRESS)
        let hasCmd = (keyEvent.consumed_mods.rawValue & GHOSTTY_MODS_SUPER.rawValue) != 0
        #expect(hasCmd == false)
    }

    @Test("기본호출_consumed_mods_shift포함")
    func defaultCall_consumedMods_includesShift() {
        let event = Self.makeKeyEvent(modifiers: [.shift])
        let keyEvent = event.ghosttyKeyEvent(action: GHOSTTY_ACTION_PRESS)
        let hasShift = (keyEvent.consumed_mods.rawValue & GHOSTTY_MODS_SHIFT.rawValue) != 0
        #expect(hasShift == true)
    }

    @Test("translationMods_option제거_consumed에Alt없음")
    func translationMods_optionRemoved_noAltInConsumed() {
        let event = Self.makeKeyEvent(modifiers: [.option])
        let keyEvent = event.ghosttyKeyEvent(
            action: GHOSTTY_ACTION_PRESS,
            translationMods: []
        )
        let hasAlt = (keyEvent.consumed_mods.rawValue & GHOSTTY_MODS_ALT.rawValue) != 0
        #expect(hasAlt == false)
    }

    @Test("translationMods_option유지_consumed에Alt있음")
    func translationMods_optionKept_altInConsumed() {
        let event = Self.makeKeyEvent(modifiers: [.option])
        let keyEvent = event.ghosttyKeyEvent(
            action: GHOSTTY_ACTION_PRESS,
            translationMods: [.option]
        )
        let hasAlt = (keyEvent.consumed_mods.rawValue & GHOSTTY_MODS_ALT.rawValue) != 0
        #expect(hasAlt == true)
    }

    @Test("mods_원본modifier유지")
    func mods_preservesOriginalModifiers() {
        let event = Self.makeKeyEvent(modifiers: [.option, .shift])
        let keyEvent = event.ghosttyKeyEvent(
            action: GHOSTTY_ACTION_PRESS,
            translationMods: [.shift]
        )
        let hasAlt = (keyEvent.mods.rawValue & GHOSTTY_MODS_ALT.rawValue) != 0
        let hasShift = (keyEvent.mods.rawValue & GHOSTTY_MODS_SHIFT.rawValue) != 0
        #expect(hasAlt == true)
        #expect(hasShift == true)
    }

    // MARK: Helper

    private static func makeKeyEvent(
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        )!
    }
}

// MARK: - 3. 키보드 레이아웃 전환 감지

@Suite("KeyboardLayout")
struct KeyboardLayoutTests {

    @Test("id_현재레이아웃_nil아님")
    func id_currentLayout_notNil() {
        let layoutId = KeyboardLayout.id
        #expect(layoutId != nil)
    }

    @Test("id_문자열_비어있지않음")
    func id_string_notEmpty() {
        if let layoutId = KeyboardLayout.id {
            #expect(!layoutId.isEmpty)
        }
    }

    @Test("id_연속호출_동일값")
    func id_consecutiveCalls_sameValue() {
        let first = KeyboardLayout.id
        let second = KeyboardLayout.id
        #expect(first == second)
    }
}

// MARK: - 4. 우클릭 컨텍스트 메뉴
// 주의: GhosttyApp 초기화가 필요한 통합 테스트는 테스트 러너 크래시 위험이 있어
// SurfaceViewTests.swift의 기존 패턴을 따라 별도 실행

@Suite("GhosttySurfaceView 컨텍스트 메뉴")
struct ContextMenuTests {

    @Test("menu_우클릭_메뉴반환")
    @MainActor
    func menu_rightClick_returnsMenu() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let view = GhosttySurfaceView(app: app)
        defer { view.close() }

        let event = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        )!

        let menu = view.menu(for: event)
        #expect(menu != nil)
    }

    @Test("menu_우클릭_붙여넣기항목포함")
    @MainActor
    func menu_rightClick_containsPaste() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let view = GhosttySurfaceView(app: app)
        defer { view.close() }

        let event = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        )!

        let menu = view.menu(for: event)
        let pasteItem = menu?.items.first { $0.title == "붙여넣기" }
        #expect(pasteItem != nil)
    }

    @Test("menu_좌클릭_nil반환")
    @MainActor
    func menu_leftClick_returnsNil() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let view = GhosttySurfaceView(app: app)
        defer { view.close() }

        let event = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        )!

        let menu = view.menu(for: event)
        #expect(menu == nil)
    }

    @Test("menu_Ctrl좌클릭_메뉴반환")
    @MainActor
    func menu_ctrlLeftClick_returnsMenu() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let view = GhosttySurfaceView(app: app)
        defer { view.close() }

        let event = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: .zero,
            modifierFlags: [.control],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        )!

        let menu = view.menu(for: event)
        #expect(menu != nil)
    }
}
