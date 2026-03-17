import Foundation

/// AI 세션 상태를 나타내는 열거형
enum AISessionPhase: String, Sendable {
    case idle
    case sessionActive
    case responding
    case toolExecuting
    case toolComplete
    case waitingForInput
    case sessionComplete
}

/// AI 세션 모니터 프로토콜 - Claude 외 다른 AI CLI 확장 가능
protocol AISessionMonitor: AnyObject, Sendable {
    /// 현재 세션 상태
    var phase: AISessionPhase { get }

    /// 현재 사용 중인 도구 이름
    var currentToolName: String? { get }

    /// 누적 토큰 사용량
    var tokenUsage: TokenUsage { get }

    /// 세션 비용 (USD)
    var costUSD: Double { get }

    /// 세션 시작 시각
    var startedAt: Date? { get }
}

/// 토큰 사용량
struct TokenUsage: Sendable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheWriteTokens: Int = 0

    var totalTokens: Int {
        inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens
    }
}
