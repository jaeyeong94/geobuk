import Foundation

/// 셸의 --help 출력을 파싱하여 서브커맨드 완성을 제공한다
/// 실행 결과를 캐싱하여 동일 명령어에 대한 반복 호출을 방지한다
final class ShellCompletionProvider {

    /// 캐시: 명령어 → 서브커맨드 목록
    nonisolated(unsafe) private static var cache: [String: [String]] = [:]

    /// 캐시 타임스탬프
    nonisolated(unsafe) private static var cacheTimestamps: [String: Date] = [:]
    private static let cacheTTL: TimeInterval = 300

    /// 명령어의 서브커맨드 후보를 반환한다
    /// - Parameters:
    ///   - command: 기본 명령어 (예: "git", "docker")
    ///   - prefix: 서브커맨드 prefix (예: "sta" → "stash", "status")
    /// - Returns: 매칭되는 서브커맨드 목록
    static func subcommands(for command: String, prefix: String) -> [String] {
        let all = cachedSubcommands(for: command)
        if prefix.isEmpty { return all }
        return all.filter { $0.hasPrefix(prefix) }
    }

    /// 캐시된 서브커맨드 목록을 반환하거나, 없으면 셸에서 가져온다
    private static func cachedSubcommands(for command: String) -> [String] {
        // 캐시 히트 + TTL 유효
        if let cached = cache[command],
           let timestamp = cacheTimestamps[command],
           Date().timeIntervalSince(timestamp) < cacheTTL {
            return cached
        }

        // 셸에서 서브커맨드 조회
        let result = fetchSubcommands(for: command)
        cache[command] = result
        cacheTimestamps[command] = Date()
        return result
    }

    /// --help 출력을 파싱하여 서브커맨드를 추출한다
    static func fetchSubcommands(for command: String) -> [String] {
        // which로 명령어 존재 확인 (없는 명령어에 대한 불필요한 실행 방지)
        guard commandExists(command) else { return [] }

        // --help 출력 가져오기 (2초 타임아웃)
        guard let output = runWithTimeout(executable: "/bin/zsh",
                                          arguments: ["-c", "\(command) --help 2>&1 || \(command) help 2>&1 || \(command) -h 2>&1"],
                                          timeout: 2.0) else {
            return []
        }

        return parseSubcommands(from: output)
    }

    /// --help 출력에서 서브커맨드를 파싱한다
    static func parseSubcommands(from output: String) -> [String] {
        var results: Set<String> = []

        // Strategy 1: 콤마 구분 리스트 (npm 스타일: "access, adduser, audit, ...")
        // 줄 단위로 분리 후 각 줄의 콤마 항목을 파싱
        let csvCandidates = output.components(separatedBy: "\n")
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isSubcommandLike($0) }

        if csvCandidates.count > 5 {
            return Array(Set(csvCandidates)).sorted()
        }

        // Strategy 2: 들여쓰기된 줄의 첫 단어 (git/docker 스타일)
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .init(charactersIn: "\t"))
            // 2칸 이상 들여쓰기된 줄
            guard line.hasPrefix("  "), !trimmed.isEmpty else { continue }

            let firstWord = trimmed.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
            if isSubcommandLike(firstWord) {
                results.insert(firstWord)
            }
        }

        return results.sorted()
    }

    /// 문자열이 서브커맨드처럼 보이는지 판별한다
    static func isSubcommandLike(_ word: String) -> Bool {
        guard word.count >= 2, word.count <= 30 else { return false }
        // --option, -f 같은 플래그는 제외
        guard !word.hasPrefix("-") else { return false }
        // 소문자로 시작, 소문자/숫자/하이픈만 허용
        let allowed = CharacterSet.lowercaseLetters
            .union(.decimalDigits)
            .union(.init(charactersIn: "-"))
        return word.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// 명령어가 시스템에 설치되어 있는지 확인한다
    private static func commandExists(_ command: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [command]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// 타임아웃 지정으로 외부 프로세스를 실행하고 stdout을 반환한다
    private static func runWithTimeout(executable: String, arguments: [String], timeout: TimeInterval) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
        } catch {
            return nil
        }

        // 타임아웃 처리
        let deadline = DispatchTime.now() + timeout
        DispatchQueue.global().asyncAfter(deadline: deadline) {
            if task.isRunning { task.terminate() }
        }

        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    /// 캐시를 초기화한다 (테스트용)
    static func clearCache() {
        cache.removeAll()
        cacheTimestamps.removeAll()
    }
}
