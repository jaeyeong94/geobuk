import AppKit

/// 터미널 렌더러 프로토콜 - libghostty와 SwiftTerm 폴백을 동일 인터페이스로 추상화
protocol TerminalRenderer: AnyObject {
    /// 렌더러가 사용하는 NSView
    var surfaceView: NSView { get }

    /// 터미널 크기 설정 (columns x rows)
    func resize(columns: UInt16, rows: UInt16)

    /// 포커스 상태 변경
    func setFocus(_ focused: Bool)

    /// 콘텐츠 스케일 팩터 설정 (Retina 지원)
    func setContentScale(_ scaleX: Double, _ scaleY: Double)

    /// 키 입력 전달 - 처리 여부 반환
    func handleKey(_ event: NSEvent) -> Bool

    /// 텍스트 입력 전달
    func insertText(_ text: String)

    /// 리소스 정리
    func destroy()
}
