import Testing
import Foundation
@testable import Geobuk

@Suite("ClaudeConfigReader - 설정 파일 읽기")
struct ClaudeConfigReaderTests {

    // MARK: - parseSkillFrontmatter (via readConfig/parseSkillFrontmatter 내부 노출 아님 → 간접 테스트)
    // parseSkillFrontmatter는 private이지 않고 internal이므로 @testable import로 접근 가능

    @Test("parseSkillFrontmatter_유효한프론트매터_name파싱됨")
    func parseSkillFrontmatter_validFrontmatter_parsesName() {
        let content = """
        ---
        name: my-skill
        description: Does something useful
        user-invocable: true
        ---
        Body content here
        """
        let (name, _, _) = ClaudeConfigReader.parseSkillFrontmatter_testing(content, fallbackName: "fallback")
        #expect(name == "my-skill")
    }

    @Test("parseSkillFrontmatter_유효한프론트매터_description파싱됨")
    func parseSkillFrontmatter_validFrontmatter_parsesDescription() {
        let content = """
        ---
        name: my-skill
        description: Does something useful
        user-invocable: true
        ---
        Body content here
        """
        let (_, desc, _) = ClaudeConfigReader.parseSkillFrontmatter_testing(content, fallbackName: "fallback")
        #expect(desc == "Does something useful")
    }

    @Test("parseSkillFrontmatter_유효한프론트매터_userInvocableTrue")
    func parseSkillFrontmatter_validFrontmatter_userInvocableTrue() {
        let content = """
        ---
        name: my-skill
        description: Test
        user-invocable: true
        ---
        """
        let (_, _, invocable) = ClaudeConfigReader.parseSkillFrontmatter_testing(content, fallbackName: "fallback")
        #expect(invocable == true)
    }

    @Test("parseSkillFrontmatter_userInvocableFalse_false반환")
    func parseSkillFrontmatter_userInvocableFalse_returnsFalse() {
        let content = """
        ---
        name: my-skill
        description: Test
        user-invocable: false
        ---
        """
        let (_, _, invocable) = ClaudeConfigReader.parseSkillFrontmatter_testing(content, fallbackName: "fallback")
        #expect(invocable == false)
    }

    @Test("parseSkillFrontmatter_프론트매터없음_fallbackName사용")
    func parseSkillFrontmatter_noFrontmatter_usesFallbackName() {
        let content = "Just plain content without frontmatter"
        let (name, _, _) = ClaudeConfigReader.parseSkillFrontmatter_testing(content, fallbackName: "my-fallback")
        #expect(name == "my-fallback")
    }

    @Test("parseSkillFrontmatter_프론트매터없음_description빈문자열")
    func parseSkillFrontmatter_noFrontmatter_emptyDescription() {
        let content = "Just plain content"
        let (_, desc, _) = ClaudeConfigReader.parseSkillFrontmatter_testing(content, fallbackName: "fallback")
        #expect(desc == "")
    }

    @Test("parseSkillFrontmatter_프론트매터없음_invocableFalse")
    func parseSkillFrontmatter_noFrontmatter_invocableFalse() {
        let content = "No frontmatter at all"
        let (_, _, invocable) = ClaudeConfigReader.parseSkillFrontmatter_testing(content, fallbackName: "fallback")
        #expect(invocable == false)
    }

    @Test("parseSkillFrontmatter_빈콘텐츠_fallbackName사용")
    func parseSkillFrontmatter_emptyContent_usesFallbackName() {
        let (name, desc, invocable) = ClaudeConfigReader.parseSkillFrontmatter_testing("", fallbackName: "empty-skill")
        #expect(name == "empty-skill")
        #expect(desc == "")
        #expect(invocable == false)
    }

    @Test("parseSkillFrontmatter_구분자만있음_fallbackName사용")
    func parseSkillFrontmatter_onlyDelimiters_usesFallbackName() {
        let content = "---\n---\n"
        let (name, _, _) = ClaudeConfigReader.parseSkillFrontmatter_testing(content, fallbackName: "only-delimiters")
        #expect(name == "only-delimiters")
    }

    // MARK: - readConfig

    @Test("readConfig_projectDirectoryNil_projectScope비어있음")
    func readConfig_nilProjectDirectory_returnsEmptyProjectScope() {
        let config = ClaudeConfigReader.readConfig(projectDirectory: nil)
        #expect(config.project.settingsRaw == nil)
        #expect(config.project.claudeMd == nil)
        #expect(config.project.rules.isEmpty)
        #expect(config.project.skills.isEmpty)
        #expect(config.project.hooks.isEmpty)
        #expect(config.project.mcpServers.isEmpty)
        #expect(config.project.permissions == nil)
        #expect(config.project.model == nil)
        #expect(config.project.effort == nil)
        #expect(config.project.plugins.isEmpty)
    }

    @Test("readConfig_projectDirectoryNil_globalScope반환됨")
    func readConfig_nilProjectDirectory_globalScopeReturned() {
        let config = ClaudeConfigReader.readConfig(projectDirectory: nil)
        // global scope는 항상 생성됨 (비어있을 수 있지만 nil은 아님)
        // 단순히 크래시 없이 반환되는지 확인
        _ = config.global
    }

    @Test("readConfig_결과_ClaudeConfig타입")
    func readConfig_returns_claudeConfigType() {
        let config = ClaudeConfigReader.readConfig(projectDirectory: nil)
        #expect(config is ClaudeConfigReader.ClaudeConfig)
    }

    // MARK: - ConfigScope 모델

    @Test("ConfigScope_기본빈값_초기화")
    func configScope_defaultEmptyValues_initialization() {
        let scope = ClaudeConfigReader.ConfigScope(
            settingsRaw: nil,
            claudeMd: nil,
            rules: [],
            skills: [],
            hooks: [],
            mcpServers: [],
            permissions: nil,
            model: nil,
            effort: nil,
            plugins: []
        )
        #expect(scope.settingsRaw == nil)
        #expect(scope.claudeMd == nil)
        #expect(scope.rules.isEmpty)
        #expect(scope.skills.isEmpty)
        #expect(scope.hooks.isEmpty)
        #expect(scope.mcpServers.isEmpty)
        #expect(scope.permissions == nil)
        #expect(scope.model == nil)
        #expect(scope.effort == nil)
        #expect(scope.plugins.isEmpty)
    }

    @Test("ConfigScope_값있음_정상초기화")
    func configScope_withValues_initializesCorrectly() {
        let scope = ClaudeConfigReader.ConfigScope(
            settingsRaw: "{\"model\":\"claude-opus\"}",
            claudeMd: "# Instructions",
            rules: [],
            skills: [],
            hooks: [],
            mcpServers: [],
            permissions: nil,
            model: "claude-opus",
            effort: "high",
            plugins: ["plugin-a", "plugin-b"]
        )
        #expect(scope.settingsRaw == "{\"model\":\"claude-opus\"}")
        #expect(scope.claudeMd == "# Instructions")
        #expect(scope.model == "claude-opus")
        #expect(scope.effort == "high")
        #expect(scope.plugins.count == 2)
    }

    // MARK: - RuleFile 모델

    @Test("RuleFile_초기화_프로퍼티정상설정")
    func ruleFile_init_propertiesSetCorrectly() {
        let rule = ClaudeConfigReader.RuleFile(
            name: "coding-style.md",
            content: "# Coding Style\nUse tabs.",
            path: "/home/user/.claude/rules/coding-style.md"
        )
        #expect(rule.name == "coding-style.md")
        #expect(rule.content == "# Coding Style\nUse tabs.")
        #expect(rule.path == "/home/user/.claude/rules/coding-style.md")
    }

    @Test("RuleFile_Identifiable_고유ID생성")
    func ruleFile_identifiable_uniqueId() {
        let rule1 = ClaudeConfigReader.RuleFile(name: "r1.md", content: "", path: "/p1")
        let rule2 = ClaudeConfigReader.RuleFile(name: "r2.md", content: "", path: "/p2")
        #expect(rule1.id != rule2.id)
    }

    // MARK: - SkillInfo 모델

    @Test("SkillInfo_초기화_프로퍼티정상설정")
    func skillInfo_init_propertiesSetCorrectly() {
        let skill = ClaudeConfigReader.SkillInfo(
            name: "autopilot",
            description: "Full autonomous execution",
            isUserInvocable: true,
            path: "/home/.claude/skills/autopilot/SKILL.md"
        )
        #expect(skill.name == "autopilot")
        #expect(skill.description == "Full autonomous execution")
        #expect(skill.isUserInvocable == true)
        #expect(skill.path == "/home/.claude/skills/autopilot/SKILL.md")
    }

    @Test("SkillInfo_Identifiable_고유ID생성")
    func skillInfo_identifiable_uniqueId() {
        let s1 = ClaudeConfigReader.SkillInfo(name: "s1", description: "", isUserInvocable: false, path: "/p1")
        let s2 = ClaudeConfigReader.SkillInfo(name: "s2", description: "", isUserInvocable: false, path: "/p2")
        #expect(s1.id != s2.id)
    }

    // MARK: - HookInfo 모델

    @Test("HookInfo_초기화_프로퍼티정상설정")
    func hookInfo_init_propertiesSetCorrectly() {
        let hook = ClaudeConfigReader.HookInfo(
            event: "PreToolUse",
            matcher: "Bash",
            hookType: "command",
            command: "/usr/local/bin/my-hook.sh"
        )
        #expect(hook.event == "PreToolUse")
        #expect(hook.matcher == "Bash")
        #expect(hook.hookType == "command")
        #expect(hook.command == "/usr/local/bin/my-hook.sh")
    }

    @Test("HookInfo_matcher없음_nil허용")
    func hookInfo_nilMatcher_allowed() {
        let hook = ClaudeConfigReader.HookInfo(
            event: "PostToolUse",
            matcher: nil,
            hookType: "http",
            command: "https://example.com/webhook"
        )
        #expect(hook.matcher == nil)
    }

    @Test("HookInfo_Identifiable_고유ID생성")
    func hookInfo_identifiable_uniqueId() {
        let h1 = ClaudeConfigReader.HookInfo(event: "Pre", matcher: nil, hookType: "command", command: nil)
        let h2 = ClaudeConfigReader.HookInfo(event: "Pre", matcher: nil, hookType: "command", command: nil)
        #expect(h1.id != h2.id)
    }

    // MARK: - MCPServerInfo 모델

    @Test("MCPServerInfo_초기화_프로퍼티정상설정")
    func mcpServerInfo_init_propertiesSetCorrectly() {
        let server = ClaudeConfigReader.MCPServerInfo(
            name: "playwright",
            type: "stdio",
            command: "npx playwright-mcp",
            url: nil,
            isDisabled: false
        )
        #expect(server.name == "playwright")
        #expect(server.type == "stdio")
        #expect(server.command == "npx playwright-mcp")
        #expect(server.url == nil)
        #expect(server.isDisabled == false)
    }

    @Test("MCPServerInfo_sse타입_url설정됨")
    func mcpServerInfo_sseType_urlSet() {
        let server = ClaudeConfigReader.MCPServerInfo(
            name: "remote-server",
            type: "sse",
            command: nil,
            url: "https://mcp.example.com/sse",
            isDisabled: true
        )
        #expect(server.type == "sse")
        #expect(server.url == "https://mcp.example.com/sse")
        #expect(server.command == nil)
        #expect(server.isDisabled == true)
    }

    @Test("MCPServerInfo_Identifiable_고유ID생성")
    func mcpServerInfo_identifiable_uniqueId() {
        let m1 = ClaudeConfigReader.MCPServerInfo(name: "s1", type: "stdio", command: nil, url: nil, isDisabled: false)
        let m2 = ClaudeConfigReader.MCPServerInfo(name: "s2", type: "stdio", command: nil, url: nil, isDisabled: false)
        #expect(m1.id != m2.id)
    }

    // MARK: - PermissionInfo 모델

    @Test("PermissionInfo_초기화_프로퍼티정상설정")
    func permissionInfo_init_propertiesSetCorrectly() {
        let perms = ClaudeConfigReader.PermissionInfo(
            allow: ["Bash", "Read"],
            deny: ["Write"],
            ask: ["Edit"]
        )
        #expect(perms.allow == ["Bash", "Read"])
        #expect(perms.deny == ["Write"])
        #expect(perms.ask == ["Edit"])
    }

    @Test("PermissionInfo_빈배열_허용됨")
    func permissionInfo_emptyArrays_allowed() {
        let perms = ClaudeConfigReader.PermissionInfo(allow: [], deny: [], ask: [])
        #expect(perms.allow.isEmpty)
        #expect(perms.deny.isEmpty)
        #expect(perms.ask.isEmpty)
    }
}

// MARK: - ClaudeConfigReader 테스트 접근자 확장

/// parseSkillFrontmatter는 private이 아닌 internal이지만
/// ClaudeConfigReader가 enum이므로 @testable import로 직접 접근 가능.
/// Swift Testing에서는 extension을 통해 테스트 접근자를 별도로 노출한다.
extension ClaudeConfigReader {
    static func parseSkillFrontmatter_testing(
        _ content: String,
        fallbackName: String
    ) -> (name: String, description: String, isUserInvocable: Bool) {
        parseSkillFrontmatter(content, fallbackName: fallbackName)
    }
}
