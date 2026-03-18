import Foundation
import Observation

/// Claude Code 세션의 PTY 출력을 모니터링하여 상태를 추적하는 클래스
/// StreamJSONParser(actor)와 ClaudeSessionState(@Observable)를 연결한다
@MainActor
@Observable
final class ClaudeSessionMonitor {
    /// 세션 상태 (외부에서 UI 바인딩용으로 접근)
    let sessionState: ClaudeSessionState

    /// 현재 모니터링 중인지 여부
    private(set) var isMonitoring: Bool = false

    /// 모니터링이 중지되었는지 여부 (중지 후 데이터 무시용)
    private var isStopped: Bool = false

    /// stream-json 파서 (actor)
    private let parser: StreamJSONParser

    /// 모니터링 태스크
    private var monitorTask: Task<Void, Never>?

    init() {
        self.sessionState = ClaudeSessionState()
        self.parser = StreamJSONParser()
    }

    /// 테스트용: 외부에서 생성한 상태와 파서를 주입
    init(sessionState: ClaudeSessionState, parser: StreamJSONParser) {
        self.sessionState = sessionState
        self.parser = parser
    }

    // MARK: - 모니터링 제어

    /// 모니터링을 시작한다
    func startMonitoring() {
        isMonitoring = true
        isStopped = false
    }

    /// 모니터링을 중지하고 상태를 초기화한다
    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
        isStopped = true
        sessionState.reset()
        Task { await parser.reset() }
    }

    // MARK: - 데이터 입력

    /// 원시 PTY 출력 데이터를 파서에 전달하고 상태를 갱신한다
    /// - Parameter data: PTY에서 읽은 원시 바이트 데이터
    func feedData(_ data: Data) async {
        guard !isStopped else { return }

        let events = await parser.feed(data)
        for event in events {
            sessionState.processEvent(event)
        }
    }
}
