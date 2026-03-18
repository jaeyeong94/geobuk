import Testing
import Foundation
@testable import Geobuk

@Suite("ClaudeLaunchSettings")
struct ClaudeLaunchSettingsTests {

    // MARK: - 단위 테스트 (Unit Tests)

    @Test("초기상태_기본값_올바르게설정")
    func initialState_hasCorrectDefaults() {
        let settings = ClaudeLaunchSettings()
        #expect(settings.chrome == true)
        #expect(settings.dangerouslySkipPermissions == false)
        #expect(settings.verbose == false)
        #expect(settings.continueSession == false)
        #expect(settings.worktree == false)
        #expect(settings.model == "sonnet")
        #expect(settings.effort == "high")
        #expect(settings.permissionMode == "default")
    }

    @Test("buildCommand_기본값_outputFormatStreamJson포함")
    func buildCommand_defaults_includesOutputFormat() {
        let settings = ClaudeLaunchSettings()
        let command = settings.buildCommand()
        #expect(command.contains("--output-format stream-json"))
    }

    @Test("buildCommand_기본값_claude로시작")
    func buildCommand_defaults_startsWithClaude() {
        let settings = ClaudeLaunchSettings()
        let command = settings.buildCommand()
        #expect(command.hasPrefix("claude"))
    }

    @Test("buildCommand_chrome활성_chromeFlag포함")
    func buildCommand_chromeEnabled_includesChromeFlag() {
        let settings = ClaudeLaunchSettings()
        settings.chrome = true
        let command = settings.buildCommand()
        #expect(command.contains("--chrome"))
    }

    @Test("buildCommand_chrome비활성_chromeFlag미포함")
    func buildCommand_chromeDisabled_excludesChromeFlag() {
        let settings = ClaudeLaunchSettings()
        settings.chrome = false
        let command = settings.buildCommand()
        #expect(!command.contains("--chrome"))
    }

    @Test("buildCommand_dangerouslySkipPermissions활성_flag포함")
    func buildCommand_dangerouslySkipPermissionsEnabled_includesFlag() {
        let settings = ClaudeLaunchSettings()
        settings.dangerouslySkipPermissions = true
        let command = settings.buildCommand()
        #expect(command.contains("--dangerously-skip-permissions"))
    }

    @Test("buildCommand_verbose활성_flag포함")
    func buildCommand_verboseEnabled_includesFlag() {
        let settings = ClaudeLaunchSettings()
        settings.verbose = true
        let command = settings.buildCommand()
        #expect(command.contains("--verbose"))
    }

    @Test("buildCommand_continue활성_flag포함")
    func buildCommand_continueEnabled_includesFlag() {
        let settings = ClaudeLaunchSettings()
        settings.continueSession = true
        let command = settings.buildCommand()
        #expect(command.contains("--continue"))
    }

    @Test("buildCommand_worktree활성_flag포함")
    func buildCommand_worktreeEnabled_includesFlag() {
        let settings = ClaudeLaunchSettings()
        settings.worktree = true
        let command = settings.buildCommand()
        #expect(command.contains("--worktree"))
    }

    @Test("buildCommand_모델설정_올바르게반영")
    func buildCommand_modelSelection_reflectedCorrectly() {
        let settings = ClaudeLaunchSettings()
        settings.model = "opus"
        let command = settings.buildCommand()
        #expect(command.contains("--model opus"))
    }

    @Test("buildCommand_effort설정_올바르게반영")
    func buildCommand_effortSelection_reflectedCorrectly() {
        let settings = ClaudeLaunchSettings()
        settings.effort = "low"
        let command = settings.buildCommand()
        #expect(command.contains("--effort low"))
    }

    @Test("buildCommand_permissionMode_default_flag미포함")
    func buildCommand_permissionModeDefault_excludesFlag() {
        let settings = ClaudeLaunchSettings()
        settings.permissionMode = "default"
        let command = settings.buildCommand()
        #expect(!command.contains("--permission-mode"))
    }

    @Test("buildCommand_permissionMode_nonDefault_flag포함")
    func buildCommand_permissionModeNonDefault_includesFlag() {
        let settings = ClaudeLaunchSettings()
        settings.permissionMode = "acceptEdits"
        let command = settings.buildCommand()
        #expect(command.contains("--permission-mode acceptEdits"))
    }

    @Test("buildCommand_모든토글활성_전체flag포함")
    func buildCommand_allTogglesEnabled_includesAllFlags() {
        let settings = ClaudeLaunchSettings()
        settings.chrome = true
        settings.dangerouslySkipPermissions = true
        settings.verbose = true
        settings.continueSession = true
        settings.worktree = true
        settings.model = "haiku"
        settings.effort = "max"
        settings.permissionMode = "bypassPermissions"

        let command = settings.buildCommand()
        #expect(command.contains("--chrome"))
        #expect(command.contains("--dangerously-skip-permissions"))
        #expect(command.contains("--verbose"))
        #expect(command.contains("--continue"))
        #expect(command.contains("--worktree"))
        #expect(command.contains("--model haiku"))
        #expect(command.contains("--effort max"))
        #expect(command.contains("--permission-mode bypassPermissions"))
        #expect(command.contains("--output-format stream-json"))
    }

    @Test("buildCommand_모든토글비활성_최소flag만포함")
    func buildCommand_allTogglesDisabled_onlyMinimalFlags() {
        let settings = ClaudeLaunchSettings()
        settings.chrome = false
        settings.dangerouslySkipPermissions = false
        settings.verbose = false
        settings.continueSession = false
        settings.worktree = false
        settings.permissionMode = "default"

        let command = settings.buildCommand()
        #expect(!command.contains("--chrome"))
        #expect(!command.contains("--dangerously-skip-permissions"))
        #expect(!command.contains("--verbose"))
        #expect(!command.contains("--continue"))
        #expect(!command.contains("--worktree"))
        #expect(!command.contains("--permission-mode"))
        #expect(command.contains("claude"))
        #expect(command.contains("--model"))
        #expect(command.contains("--effort"))
        #expect(command.contains("--output-format stream-json"))
    }

    // MARK: - 네거티브 테스트 (Negative Tests)

    @Test("buildCommand_결과_중복공백없음")
    func buildCommand_result_noDoubleSpaces() {
        let settings = ClaudeLaunchSettings()
        settings.chrome = false
        settings.dangerouslySkipPermissions = false
        settings.verbose = false
        settings.continueSession = false
        settings.worktree = false
        let command = settings.buildCommand()
        #expect(!command.contains("  "))
    }

    @Test("buildCommand_결과_선행후행공백없음")
    func buildCommand_result_noLeadingTrailingSpaces() {
        let settings = ClaudeLaunchSettings()
        let command = settings.buildCommand()
        #expect(command == command.trimmingCharacters(in: .whitespaces))
    }

    // MARK: - 모델/effort/permissionMode 유효값 테스트

    @Test("availableModels_올바른목록반환")
    func availableModels_returnsCorrectList() {
        #expect(ClaudeLaunchSettings.availableModels == ["sonnet", "opus", "haiku"])
    }

    @Test("availableEfforts_올바른목록반환")
    func availableEfforts_returnsCorrectList() {
        #expect(ClaudeLaunchSettings.availableEfforts == ["low", "medium", "high", "max"])
    }

    @Test("availablePermissionModes_올바른목록반환")
    func availablePermissionModes_returnsCorrectList() {
        #expect(ClaudeLaunchSettings.availablePermissionModes == ["default", "acceptEdits", "bypassPermissions", "plan", "auto"])
    }

    // MARK: - 퍼징 테스트 (Fuzz Tests)

    @Test("buildCommand_반복호출_일관된결과")
    func buildCommand_repeatedCalls_consistentResult() {
        let settings = ClaudeLaunchSettings()
        settings.chrome = true
        settings.verbose = true
        settings.model = "opus"
        let first = settings.buildCommand()
        for _ in 0..<100 {
            #expect(settings.buildCommand() == first)
        }
    }

    @Test("buildCommand_모든모델조합_크래시없음")
    func buildCommand_allModelCombinations_noCrash() {
        let settings = ClaudeLaunchSettings()
        let models = ClaudeLaunchSettings.availableModels
        let efforts = ClaudeLaunchSettings.availableEfforts
        let permissions = ClaudeLaunchSettings.availablePermissionModes

        for model in models {
            for effort in efforts {
                for permission in permissions {
                    settings.model = model
                    settings.effort = effort
                    settings.permissionMode = permission
                    let command = settings.buildCommand()
                    #expect(command.hasPrefix("claude"))
                    #expect(command.contains("--output-format stream-json"))
                }
            }
        }
    }

    @Test("buildCommand_토글랜덤변경_크래시없음")
    func buildCommand_randomToggleChanges_noCrash() {
        let settings = ClaudeLaunchSettings()
        for _ in 0..<200 {
            settings.chrome = Bool.random()
            settings.dangerouslySkipPermissions = Bool.random()
            settings.verbose = Bool.random()
            settings.continueSession = Bool.random()
            settings.worktree = Bool.random()
            settings.model = ClaudeLaunchSettings.availableModels.randomElement()!
            settings.effort = ClaudeLaunchSettings.availableEfforts.randomElement()!
            settings.permissionMode = ClaudeLaunchSettings.availablePermissionModes.randomElement()!
            let command = settings.buildCommand()
            #expect(command.hasPrefix("claude"))
            #expect(!command.contains("  "))
        }
    }
}
