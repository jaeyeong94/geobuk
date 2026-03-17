import Foundation
import Observation

/// Claude Code 세션의 상태를 관리하는 클래스
/// stream-json 이벤트를 받아 상태 머신을 구동하고, 토큰 사용량/비용을 추적한다
///
/// @MainActor 컨텍스트에서 사용하도록 설계되었으나,
/// AISessionMonitor 프로토콜(Sendable) 준수를 위해 클래스 수준 격리를 적용하지 않는다.
/// 호출부에서 MainActor 격리를 보장해야 한다.
@Observable
final class ClaudeSessionState: AISessionMonitor, @unchecked Sendable {
    // MARK: - 상태 머신

    /// 현재 세션 단계
    private(set) var phase: AISessionPhase = .idle

    // MARK: - 세션 정보

    /// 세션 ID
    private(set) var sessionId: String?

    /// 현재 실행 중인 도구 이름
    private(set) var currentToolName: String?

    /// 누적 토큰 사용량
    private(set) var tokenUsage: TokenUsage = TokenUsage()

    /// 세션 비용 (USD)
    private(set) var costUSD: Double = 0

    /// 세션 시작 시각
    private(set) var startedAt: Date?

    /// 경과 시간
    private(set) var elapsedTime: TimeInterval = 0

    // MARK: - 팀 정보

    /// 팀원 상태 목록 (Agent Team 모니터링용)
    private(set) var teammates: [TeammateState] = []

    // MARK: - 비용 계산 상수 (USD per token)

    /// Claude 모델 토큰 단가
    private enum Pricing {
        static let inputPerToken: Double = 3.0 / 1_000_000.0
        static let outputPerToken: Double = 15.0 / 1_000_000.0
        static let cacheReadPerToken: Double = 0.30 / 1_000_000.0
        static let cacheWritePerToken: Double = 3.75 / 1_000_000.0
    }

    // MARK: - 이벤트 처리

    /// stream-json 이벤트를 받아 상태를 갱신한다
    func processEvent(_ event: StreamJSONEvent) {
        switch event {
        case .sessionInit(let sid):
            phase = .sessionActive
            sessionId = sid
            startedAt = Date()

        case .assistantMessage:
            guard phase != .idle else { return }
            phase = .responding

        case .toolUse(_, let name, _):
            guard phase != .idle else { return }
            phase = .toolExecuting
            currentToolName = name

        case .toolResult:
            guard phase != .idle else { return }
            phase = .responding
            currentToolName = nil

        case .permissionRequest(let toolName):
            guard phase != .idle else { return }
            phase = .waitingForInput
            currentToolName = toolName

        case .result:
            guard phase != .idle else { return }
            phase = .sessionComplete

        case .usage(let inputTokens, let outputTokens):
            tokenUsage.inputTokens += inputTokens
            tokenUsage.outputTokens += outputTokens
            recalculateCost()

        case .unknown:
            break
        }
    }

    /// 모든 상태를 초기값으로 되돌린다
    func reset() {
        phase = .idle
        sessionId = nil
        currentToolName = nil
        tokenUsage = TokenUsage()
        costUSD = 0
        startedAt = nil
        elapsedTime = 0
        teammates = []
    }

    // MARK: - Private

    /// 현재 토큰 사용량 기반으로 비용을 재계산한다
    private func recalculateCost() {
        costUSD = Double(tokenUsage.inputTokens) * Pricing.inputPerToken
            + Double(tokenUsage.outputTokens) * Pricing.outputPerToken
            + Double(tokenUsage.cacheReadTokens) * Pricing.cacheReadPerToken
            + Double(tokenUsage.cacheWriteTokens) * Pricing.cacheWritePerToken
    }
}

/// 팀원 상태
struct TeammateState: Identifiable, Sendable {
    let id: String
    var name: String
    var phase: AISessionPhase
    var currentTool: String?
    var tokenUsage: TokenUsage
}
