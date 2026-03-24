import AppKit

// MARK: - NSEvent → ghostty_input_key_s 변환

extension NSEvent {
    /// NSEvent를 ghostty_input_key_s로 변환
    ///
    /// translationMods: Option-as-Alt 등 modifier 변환 시 실제 문자 변환에 사용된 modifier.
    /// nil이면 원본 modifierFlags를 사용한다.
    func ghosttyKeyEvent(
        action: ghostty_input_action_e,
        translationMods: NSEvent.ModifierFlags? = nil
    ) -> ghostty_input_key_s {
        var key = ghostty_input_key_s()
        key.action = action
        key.mods = modifierFlags.ghosttyMods
        key.keycode = UInt32(keyCode)
        key.text = nil
        key.composing = false

        // consumed_mods: 텍스트 생성에 소비된 modifier
        // Control, Command는 텍스트 변환에 기여하지 않으므로 제외
        key.consumed_mods = (translationMods ?? modifierFlags)
            .subtracting([.control, .command])
            .ghosttyMods

        // unshifted codepoint: modifier 없이 적용된 문자의 유니코드 값
        // charactersIgnoringModifiers 대신 byApplyingModifiers를 사용해야
        // Ctrl 누른 상태에서도 올바른 값을 반환함
        key.unshifted_codepoint = 0
        if type == .keyDown || type == .keyUp {
            if let chars = characters(byApplyingModifiers: []),
               let codepoint = chars.unicodeScalars.first {
                key.unshifted_codepoint = codepoint.value
            }
        }

        return key
    }

    /// Ghostty에 전달할 텍스트를 반환
    ///
    /// 제어문자(< 0x20)는 control modifier를 제거한 문자를 반환하고,
    /// PUA 범위(0xF700~0xF8FF, 기능키)는 nil을 반환한다.
    var ghosttyCharacters: String? {
        guard let characters else { return nil }

        if characters.count == 1,
           let scalar = characters.unicodeScalars.first {
            // 제어문자: Ghostty 내부에서 인코딩하므로 control 제거 후 문자 반환
            if scalar.value < 0x20 {
                return self.characters(byApplyingModifiers: modifierFlags.subtracting(.control))
            }
            // PUA 범위(기능키): Ghostty로 보내지 않음
            if scalar.value >= 0xF700 && scalar.value <= 0xF8FF {
                return nil
            }
        }

        return characters
    }
}

// MARK: - NSEvent.buttonNumber → ghostty_mouse_button_e 변환

extension Int {
    /// NSEvent.buttonNumber를 Ghostty 마우스 버튼으로 변환
    var ghosttyMouseButton: ghostty_input_mouse_button_e {
        switch self {
        case 0: return GHOSTTY_MOUSE_LEFT
        case 1: return GHOSTTY_MOUSE_RIGHT
        case 2: return GHOSTTY_MOUSE_MIDDLE
        case 3: return GHOSTTY_MOUSE_EIGHT
        case 4: return GHOSTTY_MOUSE_NINE
        case 5: return GHOSTTY_MOUSE_SIX
        case 6: return GHOSTTY_MOUSE_SEVEN
        case 7: return GHOSTTY_MOUSE_FOUR
        case 8: return GHOSTTY_MOUSE_FIVE
        case 9: return GHOSTTY_MOUSE_TEN
        case 10: return GHOSTTY_MOUSE_ELEVEN
        default: return GHOSTTY_MOUSE_UNKNOWN
        }
    }
}

// MARK: - NSEvent.ModifierFlags → ghostty_input_mods_e 변환

extension NSEvent.ModifierFlags {
    /// macOS modifier flags를 Ghostty modifier flags로 변환
    var ghosttyMods: ghostty_input_mods_e {
        var mods = GHOSTTY_MODS_NONE.rawValue

        if contains(.shift) { mods |= GHOSTTY_MODS_SHIFT.rawValue }
        if contains(.control) { mods |= GHOSTTY_MODS_CTRL.rawValue }
        if contains(.option) { mods |= GHOSTTY_MODS_ALT.rawValue }
        if contains(.command) { mods |= GHOSTTY_MODS_SUPER.rawValue }
        if contains(.capsLock) { mods |= GHOSTTY_MODS_CAPS.rawValue }

        return ghostty_input_mods_e(rawValue: mods)
    }
}
