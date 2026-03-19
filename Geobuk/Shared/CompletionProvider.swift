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
        "vim", "nano", "emacs", "code", "open"
    ]

    // MARK: - Public API

    /// 현재 입력에 대한 완성 힌트의 나머지 부분을 반환한다
    /// - Parameters:
    ///   - input: 사용자가 현재 입력한 문자열
    ///   - currentDirectory: 셸의 현재 작업 디렉토리 (nil 허용)
    ///   - history: 명령어 히스토리
    /// - Returns: 힌트 문자열 (입력에 이어 붙일 나머지 부분), 없으면 nil
    static func suggest(
        for input: String,
        currentDirectory: String?,
        history: CommandHistory
    ) -> String? {
        // 너무 짧은 입력에는 힌트를 제공하지 않는다
        guard input.count >= 2 else { return nil }

        // 1순위: 파일 경로 완성 (입력에 `/` 또는 `~` 포함 시)
        if input.contains("/") || input.contains("~") {
            if let hint = filePathCompletion(for: input, currentDirectory: currentDirectory) {
                return hint
            }
        }

        // 2순위: 히스토리 기반 완성
        if let hint = historyCompletion(for: input, history: history) {
            return hint
        }

        // 3순위: 공통 명령어 완성
        if let hint = commonCommandCompletion(for: input) {
            return hint
        }

        // 4순위: currentDirectory 기반 파일명 완성 (/, ~ 없이 마지막 토큰)
        if let cwd = currentDirectory {
            if let hint = cwdFileCompletion(for: input, currentDirectory: cwd) {
                return hint
            }
        }

        return nil
    }

    // MARK: - Multi-Candidate API

    /// 현재 입력에 대한 완성 후보 목록을 반환한다 (전체 명령어 형태)
    /// - Parameters:
    ///   - input: 사용자가 현재 입력한 문자열
    ///   - currentDirectory: 셸의 현재 작업 디렉토리 (nil 허용)
    ///   - history: 명령어 히스토리
    ///   - maxResults: 최대 반환 개수 (기본 10)
    /// - Returns: 완성된 전체 문자열 목록 (중복 없음)
    static func suggestAll(
        for input: String,
        currentDirectory: String?,
        history: CommandHistory,
        maxResults: Int = 10
    ) -> [String] {
        guard input.count >= 2 else { return [] }

        var results: [String] = []
        var seen: Set<String> = []

        // 1순위: 히스토리 기반 (최근 우선)
        for cmd in history.commands.reversed() {
            guard cmd.hasPrefix(input), cmd != input else { continue }
            if seen.insert(cmd).inserted {
                results.append(cmd)
            }
        }

        // 2순위: 파일 경로 완성
        if input.contains("/") || input.contains("~") {
            let pathCandidates = filePathCandidates(for: input, currentDirectory: currentDirectory)
            for candidate in pathCandidates {
                if seen.insert(candidate).inserted {
                    results.append(candidate)
                }
            }
        }

        // 3순위: 공통 명령어 완성 (공백 없을 때만)
        if !input.contains(" ") {
            for cmd in commonCommands where cmd.hasPrefix(input) && cmd != input {
                if seen.insert(cmd).inserted {
                    results.append(cmd)
                }
            }
        }

        // 4순위: currentDirectory 기반 파일명 완성 (/, ~ 없이 마지막 토큰)
        if let cwd = currentDirectory {
            let cwdCandidates = cwdFileCandidates(for: input, currentDirectory: cwd)
            for candidate in cwdCandidates {
                if seen.insert(candidate).inserted {
                    results.append(candidate)
                }
            }
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
        // 입력에서 경로 부분을 추출 (마지막 공백 이후)
        let pathToken = extractPathToken(from: input)
        guard !pathToken.isEmpty else { return nil }

        // `~` 를 홈 디렉토리로 확장
        let expandedToken = expandTilde(pathToken)

        // 디렉토리와 파일 이름 prefix 분리
        let (dirPath, filePrefix) = splitPathComponents(expandedToken, currentDirectory: currentDirectory)

        guard let dirPath else { return nil }

        // 해당 디렉토리의 내용 목록 조회
        let contents: [String]
        do {
            contents = try FileManager.default.contentsOfDirectory(atPath: dirPath)
        } catch {
            return nil
        }

        // filePrefix로 시작하는 첫 번째 항목 탐색
        let sorted = contents.sorted()
        guard let match = sorted.first(where: {
            !filePrefix.isEmpty && $0.hasPrefix(filePrefix) && $0 != filePrefix
        }) else { return nil }

        // 입력한 prefix를 제외한 나머지 부분만 반환
        return String(match.dropFirst(filePrefix.count))
    }

    /// 파일 경로 자동완성 후보 목록 (전체 입력 + 매칭된 파일 이름)
    static func filePathCandidates(
        for input: String,
        currentDirectory: String?
    ) -> [String] {
        let pathToken = extractPathToken(from: input)
        guard !pathToken.isEmpty else { return [] }

        let expandedToken = expandTilde(pathToken)
        let (dirPath, filePrefix) = splitPathComponents(expandedToken, currentDirectory: currentDirectory)
        guard let dirPath else { return [] }

        let contents: [String]
        do {
            contents = try FileManager.default.contentsOfDirectory(atPath: dirPath)
        } catch {
            return []
        }

        // input에서 pathToken 앞부분 (명령어 부분)
        let commandPrefix: String
        if let lastSpaceIndex = input.lastIndex(of: " ") {
            commandPrefix = String(input[...lastSpaceIndex])
        } else {
            commandPrefix = ""
        }

        let filtered: [String]
        if filePrefix.isEmpty {
            // 디렉토리 내용 전체 (예: "cd /usr/" → /usr/ 내 모든 항목)
            filtered = contents.sorted().filter { !$0.hasPrefix(".") }
        } else {
            filtered = contents.sorted().filter { $0.hasPrefix(filePrefix) && $0 != filePrefix }
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
        // 최근 항목을 우선하기 위해 역순으로 탐색
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
        // 공백이 포함된 경우 이미 명령어가 완성된 것이므로 적용하지 않는다
        guard !input.contains(" ") else { return nil }

        let match = commonCommands.first {
            $0.hasPrefix(input) && $0 != input
        }
        guard let match else { return nil }
        return String(match.dropFirst(input.count))
    }

    // MARK: - CWD-based File Completion

    /// currentDirectory에서 마지막 토큰으로 파일명을 완성한다 (인라인 힌트)
    /// 예: cwd="/Users/ted", input="cd Webstorm" → "Projects"
    static func cwdFileCompletion(for input: String, currentDirectory: String) -> String? {
        let token = extractPathToken(from: input)
        guard token.count >= 2, !token.contains("/"), !token.contains("~") else { return nil }

        let contents: [String]
        do {
            contents = try FileManager.default.contentsOfDirectory(atPath: currentDirectory)
        } catch { return nil }

        guard let match = contents.sorted().first(where: {
            $0.hasPrefix(token) && $0 != token
        }) else { return nil }

        return String(match.dropFirst(token.count))
    }

    /// currentDirectory에서 마지막 토큰으로 파일명 후보 목록을 반환한다
    static func cwdFileCandidates(for input: String, currentDirectory: String) -> [String] {
        let token = extractPathToken(from: input)
        guard token.count >= 2, !token.contains("/"), !token.contains("~") else { return [] }

        let contents: [String]
        do {
            contents = try FileManager.default.contentsOfDirectory(atPath: currentDirectory)
        } catch { return [] }

        let commandPrefix: String
        if let lastSpaceIndex = input.lastIndex(of: " ") {
            commandPrefix = String(input[...lastSpaceIndex])
        } else {
            commandPrefix = ""
        }

        return contents.sorted()
            .filter { $0.hasPrefix(token) && $0 != token }
            .map { commandPrefix + $0 }
    }

    // MARK: - Helpers

    /// 입력 문자열에서 마지막 경로 토큰을 추출한다
    /// 예: "cd ~/Web" -> "~/Web", "ls /usr/lo" -> "/usr/lo"
    private static func extractPathToken(from input: String) -> String {
        // 마지막 공백 이후 부분이 경로 토큰
        if let lastSpaceIndex = input.lastIndex(of: " ") {
            let afterSpace = input[input.index(after: lastSpaceIndex)...]
            return String(afterSpace)
        }
        return input
    }

    /// `~` 를 홈 디렉토리 경로로 확장한다
    private static func expandTilde(_ path: String) -> String {
        if path == "~" {
            return NSHomeDirectory()
        } else if path.hasPrefix("~/") {
            return NSHomeDirectory() + path.dropFirst(1)
        }
        return path
    }

    /// 경로 문자열을 (디렉토리 경로, 파일 이름 prefix) 로 분리한다
    /// - Returns: (검색할 디렉토리 절대 경로, 파일 이름 prefix). 디렉토리를 특정할 수 없으면 nil
    private static func splitPathComponents(
        _ expandedPath: String,
        currentDirectory: String?
    ) -> (String?, String) {
        let lastSlashIndex = expandedPath.lastIndex(of: "/")

        if let slashIdx = lastSlashIndex {
            // 슬래시가 있는 경우: 슬래시 이전이 디렉토리, 이후가 파일 prefix
            let dirPart = String(expandedPath[...slashIdx])
            let filePart = String(expandedPath[expandedPath.index(after: slashIdx)...])

            // 빈 디렉토리 문자열이면 루트
            let dirPath = dirPart.isEmpty ? "/" : dirPart
            return (dirPath, filePart)
        } else {
            // 슬래시가 없는 경우: currentDirectory를 기준으로 탐색
            guard let cwd = currentDirectory else { return (nil, expandedPath) }
            return (cwd, expandedPath)
        }
    }
}
