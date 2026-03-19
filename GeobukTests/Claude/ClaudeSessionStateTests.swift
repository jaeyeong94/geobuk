import Testing
import Foundation
@testable import Geobuk

@Suite("ClaudeSessionState")
struct ClaudeSessionStateTests {

    // MARK: - 단위 테스트 (Unit Tests)

    @Test("초기상태_idle")
    func initialState_isIdle() {
        let state = ClaudeSessionState()
        #expect(state.phase == .idle)
        #expect(state.sessionId == nil)
        #expect(state.currentToolName == nil)
        #expect(state.tokenUsage.totalTokens == 0)
        #expect(state.costUSD == 0)
        #expect(state.startedAt == nil)
    }

    @Test("processEvent_init이벤트_sessionActive로전환")
    func processEvent_initEvent_transitionsToSessionActive() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "sess-001"))
        #expect(state.phase == .sessionActive)
        #expect(state.sessionId == "sess-001")
        #expect(state.startedAt != nil)
    }

    @Test("processEvent_assistantText_responding으로전환")
    func processEvent_assistantText_transitionsToResponding() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "s1"))
        state.processEvent(.assistantMessage(text: "Hello"))
        #expect(state.phase == .responding)
    }

    @Test("processEvent_toolUse_toolExecuting으로전환_도구명설정")
    func processEvent_toolUse_transitionsToToolExecutingWithToolName() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "s1"))
        state.processEvent(.toolUse(id: "tu-1", name: "Edit", input: "{}"))
        #expect(state.phase == .toolExecuting)
        #expect(state.currentToolName == "Edit")
    }

    @Test("processEvent_toolResult_responding으로전환")
    func processEvent_toolResult_transitionsToResponding() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "s1"))
        state.processEvent(.toolUse(id: "tu-1", name: "Edit", input: "{}"))
        state.processEvent(.toolResult(id: "tu-1", content: "ok"))
        #expect(state.phase == .responding)
        #expect(state.currentToolName == nil)
    }

    @Test("processEvent_permissionRequest_waitingForInput으로전환")
    func processEvent_permissionRequest_transitionsToWaitingForInput() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "s1"))
        state.processEvent(.permissionRequest(toolName: "Bash"))
        #expect(state.phase == .waitingForInput)
        #expect(state.currentToolName == "Bash")
    }

    @Test("processEvent_resultSuccess_sessionComplete로전환")
    func processEvent_resultSuccess_transitionsToSessionComplete() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "s1"))
        state.processEvent(.assistantMessage(text: "done"))
        state.processEvent(.result(text: "All done"))
        #expect(state.phase == .sessionComplete)
    }

    @Test("processEvent_usage_토큰사용량누적")
    func processEvent_usage_accumulatesTokenUsage() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "s1"))
        state.processEvent(.usage(inputTokens: 100, outputTokens: 200))
        #expect(state.tokenUsage.inputTokens == 100)
        #expect(state.tokenUsage.outputTokens == 200)
    }

    @Test("processEvent_usage_여러번_누적됨")
    func processEvent_multipleUsage_accumulates() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "s1"))
        state.processEvent(.usage(inputTokens: 100, outputTokens: 200))
        state.processEvent(.usage(inputTokens: 50, outputTokens: 100))
        #expect(state.tokenUsage.inputTokens == 150)
        #expect(state.tokenUsage.outputTokens == 300)
    }

    @Test("processEvent_usage_비용정확히계산")
    func processEvent_usage_calculatesCorrectCost() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "s1"))
        // Input: 1,000,000 tokens * $3/MTok = $3.00
        // Output: 1,000,000 tokens * $15/MTok = $15.00
        state.processEvent(.usage(inputTokens: 1_000_000, outputTokens: 1_000_000))
        #expect(state.costUSD == 18.0)
    }

    @Test("processEvent_usage_소량토큰_비용정확")
    func processEvent_usage_smallTokens_accurateCost() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "s1"))
        // Input: 100 tokens * $3/1M = $0.0003
        // Output: 200 tokens * $15/1M = $0.003
        state.processEvent(.usage(inputTokens: 100, outputTokens: 200))
        let expectedCost = (100.0 * 3.0 / 1_000_000.0) + (200.0 * 15.0 / 1_000_000.0)
        #expect(abs(state.costUSD - expectedCost) < 0.000001)
    }

    @Test("reset_전체상태초기화")
    func reset_clearsAllState() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "s1"))
        state.processEvent(.toolUse(id: "tu-1", name: "Edit", input: "{}"))
        state.processEvent(.usage(inputTokens: 100, outputTokens: 200))
        state.reset()
        #expect(state.phase == .idle)
        #expect(state.sessionId == nil)
        #expect(state.currentToolName == nil)
        #expect(state.tokenUsage.totalTokens == 0)
        #expect(state.costUSD == 0)
        #expect(state.startedAt == nil)
    }

    // MARK: - 네거티브 테스트 (Negative Tests)

    @Test("processEvent_idle상태에서toolResult_무시")
    func processEvent_toolResultInIdleState_ignored() {
        let state = ClaudeSessionState()
        state.processEvent(.toolResult(id: "tu-1", content: "ok"))
        #expect(state.phase == .idle)
    }

    @Test("processEvent_idle상태에서assistantMessage_무시")
    func processEvent_assistantMessageInIdleState_ignored() {
        let state = ClaudeSessionState()
        state.processEvent(.assistantMessage(text: "hello"))
        #expect(state.phase == .idle)
    }

    @Test("processEvent_unknown이벤트_상태변경없음")
    func processEvent_unknownEvent_noStateChange() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "s1"))
        state.processEvent(.unknown(type: "custom", raw: "{}"))
        #expect(state.phase == .sessionActive)
    }

    @Test("processEvent_복수세션_리셋사이정상동작")
    func processEvent_multipleSessions_workCorrectlyBetweenResets() {
        let state = ClaudeSessionState()
        // First session
        state.processEvent(.sessionInit(sessionId: "s1"))
        state.processEvent(.usage(inputTokens: 100, outputTokens: 50))
        state.processEvent(.result(text: "done"))
        #expect(state.phase == .sessionComplete)

        // Reset
        state.reset()
        #expect(state.phase == .idle)
        #expect(state.tokenUsage.totalTokens == 0)

        // Second session
        state.processEvent(.sessionInit(sessionId: "s2"))
        #expect(state.sessionId == "s2")
        #expect(state.phase == .sessionActive)
        #expect(state.tokenUsage.totalTokens == 0)
    }

    @Test("processEvent_toolUse연속_최신도구명유지")
    func processEvent_consecutiveToolUse_keepsLatestToolName() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "s1"))
        state.processEvent(.toolUse(id: "tu-1", name: "Edit", input: "{}"))
        state.processEvent(.toolResult(id: "tu-1", content: "ok"))
        state.processEvent(.toolUse(id: "tu-2", name: "Bash", input: "{}"))
        #expect(state.currentToolName == "Bash")
        #expect(state.phase == .toolExecuting)
    }

    // MARK: - AISessionMonitor 준수 테스트

    @Test("AISessionMonitor준수_프로퍼티접근가능")
    func conformsToAISessionMonitor() {
        let state = ClaudeSessionState()
        let monitor: any AISessionMonitor = state
        #expect(monitor.phase == .idle)
        #expect(monitor.currentToolName == nil)
        #expect(monitor.tokenUsage.totalTokens == 0)
        #expect(monitor.costUSD == 0)
        #expect(monitor.startedAt == nil)
    }

    // MARK: - 퍼징 테스트 (Fuzz Tests)

    @Test("processEvent_랜덤이벤트시퀀스_크래시없음")
    func processEvent_randomEventSequence_doesNotCrash() {
        let state = ClaudeSessionState()
        let events: [StreamJSONEvent] = [
            .sessionInit(sessionId: "fuzz"),
            .assistantMessage(text: "msg"),
            .toolUse(id: "t1", name: "Edit", input: "{}"),
            .toolResult(id: "t1", content: "ok"),
            .permissionRequest(toolName: "Bash"),
            .result(text: "done"),
            .usage(inputTokens: 10, outputTokens: 20),
            .unknown(type: "x", raw: "{}")
        ]
        for _ in 0..<200 {
            let event = events.randomElement()!
            state.processEvent(event)
        }
        // If we get here, no crash occurred
    }

    @Test("processEvent_usage_제로토큰_비용0")
    func processEvent_usage_zeroTokens_zeroCost() {
        let state = ClaudeSessionState()
        state.processEvent(.sessionInit(sessionId: "s1"))
        state.processEvent(.usage(inputTokens: 0, outputTokens: 0))
        #expect(state.costUSD == 0)
    }
}
