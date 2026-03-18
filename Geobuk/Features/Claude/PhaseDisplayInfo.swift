import Foundation

/// AI 세션 단계의 표시 정보를 제공하는 구조체
struct PhaseDisplayInfo: Sendable {
    let label: String
    let systemImage: String
    let colorName: String

    /// AISessionPhase에 대응하는 표시 정보를 반환한다
    static func from(phase: AISessionPhase) -> PhaseDisplayInfo {
        switch phase {
        case .idle:
            return PhaseDisplayInfo(
                label: "Idle",
                systemImage: "circle",
                colorName: "gray"
            )
        case .sessionActive:
            return PhaseDisplayInfo(
                label: "Session Active",
                systemImage: "circle.fill",
                colorName: "green"
            )
        case .responding:
            return PhaseDisplayInfo(
                label: "Responding",
                systemImage: "circle.fill",
                colorName: "green"
            )
        case .toolExecuting:
            return PhaseDisplayInfo(
                label: "Tool Executing",
                systemImage: "circle.fill",
                colorName: "blue"
            )
        case .toolComplete:
            return PhaseDisplayInfo(
                label: "Tool Complete",
                systemImage: "circle.fill",
                colorName: "blue"
            )
        case .waitingForInput:
            return PhaseDisplayInfo(
                label: "Waiting for Input",
                systemImage: "exclamationmark.circle.fill",
                colorName: "yellow"
            )
        case .sessionComplete:
            return PhaseDisplayInfo(
                label: "Complete",
                systemImage: "checkmark.circle",
                colorName: "gray"
            )
        }
    }
}
