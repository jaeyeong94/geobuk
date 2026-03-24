import Carbon

/// 현재 키보드 입력 소스(레이아웃/IME) 식별자를 제공
/// 한영 전환 감지에 사용: keyDown 전후로 id가 변경되면 IME가 이벤트를 소비한 것
enum KeyboardLayout {
    static var id: String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return unsafeBitCast(ptr, to: CFString.self) as String
    }
}
