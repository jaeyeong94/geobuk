import Foundation

/// UI 없는 PTY 세션 (API 전용)
/// Metal 렌더링 표면 없이 PTY + 출력 버퍼만 유지
final class HeadlessSession: @unchecked Sendable {
    /// 세션 이름
    let name: String

    /// 자식 프로세스 PID
    var pid: pid_t { ptyController.childPid }

    /// 세션 파괴 여부
    private(set) var isDestroyed = false

    /// PTY 컨트롤러 (프로토콜을 통한 추상화)
    private let ptyController: PTYControlling

    /// 출력 링 버퍼 (최근 N 라인 보관)
    private let outputBuffer: RingBuffer

    /// 부분 라인 버퍼 (줄바꿈 전까지 축적)
    private var partialLine = ""
    private let partialLock = NSLock()

    // MARK: - Init

    /// HeadlessSession 생성 및 셸 시작
    /// - Parameters:
    ///   - name: 세션 이름
    ///   - cwd: 작업 디렉토리
    ///   - shell: 셸 경로 (nil이면 기본 셸)
    ///   - bufferCapacity: 출력 버퍼 용량 (기본 1000줄)
    ///   - ptyController: PTY 컨트롤러 (테스트 시 mock 주입 가능)
    init(
        name: String,
        cwd: String,
        shell: String?,
        bufferCapacity: Int = 1000,
        ptyController: PTYControlling? = nil,
        extraEnvironment: [String: String] = [:]
    ) {
        self.name = name
        self.outputBuffer = RingBuffer(capacity: bufferCapacity)
        self.ptyController = ptyController ?? PTYController()

        do {
            var env = ["GEOBUK_SESSION": name]
            env.merge(extraEnvironment) { _, new in new }
            try self.ptyController.spawn(
                shell: shell,
                cwd: cwd,
                environment: env,
                onRead: { [weak self] data in
                    self?.handleOutput(data)
                }
            )
        } catch {
            // PTY 시작 실패 시 destroyed 상태로 전환
            isDestroyed = true
        }
    }

    // MARK: - Public API

    /// PTY에 텍스트 전송
    func sendKeys(_ text: String) {
        guard !isDestroyed else { return }
        guard let data = text.data(using: .utf8) else { return }
        ptyController.write(data)
    }

    /// PTY에 특수 키 전송
    func sendSpecialKey(_ key: PTYController.SpecialKey) {
        guard !isDestroyed else { return }
        ptyController.sendSpecialKey(key)
    }

    /// 최근 출력 캡처
    /// - Parameter lines: 가져올 줄 수
    /// - Returns: 줄바꿈으로 합쳐진 출력 문자열
    func captureOutput(lines: Int) -> String {
        outputBuffer.lastLines(lines).joined(separator: "\n")
    }

    /// 세션 파괴 (PTY 종료)
    func destroy() {
        guard !isDestroyed else { return }
        isDestroyed = true
        ptyController.close()
    }

    // MARK: - Private

    /// PTY 출력 데이터 처리 -> 줄 단위로 버퍼에 추가
    private func handleOutput(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }

        partialLock.lock()
        defer { partialLock.unlock() }

        let combined = partialLine + text
        let lines = combined.split(separator: "\n", omittingEmptySubsequences: false)

        if lines.isEmpty { return }

        // 마지막 줄이 줄바꿈으로 끝나지 않으면 부분 라인으로 보관
        if combined.hasSuffix("\n") || combined.hasSuffix("\r\n") {
            for line in lines where !line.isEmpty {
                outputBuffer.append(String(line))
            }
            partialLine = ""
        } else {
            for line in lines.dropLast() where !line.isEmpty {
                outputBuffer.append(String(line))
            }
            partialLine = String(lines.last ?? "")
        }
    }

    deinit {
        if !isDestroyed {
            ptyController.close()
        }
    }
}
