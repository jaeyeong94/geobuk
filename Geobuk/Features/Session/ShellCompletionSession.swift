import Foundation

/// Tab 완성 전용 Headless PTY 세션.
/// 앱 수명 동안 하나만 유지하며, CWD를 사용자 셸과 동기화한다.
@MainActor
final class ShellCompletionSession {

    private var session: HeadlessSession?
    private var currentCwd: String = NSHomeDirectory()
    private(set) var isReady = false

    /// 프롬프트 감지용 마커
    private static let readyMarker = "GEOBUK_COMP_READY"

    /// 완성 출력 구분용 마커
    private static let beginMarker = "GEOBUK_COMP_BEGIN"
    private static let endMarker = "GEOBUK_COMP_END"

    // MARK: - Lifecycle

    /// start() 전에 초기 CWD를 설정한다.
    func setCwd(_ cwd: String) {
        currentCwd = cwd
    }

    /// Headless PTY를 생성하고 프롬프트 대기
    func start() {
        guard session == nil else { return }

        let shell = detectShell()
        GeobukLogger.info(.app, "ShellCompletionSession starting", context: ["shell": shell])

        // 사용자의 일반 셸을 그대로 사용 (completion 환경 유지)
        // ZDOTDIR 등을 커스텀하지 않음 — 사용자의 .zshrc에서 compinit이 이미 로드됨
        session = HeadlessSession(
            name: "__geobuk_completion__",
            cwd: currentCwd,
            shell: shell,
            bufferCapacity: 500
        )

        // 셸이 초기화될 시간을 준 뒤 프롬프트 마커 설정
        Task {
            // 셸 초기화 대기 (zshrc 로딩)
            try? await Task.sleep(for: .milliseconds(1500))

            guard let session else { return }

            // TERM을 xterm으로 유지 (dumb → completion 비활성화 방지)
            // 프롬프트만 커스텀 마커로 변경
            session.sendKeys("export PS1='\(Self.readyMarker)\\n'\n")
            try? await Task.sleep(for: .milliseconds(200))

            // compinit이 아직 로드되지 않았을 수 있으므로 안전하게 재초기화
            if shell.contains("zsh") {
                session.sendKeys("autoload -Uz compinit && compinit -C 2>/dev/null\n")
                try? await Task.sleep(for: .milliseconds(300))
            }

            // ready 마커 echo로 확인
            session.sendKeys("echo \(Self.readyMarker)\n")

            isReady = await waitForMarker(Self.readyMarker, timeout: 5.0)
            if isReady {
                GeobukLogger.info(.app, "ShellCompletionSession ready")
            } else {
                GeobukLogger.warn(.app, "ShellCompletionSession failed to initialize")
            }
        }
    }

    /// CWD 동기화
    func updateCwd(_ cwd: String) {
        guard let session, isReady, cwd != currentCwd else { return }
        currentCwd = cwd
        session.sendKeys("cd \(shellEscape(cwd))\n")
    }

    /// Tab 완성 실행: input을 셸에 보내고 Tab 결과를 캡처한다.
    /// - Returns: 완성 후보 배열 (빈 배열이면 완성 없음)
    func complete(_ input: String) async -> [String] {
        guard let session, isReady, !input.isEmpty else { return [] }

        // 1. 이전 출력 클리어 — 마커로 경계 설정
        session.sendKeys("echo \(Self.beginMarker)\n")
        _ = await waitForMarker(Self.beginMarker, timeout: 1.0)

        // 2. 입력 전송 + Tab
        session.sendKeys(input)
        session.sendSpecialKey(.tab)
        // 더블 Tab으로 전체 후보 나열 강제 (zsh에서 단일 Tab은 공통 접두어만 완성)
        try? await Task.sleep(for: .milliseconds(100))
        session.sendSpecialKey(.tab)

        // 3. 완성 결과 대기
        try? await Task.sleep(for: .milliseconds(400))

        // 4. 출력 캡처
        let output = session.captureOutput(lines: 50)

        // 5. 상태 복원: Ctrl+U로 입력 줄 삭제, Ctrl+C로 안전하게 프롬프트 복귀
        session.sendSpecialKey(.ctrlC)
        try? await Task.sleep(for: .milliseconds(100))
        session.sendKeys("echo \(Self.endMarker)\n")
        _ = await waitForMarker(Self.endMarker, timeout: 1.0)

        // 6. 마커 사이의 출력 추출 및 파싱
        let completionOutput = extractCompletionOutput(from: output, input: input)

        let shell = detectShell()
        if shell.contains("zsh") {
            return TabCompletionParser.parseZsh(input: input, output: completionOutput)
        } else {
            return TabCompletionParser.parseBash(input: input, output: completionOutput)
        }
    }

    /// 세션 재시작 (비정상 시)
    func restart() {
        destroy()
        start()
    }

    /// PTY 정리
    func destroy() {
        session?.destroy()
        session = nil
        isReady = false
    }

    // MARK: - Private

    /// 출력에서 마커가 나타날 때까지 대기
    @discardableResult
    private func waitForMarker(_ marker: String, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let pollInterval: UInt64 = 50_000_000 // 50ms

        while Date() < deadline {
            if let session, session.captureOutput(lines: 20).contains(marker) {
                return true
            }
            try? await Task.sleep(nanoseconds: pollInterval)
        }
        return false
    }

    /// beginMarker 이후, 프롬프트/endMarker 이전의 Tab 출력을 추출
    private func extractCompletionOutput(from output: String, input: String) -> String {
        let lines = output.components(separatedBy: .newlines)

        var capturing = false
        var captured: [String] = []

        for line in lines {
            let stripped = TabCompletionParser.stripAnsi(line)
                .trimmingCharacters(in: .whitespaces)

            if stripped.contains(Self.beginMarker) {
                capturing = true
                continue
            }

            if stripped.contains(Self.endMarker) || stripped.contains(Self.readyMarker) {
                break
            }

            if capturing && !stripped.isEmpty {
                // 입력 에코, ^C, echo 명령어 자체를 제외
                if stripped == input || stripped.hasSuffix("^C") { continue }
                if stripped.hasPrefix("echo ") { continue }
                captured.append(stripped)
            }
        }

        return captured.joined(separator: "\n")
    }

    private func detectShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            return shell
        }
        return "/bin/zsh"
    }

    private func shellEscape(_ path: String) -> String {
        return "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
