import Foundation

/// Claude Code 설정 파일 읽기 유틸리티
enum ClaudeConfigReader {

    // MARK: - Models

    struct ClaudeConfig: Sendable {
        let global: ConfigScope
        let project: ConfigScope
    }

    struct ConfigScope: Sendable {
        /// settings.json 원본 (표시용 raw JSON 문자열)
        let settingsRaw: String?
        let claudeMd: String?
        let rules: [RuleFile]
        let skills: [SkillInfo]
        let hooks: [HookInfo]
        let mcpServers: [MCPServerInfo]
        let permissions: PermissionInfo?
        /// settings.json에서 파싱한 모델 이름
        let model: String?
        /// settings.json에서 파싱한 effort 값
        let effort: String?
        /// 활성화된 플러그인 목록
        let plugins: [String]
    }

    struct RuleFile: Identifiable, Sendable {
        let id = UUID()
        let name: String
        let content: String
        let path: String
    }

    struct SkillInfo: Identifiable, Sendable {
        let id = UUID()
        let name: String
        let description: String
        let isUserInvocable: Bool
        let path: String
    }

    struct HookInfo: Identifiable, Sendable {
        let id = UUID()
        let event: String    // "PreToolUse", "PostToolUse" 등
        let matcher: String?
        let hookType: String // "command", "http" 등
        let command: String?
    }

    struct MCPServerInfo: Identifiable, Sendable {
        let id = UUID()
        let name: String
        let type: String   // "stdio", "sse", "http"
        let command: String?
        let url: String?
        let isDisabled: Bool
    }

    struct PermissionInfo: Sendable {
        let allow: [String]
        let deny: [String]
        let ask: [String]
    }

    // MARK: - Read Config

    /// 글로벌 + 프로젝트 설정을 모두 읽는다
    static func readConfig(projectDirectory: String?) -> ClaudeConfig {
        let global = readScope(
            baseDir: NSHomeDirectory() + "/.claude",
            claudeMdPaths: [NSHomeDirectory() + "/.claude/CLAUDE.md"],
            mcpPath: NSHomeDirectory() + "/.claude/.mcp.json"
        )

        let project: ConfigScope
        if let dir = projectDirectory {
            let gitRoot = findGitRoot(from: dir) ?? dir
            project = readScope(
                baseDir: gitRoot + "/.claude",
                claudeMdPaths: [
                    gitRoot + "/.claude/CLAUDE.md",
                    gitRoot + "/CLAUDE.md"
                ],
                mcpPath: gitRoot + "/.mcp.json"
            )
        } else {
            project = ConfigScope(
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
        }

        return ClaudeConfig(global: global, project: project)
    }

    // MARK: - Private

    private static func readScope(baseDir: String, claudeMdPaths: [String], mcpPath: String) -> ConfigScope {
        let fm = FileManager.default

        // settings.json (raw JSON 문자열 + 파싱)
        let settingsPath = baseDir + "/settings.json"
        let settingsRaw: String?
        let settingsDict: [String: Any]?
        if let data = fm.contents(atPath: settingsPath) {
            settingsRaw = String(data: data, encoding: .utf8)
            settingsDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } else {
            settingsRaw = nil
            settingsDict = nil
        }

        // CLAUDE.md (처음 발견된 파일 사용)
        let claudeMd = claudeMdPaths.compactMap { path -> String? in
            guard fm.fileExists(atPath: path) else { return nil }
            return try? String(contentsOfFile: path, encoding: .utf8)
        }.first

        // Rules
        let rulesDir = baseDir + "/rules"
        var rules: [RuleFile] = []
        if let files = try? fm.contentsOfDirectory(atPath: rulesDir) {
            for file in files.sorted() where file.hasSuffix(".md") {
                let path = rulesDir + "/" + file
                let content = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
                rules.append(RuleFile(name: file, content: content, path: path))
            }
        }

        // Skills
        let skillsDir = baseDir + "/skills"
        var skills: [SkillInfo] = []
        if let dirs = try? fm.contentsOfDirectory(atPath: skillsDir) {
            for dir in dirs.sorted() {
                let skillMdPath = skillsDir + "/" + dir + "/SKILL.md"
                guard fm.fileExists(atPath: skillMdPath) else { continue }
                let content = (try? String(contentsOfFile: skillMdPath, encoding: .utf8)) ?? ""
                let (name, desc, invocable) = parseSkillFrontmatter(content, fallbackName: dir)
                skills.append(SkillInfo(name: name, description: desc, isUserInvocable: invocable, path: skillMdPath))
            }
        }

        // Hooks (settings.json의 "hooks" 키에서 파싱)
        var hooks: [HookInfo] = []
        if let hooksDict = settingsDict?["hooks"] as? [String: Any] {
            for (event, value) in hooksDict.sorted(by: { $0.key < $1.key }) {
                if let hookArray = value as? [[String: Any]] {
                    for hook in hookArray {
                        let matcher = hook["matcher"] as? String
                        if let innerHooks = hook["hooks"] as? [[String: Any]] {
                            for inner in innerHooks {
                                let hookType = inner["type"] as? String ?? "unknown"
                                let command = inner["command"] as? String ?? inner["url"] as? String
                                hooks.append(HookInfo(event: event, matcher: matcher, hookType: hookType, command: command))
                            }
                        }
                    }
                }
            }
        }

        // MCP Servers
        var mcpServers: [MCPServerInfo] = []
        if let data = fm.contents(atPath: mcpPath),
           let mcpJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let servers = mcpJson["mcpServers"] as? [String: [String: Any]] {
            for (name, config) in servers.sorted(by: { $0.key < $1.key }) {
                let type = config["type"] as? String ?? "stdio"
                let command = config["command"] as? String
                let url = config["url"] as? String
                let disabled = config["disabled"] as? Bool ?? false
                mcpServers.append(MCPServerInfo(name: name, type: type, command: command, url: url, isDisabled: disabled))
            }
        }

        // Permissions
        var permissions: PermissionInfo? = nil
        if let perms = settingsDict?["permissions"] as? [String: Any] {
            let allow = perms["allow"] as? [String] ?? []
            let deny = perms["deny"] as? [String] ?? []
            let ask = perms["ask"] as? [String] ?? []
            if !allow.isEmpty || !deny.isEmpty || !ask.isEmpty {
                permissions = PermissionInfo(allow: allow, deny: deny, ask: ask)
            }
        }

        // Model / Effort
        let model = settingsDict?["model"] as? String
        let effort = settingsDict?["effort"] as? String

        // Plugins (enabledPlugins 딕셔너리에서 활성화된 것만)
        var plugins: [String] = []
        if let enabledPlugins = settingsDict?["enabledPlugins"] as? [String: Bool] {
            plugins = enabledPlugins.filter(\.value).map(\.key).sorted()
        }

        return ConfigScope(
            settingsRaw: settingsRaw,
            claudeMd: claudeMd,
            rules: rules,
            skills: skills,
            hooks: hooks,
            mcpServers: mcpServers,
            permissions: permissions,
            model: model,
            effort: effort,
            plugins: plugins
        )
    }

    private static func parseSkillFrontmatter(_ content: String, fallbackName: String) -> (name: String, description: String, isUserInvocable: Bool) {
        var name = fallbackName
        var description = ""
        var invocable = false

        if content.hasPrefix("---") {
            let parts = content.components(separatedBy: "---")
            if parts.count >= 3 {
                let frontmatter = parts[1]
                for line in frontmatter.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("name:") {
                        name = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("description:") {
                        description = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("user-invocable:") {
                        invocable = trimmed.contains("true")
                    }
                }
            }
        }

        return (name, description, invocable)
    }

    private static func findGitRoot(from directory: String) -> String? {
        ProcessRunner.output("/usr/bin/git", arguments: ["rev-parse", "--show-toplevel"], currentDirectory: directory)
    }
}
