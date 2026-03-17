import Testing
@testable import Geobuk

// MARK: - TokenUsage Tests

@Suite("TokenUsage")
struct TokenUsageTests {
    @Test("totalTokens_모든토큰합산_정확한합계반환")
    func totalTokens_sumsAllFields() {
        let usage = TokenUsage(
            inputTokens: 100,
            outputTokens: 200,
            cacheReadTokens: 50,
            cacheWriteTokens: 30
        )
        #expect(usage.totalTokens == 380)
    }

    @Test("totalTokens_모든값0_0반환")
    func totalTokens_allZero_returnsZero() {
        let usage = TokenUsage()
        #expect(usage.totalTokens == 0)
    }

    @Test("totalTokens_큰값_오버플로없음")
    func totalTokens_largeValues_noOverflow() {
        let usage = TokenUsage(
            inputTokens: 1_000_000,
            outputTokens: 1_000_000,
            cacheReadTokens: 500_000,
            cacheWriteTokens: 500_000
        )
        #expect(usage.totalTokens == 3_000_000)
    }
}

// MARK: - AISessionPhase Tests

@Suite("AISessionPhase")
struct AISessionPhaseTests {
    @Test("rawValue_올바른문자열매핑")
    func rawValue_correctMapping() {
        #expect(AISessionPhase.idle.rawValue == "idle")
        #expect(AISessionPhase.sessionActive.rawValue == "sessionActive")
        #expect(AISessionPhase.responding.rawValue == "responding")
        #expect(AISessionPhase.toolExecuting.rawValue == "toolExecuting")
        #expect(AISessionPhase.toolComplete.rawValue == "toolComplete")
        #expect(AISessionPhase.waitingForInput.rawValue == "waitingForInput")
        #expect(AISessionPhase.sessionComplete.rawValue == "sessionComplete")
    }

    @Test("fromRawValue_유효한문자열_인스턴스생성")
    func fromRawValue_validString_createsInstance() {
        let phase = AISessionPhase(rawValue: "responding")
        #expect(phase == .responding)
    }

    @Test("fromRawValue_잘못된문자열_nil반환")
    func fromRawValue_invalidString_returnsNil() {
        let phase = AISessionPhase(rawValue: "invalid")
        #expect(phase == nil)
    }
}
