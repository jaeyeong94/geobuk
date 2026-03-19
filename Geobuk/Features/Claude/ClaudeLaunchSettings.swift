import Foundation
import Observation

/// 모델 선택 옵션
struct ModelOption: Identifiable, Hashable {
    let id: String    // alias (sonnet, opus, haiku)
    let label: String // 표시 이름 (Claude Sonnet 4.6 ($3/$15))
}

/// Claude Code 실행 시 전달할 플래그를 관리하는 설정 모델
/// Cmd+, 설정 팝오버에서 사용자가 토글/선택할 수 있다
@MainActor
@Observable
final class ClaudeLaunchSettings {
    // MARK: - 토글 플래그

    /// 브라우저 통합 (--chrome)
    var chrome: Bool = true

    /// 모든 권한 스킵 (--dangerously-skip-permissions)
    var dangerouslySkipPermissions: Bool = false

    /// 상세 출력 (--verbose)
    var verbose: Bool = false

    /// 이전 대화 이어가기 (--continue)
    var continueSession: Bool = false

    /// Git worktree 격리 (--worktree)
    var worktree: Bool = false

    // MARK: - 선택 플래그

    /// 사용할 모델 (sonnet, opus, haiku)
    var model: String = "sonnet"

    /// 추론 노력 수준 (low, medium, high, max)
    var effort: String = "high"

    /// 권한 모드 (default, acceptEdits, bypassPermissions, plan, auto)
    var permissionMode: String = "default"

    // MARK: - 유효 옵션 목록

    /// 가격 매니저 참조 (동적 모델 목록용)
    var pricingManager: ClaudePricingManager?

    /// 선택 가능한 모델 목록 (가격 매니저에서 동적으로 로드, fallback 하드코딩)
    var availableModels: [ModelOption] {
        if let pm = pricingManager, !pm.pricing.isEmpty {
            return pm.pricing.values
                .sorted { $0.outputPerMTok > $1.outputPerMTok } // 비싼 순
                .map { ModelOption(id: modelNameToAlias($0.modelName), label: "\($0.modelName) ($\(Int($0.inputPerMTok))/$\(Int($0.outputPerMTok)))") }
        }
        return Self.defaultModels
    }

    /// 기본 모델 목록 (fallback)
    static let defaultModels: [ModelOption] = [
        ModelOption(id: "opus", label: "Opus ($5/$25)"),
        ModelOption(id: "sonnet", label: "Sonnet ($3/$15)"),
        ModelOption(id: "haiku", label: "Haiku ($1/$5)"),
    ]

    /// 선택 가능한 effort 목록
    static let availableEfforts = ["low", "medium", "high", "max"]

    /// 선택 가능한 권한 모드 목록
    static let availablePermissionModes = ["default", "acceptEdits", "bypassPermissions", "plan", "auto"]

    /// 모델 이름 → alias 변환 (Claude Sonnet 4.6 → sonnet)
    private func modelNameToAlias(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("opus") { return "opus" }
        if lower.contains("sonnet") { return "sonnet" }
        if lower.contains("haiku") { return "haiku" }
        return lower.replacingOccurrences(of: "claude ", with: "").replacingOccurrences(of: " ", with: "-")
    }

    // MARK: - 커맨드 빌드

    /// 선택된 플래그로 claude 명령어를 생성한다
    func buildCommand() -> String {
        var parts = ["claude"]
        if chrome { parts.append("--chrome") }
        if dangerouslySkipPermissions { parts.append("--dangerously-skip-permissions") }
        if verbose { parts.append("--verbose") }
        if continueSession { parts.append("--continue") }
        if worktree { parts.append("--worktree") }
        parts.append("--model \(model)")
        parts.append("--effort \(effort)")
        if permissionMode != "default" { parts.append("--permission-mode \(permissionMode)") }
        parts.append("--output-format stream-json")
        return parts.joined(separator: " ")
    }
}
