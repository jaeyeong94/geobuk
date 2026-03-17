import AppKit

// MARK: - NSEvent → ghostty_input_key_s 변환

extension NSEvent {
    /// NSEvent를 ghostty_input_key_s로 변환
    func ghosttyKeyEvent(action: ghostty_input_action_e) -> ghostty_input_key_s {
        var key = ghostty_input_key_s()
        key.action = action
        key.mods = modifierFlags.ghosttyMods
        key.consumed_mods = GHOSTTY_MODS_NONE
        key.keycode = UInt32(keyCode)
        key.text = nil
        key.unshifted_codepoint = 0
        key.composing = false

        // unshifted codepoint: characters without modifiers의 첫 유니코드 값
        if let chars = charactersIgnoringModifiers, let scalar = chars.unicodeScalars.first {
            key.unshifted_codepoint = scalar.value
        }

        return key
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
