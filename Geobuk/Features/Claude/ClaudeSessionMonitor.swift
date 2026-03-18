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

    /// surfaceViewId -> PTYLogTailer 매핑
    private var tailers: [UUID: PTYLogTailer] = [:]

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

    /// surface의 PTY 로그 파일을 통해 모니터링 시작
    func monitor(surfaceViewId: UUID) {
        let logPath = PTYLogManager.logPath(for: surfaceViewId)
        let tailer = PTYLogTailer(filePath: logPath)
        tailers[surfaceViewId] = tailer

        startMonitoring()

        Task {
            await tailer.startTailing { [weak self] data in
                guard let self else { return }
                Task { @MainActor in
                    await self.feedData(data)
                }
            }
        }
    }

    /// 특정 surface 모니터링 중지
    func stopMonitoring(surfaceViewId: UUID) {
        if let tailer = tailers.removeValue(forKey: surfaceViewId) {
            Task { await tailer.stopTailing() }
        }
        PTYLogManager.cleanup(paneId: surfaceViewId)

        if tailers.isEmpty {
            stopMonitoring()
        }
    }

    /// 모든 모니터링 중지
    func stopAll() {
        for (id, tailer) in tailers {
            Task { await tailer.stopTailing() }
            PTYLogManager.cleanup(paneId: id)
        }
        tailers.removeAll()
        stopMonitoring()
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
    func feedData(_ data: Data) async {
        guard !isStopped else { return }

        let events = await parser.feed(data)
        for event in events {
            sessionState.processEvent(event)
        }
    }

    // MARK: - 트랜스크립트 이벤트 처리

    /// Claude 트랜스크립트 JSONL 이벤트를 처리한다
    /// stream-json과 다른 포맷이므로 변환하여 sessionState에 전달
    func processTranscriptEvent(_ event: [String: Any]) {
        guard let type = event["type"] as? String else { return }

        if !isMonitoring {
            startMonitoring()
        }

        // 세션 ID 설정
        if let sessionId = event["sessionId"] as? String,
           sessionState.sessionId == nil {
            sessionState.processEvent(.sessionInit(sessionId: sessionId))
        }

        switch type {
        case "user":
            // 사용자 입력 → 세션 활성
            sessionState.processEvent(.sessionInit(sessionId: event["sessionId"] as? String ?? ""))

        case "assistant":
            // Claude 응답
            if let message = event["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {
                for block in content {
                    if let blockType = block["type"] as? String {
                        switch blockType {
                        case "text":
                            let text = block["text"] as? String ?? ""
                            sessionState.processEvent(.assistantMessage(text: text))

                        case "tool_use":
                            let name = block["name"] as? String ?? ""
                            let id = block["id"] as? String ?? ""
                            sessionState.processEvent(.toolUse(id: id, name: name, input: ""))

                        case "tool_result":
                            let id = block["tool_use_id"] as? String ?? ""
                            sessionState.processEvent(.toolResult(id: id, content: ""))

                        default:
                            break
                        }
                    }
                }
            }

            // 토큰 사용량
            if let usage = event["usage"] as? [String: Any] {
                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                sessionState.processEvent(.usage(inputTokens: input, outputTokens: output))
            }

        case "result":
            if let subtype = event["subtype"] as? String {
                switch subtype {
                case "tool_result":
                    let id = event["toolUseID"] as? String ?? ""
                    sessionState.processEvent(.toolResult(id: id, content: ""))
                case "success", "error":
                    sessionState.processEvent(.result(text: subtype))
                default:
                    break
                }
            }

        case "system":
            if let subtype = event["subtype"] as? String, subtype == "turn_duration" {
                // 턴 완료 → 다시 대기 상태
                sessionState.processEvent(.result(text: "turn complete"))
            }

        default:
            break
        }
    }
}
