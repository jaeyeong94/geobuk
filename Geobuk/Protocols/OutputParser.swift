import Foundation

/// 출력 파서가 방출하는 이벤트
enum ParsedEvent: Sendable {
    /// stream-json 이벤트 (Claude --output-format stream-json)
    case streamJSON(StreamJSONEvent)

    /// OSC 이스케이프 시퀀스
    case osc(OSCEvent)

    /// 일반 텍스트 출력
    case text(String)
}

/// stream-json 이벤트 타입
enum StreamJSONEvent: Sendable {
    case sessionInit(sessionId: String)
    case assistantMessage(text: String)
    case toolUse(id: String, name: String, input: String)
    case toolResult(id: String, content: String)
    case permissionRequest(toolName: String)
    case result(text: String)
    case usage(inputTokens: Int, outputTokens: Int)
    case unknown(type: String, raw: String)
}

/// OSC 이벤트 타입
enum OSCEvent: Sendable {
    case notification(title: String, body: String)  // OSC 9/99
    case desktopNotification(title: String, body: String)  // OSC 777
    case setTitle(String)  // OSC 0/2
}

/// 출력 파서 프로토콜 - PTY 출력을 구조화된 이벤트로 변환
protocol OutputParser: AnyObject, Sendable {
    /// 바이트 데이터를 파싱하여 이벤트 스트림 생성
    func parse(_ data: Data) -> [ParsedEvent]

    /// 파서 상태 초기화
    func reset()
}
