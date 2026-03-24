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

    /// Headless PTY를 생성하고 프롬프트 대기
    func start() {
        guard session == nil else { return }

        let shell = detectShell()
        GeobukLogger.info(.app, "ShellCompletionSession starting", context: ["shell": shell])

        session = HeadlessSession(
            name: "__geobuk_completion__",
            cwd: currentCwd,
            shell: shell,
            bufferCapacity: 200
        )

        // 셸 초기화: 최소한의 프롬프트 설정
        // TERM=dumb으로 ANSI 최소화, 커스텀 프롬프트로 마커 감지
        let setup: String
        if shell.contains("zsh") {
            setup = """
            export TERM=dumb
            export PS1='\(Self.readyMarker)\n'
            autoload -Uz compinit && compinit -C 2>/dev/null
            \(Self.readyMarker)_INIT_DONE=1
            """
        } else {
            // bash
            setup = """
            export TERM=dumb
            export PS1='\(Self.readyMarker)\n'
            \(Self.readyMarker)_INIT_DONE=1
            """
        }

        session?.sendKeys(setup + "\n")

        // 프롬프트 대기 (비동기)
        Task {
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
        await waitForMarker(Self.beginMarker, timeout: 1.0)

        // 2. 입력 전송 + Tab
        session.sendKeys(input)
        session.sendSpecialKey(.tab)

        // 3. 완성 결과 대기 (200ms)
        try? await Task.sleep(for: .milliseconds(300))

        // 4. 출력 캡처
        let output = session.captureOutput(lines: 50)

        // 5. 상태 복원: Ctrl+C로 부분 입력 취소, 프롬프트 복귀
        session.sendSpecialKey(.ctrlC)
        session.sendKeys("echo \(Self.endMarker)\n")
        await waitForMarker(Self.endMarker, timeout: 1.0)

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
            if let session, session.captureOutput(lines: 10).contains(marker) {
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

            // beginMarker 이후부터 캡처 시작
            if stripped.contains(Self.beginMarker) {
                capturing = true
                continue
            }

            // endMarker 또는 readyMarker를 만나면 중단
            if stripped.contains(Self.endMarker) || stripped.contains(Self.readyMarker) {
                break
            }

            // 마커 이후의 출력만 수집
            if capturing && !stripped.isEmpty {
                // 입력 에코를 제외하고, 셸 ^C 출력도 제외
                if stripped == input || stripped.hasSuffix("^C") {
                    continue
                }
                captured.append(stripped)
            }
        }

        return captured.joined(separator: "\n")
    }

    /// 사용자 기본 셸 감지
    private func detectShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            return shell
        }
        return "/bin/zsh"
    }

    /// 셸 경로 이스케이프 (공백, 특수문자)
    private func shellEscape(_ path: String) -> String {
        // 작은따옴표로 감싸되, 경로 내 작은따옴표는 이스케이프
        return "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
