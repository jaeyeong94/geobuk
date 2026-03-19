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
            // 최신 모델 우선 (버전 번호 역순), 같으면 비싼 순
            return pm.pricing
                .sorted { $0.key > $1.key }
                .map { ModelOption(
                    id: $0.key,  // claude-opus-4-6 등 실제 API ID
                    label: "\($0.value.modelName) ($\(formatPrice($0.value.inputPerMTok))/$\(formatPrice($0.value.outputPerMTok)))"
                )}
        }
        return Self.defaultModels
    }

    /// 기본 모델 목록 (fallback)
    static let defaultModels: [ModelOption] = [
        ModelOption(id: "opus", label: "Claude Opus ($5/$25)"),
        ModelOption(id: "sonnet", label: "Claude Sonnet ($3/$15)"),
        ModelOption(id: "haiku", label: "Claude Haiku ($1/$5)"),
    ]

    private func formatPrice(_ price: Double) -> String {
        price == Double(Int(price)) ? "\(Int(price))" : String(format: "%.2f", price)
    }

    /// 선택 가능한 effort 목록
    static let availableEfforts = ["low", "medium", "high", "max"]

    /// 선택 가능한 권한 모드 목록
    static let availablePermissionModes = ["default", "acceptEdits", "bypassPermissions", "plan", "auto"]

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
