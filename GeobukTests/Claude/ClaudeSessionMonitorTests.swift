import Testing
import Foundation
@testable import Geobuk

@Suite("ClaudeSessionMonitor")
struct ClaudeSessionMonitorTests {

    // MARK: - 단위 테스트 (Unit Tests)

    @Test("초기상태_모니터링안함")
    @MainActor
    func initialState_notMonitoring() {
        let monitor = ClaudeSessionMonitor()
        #expect(monitor.isMonitoring == false)
        #expect(monitor.sessionState.phase == .idle)
    }

    @Test("feedData_유효한initJSON_상태갱신")
    @MainActor
    func feedData_validInitJSON_updatesState() async {
        let monitor = ClaudeSessionMonitor()
        let json = "{\"type\":\"system\",\"subtype\":\"init\",\"session_id\":\"sess-001\",\"tools\":[]}\n"
        await monitor.feedData(Data(json.utf8))
        #expect(monitor.sessionState.phase == .sessionActive)
        #expect(monitor.sessionState.sessionId == "sess-001")
    }

    @Test("feedData_복수이벤트_순차상태갱신")
    @MainActor
    func feedData_multipleEvents_updatesStateSequentially() async {
        let monitor = ClaudeSessionMonitor()
        let json = """
        {"type":"system","subtype":"init","session_id":"s1","tools":[]}
        {"type":"assistant","subtype":"text","text":"Hello"}
        {"type":"assistant","subtype":"tool_use","id":"tu-1","name":"Edit","input":{}}

        """
        await monitor.feedData(Data(json.utf8))
        #expect(monitor.sessionState.phase == .toolExecuting)
        #expect(monitor.sessionState.currentToolName == "Edit")
    }

    @Test("feedData_usage이벤트_토큰비용갱신")
    @MainActor
    func feedData_usageEvent_updatesTokensAndCost() async {
        let monitor = ClaudeSessionMonitor()
        let json = """
        {"type":"system","subtype":"init","session_id":"s1","tools":[]}
        {"type":"result","subtype":"success","result":"done","usage":{"input_tokens":1000,"output_tokens":500}}

        """
        await monitor.feedData(Data(json.utf8))
        #expect(monitor.sessionState.tokenUsage.inputTokens == 1000)
        #expect(monitor.sessionState.tokenUsage.outputTokens == 500)
        #expect(monitor.sessionState.costUSD > 0)
    }

    @Test("startMonitoring_isMonitoringTrue")
    @MainActor
    func startMonitoring_setsIsMonitoring() {
        let monitor = ClaudeSessionMonitor()
        monitor.startMonitoring()
        #expect(monitor.isMonitoring == true)
    }

    @Test("stopMonitoring_isMonitoringFalse")
    @MainActor
    func stopMonitoring_setsIsMonitoringFalse() {
        let monitor = ClaudeSessionMonitor()
        monitor.startMonitoring()
        monitor.stopMonitoring()
        #expect(monitor.isMonitoring == false)
    }

    @Test("stopMonitoring_상태리셋")
    @MainActor
    func stopMonitoring_resetsState() async {
        let monitor = ClaudeSessionMonitor()
        let json = "{\"type\":\"system\",\"subtype\":\"init\",\"session_id\":\"s1\",\"tools\":[]}\n"
        await monitor.feedData(Data(json.utf8))
        monitor.stopMonitoring()
        #expect(monitor.sessionState.phase == .idle)
    }

    @Test("feedData_stopMonitoring후_데이터무시")
    @MainActor
    func feedData_afterStopMonitoring_ignoresData() async {
        let monitor = ClaudeSessionMonitor()
        monitor.startMonitoring()
        monitor.stopMonitoring()
        let json = "{\"type\":\"system\",\"subtype\":\"init\",\"session_id\":\"s1\",\"tools\":[]}\n"
        await monitor.feedData(Data(json.utf8))
        #expect(monitor.sessionState.phase == .idle)
    }

    // MARK: - 네거티브 테스트 (Negative Tests)

    @Test("feedData_비JSON데이터_크래시없음_상태불변")
    @MainActor
    func feedData_nonJSONData_noCrashNoStateChange() async {
        let monitor = ClaudeSessionMonitor()
        monitor.startMonitoring()
        let data = "This is regular terminal output\nAnother line\n"
        await monitor.feedData(Data(data.utf8))
        #expect(monitor.sessionState.phase == .idle)
    }

    @Test("feedData_빈데이터_크래시없음")
    @MainActor
    func feedData_emptyData_noCrash() async {
        let monitor = ClaudeSessionMonitor()
        monitor.startMonitoring()
        await monitor.feedData(Data())
        #expect(monitor.sessionState.phase == .idle)
    }

    @Test("feedData_잘못된JSON_크래시없음_상태불변")
    @MainActor
    func feedData_malformedJSON_noCrashNoStateChange() async {
        let monitor = ClaudeSessionMonitor()
        monitor.startMonitoring()
        let data = "{broken json\n{\"also broken\n"
        await monitor.feedData(Data(data.utf8))
        #expect(monitor.sessionState.phase == .idle)
    }

    @Test("feedData_부분데이터_버퍼링후완성시처리")
    @MainActor
    func feedData_partialData_bufferedUntilComplete() async {
        let monitor = ClaudeSessionMonitor()
        monitor.startMonitoring()
        // First chunk without newline
        let part1 = "{\"type\":\"system\",\"subtype\":\"init\""
        await monitor.feedData(Data(part1.utf8))
        #expect(monitor.sessionState.phase == .idle) // Not yet processed

        // Complete the line
        let part2 = ",\"session_id\":\"s1\",\"tools\":[]}\n"
        await monitor.feedData(Data(part2.utf8))
        #expect(monitor.sessionState.phase == .sessionActive)
    }

    // MARK: - 퍼징 테스트 (Fuzz Tests)

    @Test("feedData_랜덤바이트_크래시없음")
    @MainActor
    func feedData_randomBytes_doesNotCrash() async {
        let monitor = ClaudeSessionMonitor()
        monitor.startMonitoring()
        for _ in 0..<50 {
            let size = Int.random(in: 0...512)
            var bytes = [UInt8](repeating: 0, count: size)
            for i in 0..<size {
                bytes[i] = UInt8.random(in: 0...255)
            }
            await monitor.feedData(Data(bytes))
        }
        // No crash = pass
    }

    @Test("feedData_JSON과터미널출력혼재_JSON만처리")
    @MainActor
    func feedData_mixedJSONAndTerminal_onlyProcessesJSON() async {
        let monitor = ClaudeSessionMonitor()
        monitor.startMonitoring()
        let data = """
        \u{1b}[32mSome terminal escape\u{1b}[0m
        {"type":"system","subtype":"init","session_id":"s1","tools":[]}
        Regular text output
        {"type":"assistant","subtype":"text","text":"hi"}

        """
        await monitor.feedData(Data(data.utf8))
        #expect(monitor.sessionState.phase == .responding)
    }
}
