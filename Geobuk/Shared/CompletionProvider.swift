import Foundation

/// 인라인 자동완성 힌트를 제공하는 타입
/// 파일 경로, 명령어 히스토리, 공통 명령어 순서로 완성 후보를 탐색한다
final class CompletionProvider {

    /// 일반적으로 많이 쓰이는 셸 명령어 목록
    static let commonCommands: [String] = [
        "cd", "ls", "pwd", "echo", "cat", "grep", "find", "mkdir", "rm", "cp",
        "mv", "touch", "chmod", "chown", "curl", "wget", "ssh", "scp", "tar",
        "git", "npm", "yarn", "pnpm", "node", "python", "python3", "pip",
        "brew", "make", "xcodebuild", "swift", "cargo", "go", "java", "mvn",
        "docker", "kubectl", "terraform", "aws", "gcloud", "az",
        "ps", "top", "kill", "man", "which", "export", "source", "history",
        "open", "pbcopy", "pbpaste", "say", "afplay", "df", "du", "lsof",
        "netstat", "ping", "traceroute", "nslookup", "dig", "ifconfig",
        "sudo", "su", "env", "set", "unset", "alias", "unalias",
        "head", "tail", "less", "more", "sort", "uniq", "wc", "awk", "sed",
        "xargs", "tee", "diff", "patch", "zip", "unzip", "gzip", "gunzip",
        "vim", "nano", "emacs", "code"
    ]

    // MARK: - Public API

    /// 현재 입력에 대한 완성 힌트의 나머지 부분을 반환한다
    /// suggestAll()의 첫 번째 결과에서 입력을 제외한 나머지를 반환
    static func suggest(
        for input: String,
        currentDirectory: String?,
        history: CommandHistory
    ) -> String? {
        guard let first = suggestAll(for: input, currentDirectory: currentDirectory, history: history, maxResults: 1).first else {
            return nil
        }
        guard first.hasPrefix(input), first != input else { return nil }
        return String(first.dropFirst(input.count))
    }

    /// 현재 입력에 대한 완성 후보 목록을 반환한다 (전체 명령어 형태)
    static func suggestAll(
        for input: String,
        currentDirectory: String?,
        history: CommandHistory,
        maxResults: Int = 10
    ) -> [String] {
        guard input.count >= 2 else { return [] }

        var results: [String] = []
        var seen: Set<String> = []

        func appendUnique(_ items: [String]) {
            for item in items where seen.insert(item).inserted {
                results.append(item)
            }
        }

        // 1순위: 히스토리 기반 (최근 우선)
        appendUnique(
            history.commands.reversed().filter { $0.hasPrefix(input) && $0 != input }
        )

        // 2순위: 파일 경로 완성 (/, ~ 포함 시)
        if input.contains("/") || input.contains("~") {
            appendUnique(filePathCandidates(for: input, currentDirectory: currentDirectory))
        }

        // 3순위: 공통 명령어 완성 (공백 없을 때만)
        if !input.contains(" ") {
            appendUnique(
                commonCommands.filter { $0.hasPrefix(input) && $0 != input }
            )
        }

        // 4순위: 서브커맨드 완성 (git, docker, npm 등)
        appendUnique(subcommandCandidates(for: input))

        // 5순위: 환경변수 완성 ($로 시작)
        if input.contains("$") {
            appendUnique(envVarCandidates(for: input))
        }

        // 6순위: currentDirectory 기반 파일명 완성
        if let cwd = currentDirectory {
            appendUnique(cwdFileCandidates(for: input, currentDirectory: cwd))
        }

        return Array(results.prefix(maxResults))
    }

    // MARK: - File Path Completion

    /// 파일 경로 자동완성
    /// 입력의 마지막 경로 컴포넌트를 기준으로 같은 디렉토리 내 항목을 탐색한다
    static func filePathCompletion(
        for input: String,
        currentDirectory: String?
    ) -> String? {
        guard let first = filePathCandidates(for: input, currentDirectory: currentDirectory).first else {
            return nil
        }
        guard first.hasPrefix(input), first != input else { return nil }
        return String(first.dropFirst(input.count))
    }

    /// 파일 경로 자동완성 후보 목록 (전체 입력 + 매칭된 파일 이름)
    static func filePathCandidates(
        for input: String,
        currentDirectory: String?
    ) -> [String] {
        let pathToken = extractPathToken(from: input)
        guard !pathToken.isEmpty else { return [] }

        // 상대 경로(./ ../)인데 currentDirectory가 없으면 해석 불가
        if pathToken.hasPrefix(".") && currentDirectory == nil { return [] }

        let expandedToken = expandPath(pathToken, currentDirectory: currentDirectory)
        let (dirPath, filePrefix) = splitPathComponents(expandedToken, currentDirectory: currentDirectory)
        guard let dirPath else { return [] }
        guard let contents = listDirectory(dirPath) else { return [] }

        let commandPrefix = extractCommandPrefix(from: input)

        let filtered: [String]
        if filePrefix.isEmpty {
            filtered = contents.filter { !$0.hasPrefix(".") }
        } else {
            filtered = contents.filter { $0.hasPrefix(filePrefix) && $0 != filePrefix }
        }

        return filtered.map { match in
            let completedPath = filePrefix.isEmpty
                ? pathToken + match
                : String(pathToken.dropLast(filePrefix.count)) + match
            return commandPrefix + completedPath
        }
    }

    // MARK: - History Completion

    /// 히스토리 기반 자동완성
    /// 현재 입력으로 시작하는 가장 최근 히스토리 항목을 찾는다
    static func historyCompletion(
        for input: String,
        history: CommandHistory
    ) -> String? {
        let match = history.commands.reversed().first {
            $0.hasPrefix(input) && $0 != input
        }
        guard let match else { return nil }
        return String(match.dropFirst(input.count))
    }

    // MARK: - Common Command Completion

    /// 공통 명령어 자동완성
    /// 입력이 명령어의 시작 부분과 일치하는 경우에만 제안한다 (첫 번째 토큰에만 적용)
    static func commonCommandCompletion(for input: String) -> String? {
        guard !input.contains(" ") else { return nil }

        let match = commonCommands.first {
            $0.hasPrefix(input) && $0 != input
        }
        guard let match else { return nil }
        return String(match.dropFirst(input.count))
    }

    // MARK: - Subcommand Completion

    /// 하드코딩 fallback 서브커맨드 (ShellCompletionProvider 실패 시 사용)
    static let fallbackSubcommands: [String: [String]] = [
        "git": [
            "add", "bisect", "blame", "branch", "checkout", "cherry-pick", "clean",
            "clone", "commit", "config", "diff", "fetch", "init", "log", "merge",
            "mv", "pull", "push", "rebase", "reflog", "remote", "reset", "restore",
            "revert", "rm", "show", "stash", "status", "switch", "tag", "worktree"
        ],
        "docker": [
            "build", "compose", "cp", "create", "exec", "images", "inspect",
            "kill", "logs", "network", "ps", "pull", "push", "rm", "rmi",
            "run", "start", "stop", "system", "volume"
        ],
        "kubectl": [
            "apply", "config", "create", "delete", "describe", "edit", "exec",
            "expose", "get", "logs", "port-forward", "rollout", "run", "scale", "set", "top"
        ],
        "npm": [
            "ci", "config", "exec", "init", "install", "list", "outdated",
            "pack", "publish", "run", "search", "start", "test", "uninstall", "update", "version"
        ],
        "yarn": [
            "add", "build", "cache", "config", "create", "info", "init",
            "install", "link", "list", "remove", "run", "start", "test", "upgrade", "why"
        ],
        "pnpm": [
            "add", "audit", "build", "create", "exec", "fetch", "install",
            "list", "outdated", "publish", "remove", "run", "start", "test", "update"
        ],
        "cargo": [
            "add", "bench", "build", "check", "clean", "clippy", "doc",
            "fix", "fmt", "init", "install", "new", "publish", "remove", "run", "test", "update"
        ],
        "brew": [
            "autoremove", "cleanup", "config", "deps", "doctor", "info",
            "install", "leaves", "list", "outdated", "search", "uninstall", "update", "upgrade"
        ]
    ]

    /// "git sta" → ["git stash", "git status"] 같은 서브커맨드 후보를 반환한다
    /// ShellCompletionProvider(런타임 --help 파싱)를 우선 사용하고, 실패 시 하드코딩 fallback
    static func subcommandCandidates(for input: String) -> [String] {
        let parts = input.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return [] }

        let command = String(parts[0])
        let subPrefix = String(parts[1])

        // 1순위: 셸에서 런타임으로 서브커맨드 조회
        let shellSubs = ShellCompletionProvider.subcommands(for: command, prefix: subPrefix)
        if !shellSubs.isEmpty {
            return shellSubs.map { "\(command) \($0)" }
        }

        // 2순위: 하드코딩 fallback
        guard let subs = fallbackSubcommands[command] else { return [] }

        if subPrefix.isEmpty {
            return subs.map { "\(command) \($0)" }
        }

        return subs
            .filter { $0.hasPrefix(subPrefix) && $0 != subPrefix }
            .map { "\(command) \($0)" }
    }

    // MARK: - Environment Variable Completion

    /// $HO → $HOME 같은 환경변수 완성 후보를 반환한다
    static func envVarCandidates(for input: String) -> [String] {
        let token = extractPathToken(from: input)
        guard token.hasPrefix("$"), token.count >= 2 else { return [] }

        let varPrefix = String(token.dropFirst()) // "$" 제거
        let commandPrefix = extractCommandPrefix(from: input)
        let env = ProcessInfo.processInfo.environment

        return env.keys.sorted()
            .filter { $0.hasPrefix(varPrefix) && $0 != varPrefix }
            .prefix(10)
            .map { commandPrefix + "$" + $0 }
    }

    // MARK: - CWD-based File Completion

    /// currentDirectory에서 마지막 토큰으로 파일명을 완성한다 (인라인 힌트)
    static func cwdFileCompletion(for input: String, currentDirectory: String) -> String? {
        guard let first = cwdFileCandidates(for: input, currentDirectory: currentDirectory).first else {
            return nil
        }
        guard first.hasPrefix(input), first != input else { return nil }
        return String(first.dropFirst(input.count))
    }

    /// currentDirectory에서 마지막 토큰으로 파일명 후보 목록을 반환한다
    static func cwdFileCandidates(for input: String, currentDirectory: String) -> [String] {
        let token = extractPathToken(from: input)
        guard token.count >= 2, !token.contains("/"), !token.contains("~") else { return [] }
        guard let contents = listDirectory(currentDirectory) else { return [] }

        let commandPrefix = extractCommandPrefix(from: input)

        return contents
            .filter { $0.hasPrefix(token) && $0 != token }
            .map { commandPrefix + $0 }
    }

    // MARK: - Helpers

    /// 입력 문자열에서 마지막 경로 토큰을 추출한다
    /// 예: "cd ~/Web" -> "~/Web", "ls /usr/lo" -> "/usr/lo"
    static func extractPathToken(from input: String) -> String {
        if let lastSpaceIndex = input.lastIndex(of: " ") {
            return String(input[input.index(after: lastSpaceIndex)...])
        }
        return input
    }

    /// 입력에서 마지막 토큰 앞의 명령어 부분을 추출한다
    /// 예: "cd ~/Web" -> "cd ", "ls" -> ""
    private static func extractCommandPrefix(from input: String) -> String {
        if let lastSpaceIndex = input.lastIndex(of: " ") {
            return String(input[...lastSpaceIndex])
        }
        return ""
    }

    /// 셸 경로를 절대 경로로 확장한다 (~, ./, ../ 등)
    private static func expandPath(_ path: String, currentDirectory: String?) -> String {
        if path == "~" {
            return NSHomeDirectory()
        } else if path.hasPrefix("~/") {
            return NSHomeDirectory() + String(path.dropFirst(1))
        } else if let cwd = currentDirectory, path.hasPrefix(".") {
            let resolved = (cwd as NSString).appendingPathComponent(path)
            var result = (resolved as NSString).standardizingPath
            // 원본이 /로 끝나면 결과에도 / 유지 (디렉토리 내용 나열용)
            if path.hasSuffix("/") && !result.hasSuffix("/") {
                result += "/"
            }
            return result
        }
        return path
    }

    /// 디렉토리 내용을 정렬된 배열로 반환한다
    private static func listDirectory(_ path: String) -> [String]? {
        try? FileManager.default.contentsOfDirectory(atPath: path).sorted()
    }

    /// 경로 문자열을 (디렉토리 경로, 파일 이름 prefix) 로 분리한다
    private static func splitPathComponents(
        _ expandedPath: String,
        currentDirectory: String?
    ) -> (String?, String) {
        if let slashIdx = expandedPath.lastIndex(of: "/") {
            let dirPart = String(expandedPath[...slashIdx])
            let filePart = String(expandedPath[expandedPath.index(after: slashIdx)...])
            return (dirPart.isEmpty ? "/" : dirPart, filePart)
        } else {
            guard let cwd = currentDirectory else { return (nil, expandedPath) }
            return (cwd, expandedPath)
        }
    }
}
