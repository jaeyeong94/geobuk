import Foundation
import Observation

/// Claude Code 세션의 PTY 출력을 모니터링하여 상태를 추적하는 클래스
/// StreamJSONParser(actor)와 ClaudeSessionState(@Observable)를 연결한다
@MainActor
@Observable
final class ClaudeSessionMonitor {
    /// 단일 세션 상태 (하위 호환용)
    let sessionState: ClaudeSessionState

    /// 세션별 독립 상태 (sessionId → state)
    private(set) var sessionStates: [String: ClaudeSessionState] = [:]

    /// 세션별 모델 이름
    private(set) var sessionModels: [String: String] = [:]

    /// 세션별 마지막 턴 소요 시간 (ms)
    private(set) var sessionTurnDurations: [String: Int] = [:]

    /// 세션별 Git 브랜치
    private(set) var sessionBranches: [String: String] = [:]

    /// 세션이 실행 중인 패널의 surfaceViewId (sessionId → surfaceViewId)
    private(set) var sessionSurfaceIds: [String: String] = [:]

    /// 모니터링 중인 surfaceViewId 목록
    private var monitoredSurfaceIds: Set<UUID> = []

    /// 가격 매니저
    var pricingManager: ClaudePricingManager?

    /// 감지된 모델 이름
    private(set) var detectedModel: String?

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
        GeobukLogger.info(.claude, "Monitoring started")
    }

    /// surface의 PTY 로그 파일을 통해 모니터링 시작
    func monitor(surfaceViewId: UUID) {
        let logPath = PTYLogManager.logPath(for: surfaceViewId)
        let tailer = PTYLogTailer(filePath: logPath)
        tailers[surfaceViewId] = tailer
        monitoredSurfaceIds.insert(surfaceViewId)

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
        GeobukLogger.info(.claude, "Monitoring stopped")
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

    /// Claude 트랜스크립트 JSONL 이벤트를 처리한다 (세션별 독립 상태)
    func processTranscriptEvent(_ event: [String: Any], sessionId: String? = nil) {
        guard let type = event["type"] as? String else { return }

        if !isMonitoring {
            startMonitoring()
        }

        // 세션 ID 결정
        let sid = sessionId ?? event["sessionId"] as? String ?? "unknown"

        // 세션별 상태 가져오기 (없으면 생성)
        let state: ClaudeSessionState
        if let existing = sessionStates[sid] {
            state = existing
        } else {
            let newState = ClaudeSessionState()
            sessionStates[sid] = newState
            state = newState
        }

        // 세션 ID 설정
        if state.sessionId == nil {
            state.processEvent(.sessionInit(sessionId: sid))
        }

        // Git 브랜치 추출 (모든 이벤트에 포함)
        if let branch = event["gitBranch"] as? String, !branch.isEmpty {
            sessionBranches[sid] = branch
        }

        // 단일 상태도 마지막 활성 세션으로 업데이트 (하위 호환)
        let _ = { self.sessionState.processEvent(.sessionInit(sessionId: sid)) }()

        GeobukLogger.debug(.claude, "Event processed", context: ["sessionId": sid, "type": type])

        switch type {
        case "user":
            // 사용자가 프롬프트를 제출함 → 응답 대기 (세션 활성화)
            state.processEvent(.sessionInit(sessionId: sid))

        case "assistant":
            if let message = event["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {
                for block in content {
                    if let blockType = block["type"] as? String {
                        switch blockType {
                        case "thinking":
                            // 생각 중 → Responding 상태
                            state.processEvent(.assistantMessage(text: "(thinking...)"))
                        case "text":
                            let text = block["text"] as? String ?? ""
                            state.processEvent(.assistantMessage(text: text))
                        case "tool_use":
                            let name = block["name"] as? String ?? ""
                            let id = block["id"] as? String ?? ""
                            state.processEvent(.toolUse(id: id, name: name, input: ""))
                        case "tool_result":
                            let id = block["tool_use_id"] as? String ?? ""
                            state.processEvent(.toolResult(id: id, content: ""))
                        default:
                            break
                        }
                    }
                }
            }

            // 모델 감지
            if let message = event["message"] as? [String: Any],
               let model = message["model"] as? String {
                detectedModel = model
                sessionModels[sid] = model
                GeobukLogger.info(.claude, "Model detected", context: ["sessionId": sid, "model": model])
            }

            // 토큰 사용량
            let usage: [String: Any]? =
                (event["message"] as? [String: Any])?["usage"] as? [String: Any]
                ?? event["usage"] as? [String: Any]

            if let usage {
                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                let cacheWrite = usage["cache_creation_input_tokens"] as? Int ?? 0
                state.processEvent(.usage(inputTokens: input + cacheRead + cacheWrite, outputTokens: output))

                let model = sessionModels[sid] ?? detectedModel
                if let pricing = pricingManager, let model {
                    state.useExternalPricing = true
                    let cost = pricing.calculateCost(
                        model: model,
                        inputTokens: input,
                        outputTokens: output,
                        cacheReadTokens: cacheRead,
                        cacheWriteTokens: cacheWrite
                    )
                    state.addCost(cost)
                    GeobukLogger.debug(.claude, "Cost calculated", context: ["sessionId": sid, "model": model, "cost": String(format: "%.6f", cost), "inputTokens": "\(input)", "outputTokens": "\(output)"])
                }
            }

        case "result":
            if let subtype = event["subtype"] as? String {
                switch subtype {
                case "tool_result":
                    let id = event["toolUseID"] as? String ?? ""
                    state.processEvent(.toolResult(id: id, content: ""))
                case "success", "error":
                    state.processEvent(.result(text: subtype))
                default:
                    break
                }
            }

        case "system":
            if let subtype = event["subtype"] as? String {
                switch subtype {
                case "turn_duration":
                    // 턴 소요 시간 기록
                    if let durationMs = event["durationMs"] as? Int {
                        sessionTurnDurations[sid] = durationMs
                    }
                    // 턴 완료 → 입력 대기 상태
                    state.processEvent(.permissionRequest(toolName: ""))
                case "stop_hook_summary":
                    // stop hook 실행 완료 → 세션 종료/대기
                    state.processEvent(.result(text: "complete"))
                default:
                    break
                }
            }

        default:
            break
        }
    }

    /// 특정 세션의 상태 조회
    func getState(for sessionId: String) -> ClaudeSessionState? {
        sessionStates[sessionId]
    }

    /// 종료된 세션 정리
    func removeSession(_ sessionId: String) {
        sessionStates.removeValue(forKey: sessionId)
        sessionModels.removeValue(forKey: sessionId)
        sessionTurnDurations.removeValue(forKey: sessionId)
        sessionBranches.removeValue(forKey: sessionId)
    }
}
