import Foundation

/// PTY 에러
enum PTYError: Error, Sendable {
    case forkFailed
    case alreadyActive
}

/// PTY (Pseudo Terminal) 제어기
/// forkpty() + DispatchIO 기반 비동기 I/O
///
/// 명시적 close() 패턴으로 fd 누수 방지 (macOS fd limit: 256)
final class PTYController: @unchecked Sendable {
    // MARK: - Properties

    /// PTY master fd
    private var masterFd: Int32 = -1

    /// 자식 프로세스 PID
    private(set) var childPid: pid_t = 0

    /// DispatchIO 채널 (비동기 읽기/쓰기)
    private var dispatchChannel: DispatchIO?

    /// PTY 읽기 큐
    private let readQueue = DispatchQueue(label: "com.geobuk.pty.read", qos: .userInteractive)

    /// PTY 활성 상태
    private(set) var isActive = false

    // MARK: - Lifecycle

    deinit {
        close()
    }

    /// PTY 생성 및 셸 프로세스 시작
    /// - Parameters:
    ///   - shell: 셸 경로 (기본: $SHELL 또는 /bin/zsh)
    ///   - cwd: 작업 디렉토리
    ///   - environment: 추가 환경변수
    ///   - onRead: PTY 출력 콜백
    func spawn(
        shell: String? = nil,
        cwd: String = NSHomeDirectory(),
        environment: [String: String] = [:],
        onRead: @escaping @Sendable (Data) -> Void
    ) throws {
        guard !isActive else { throw PTYError.alreadyActive }

        var winSize = winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0)

        let pid = forkpty(&masterFd, nil, nil, &winSize)
        guard pid >= 0 else { throw PTYError.forkFailed }

        if pid == 0 {
            // Child process
            let shellPath = shell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

            // 작업 디렉토리 변경
            if chdir(cwd) != 0 {
                // chdir 실패 시 홈 디렉토리 사용
                _ = chdir(NSHomeDirectory())
            }

            // 환경변수 설정
            for (key, value) in environment {
                setenv(key, value, 1)
            }
            setenv("TERM", "xterm-256color", 1)

            // 셸 실행
            let shellName = (shellPath as NSString).lastPathComponent
            let loginShellName = "-\(shellName)"

            loginShellName.withCString { namePtr in
                shellPath.withCString { pathPtr in
                    // execvp에 전달할 인자 배열
                    let args: [UnsafeMutablePointer<CChar>?] = [
                        UnsafeMutablePointer(mutating: namePtr),
                        nil
                    ]
                    execvp(pathPtr, args)
                }
            }

            // execvp가 실패하면 여기에 도달
            _exit(1)
        }

        // Parent process
        childPid = pid

        // DispatchIO 채널 생성
        let channel = DispatchIO(type: .stream, fileDescriptor: masterFd, queue: readQueue) { [weak self] _ in
            // Cleanup handler - fd는 close()에서 관리
            _ = self
        }
        dispatchChannel = channel

        // 비동기 읽기 시작
        channel.read(offset: 0, length: .max, queue: readQueue) { done, data, error in
            if let data, !data.isEmpty {
                let bytes = Data(data)
                onRead(bytes)
            }
            if done && error != 0 {
                // Read 완료 또는 에러 - 정리는 close()에서 처리
            }
        }

        isActive = true
    }

    /// PTY에 데이터 쓰기
    func write(_ data: Data) {
        guard isActive, masterFd >= 0 else { return }
        data.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            _ = Darwin.write(masterFd, baseAddress, ptr.count)
        }
    }

    /// 특수 키 전송 (Ctrl+C, Ctrl+D 등)
    func sendSpecialKey(_ key: SpecialKey) {
        guard isActive else { return }
        write(key.bytes)
    }

    /// PTY 및 자식 프로세스 정리 (명시적 호출 필수)
    func close() {
        guard isActive else { return }
        isActive = false

        // DispatchIO 채널 정리
        dispatchChannel?.close(flags: .stop)
        dispatchChannel = nil

        // fd 명시적 닫기 (ARC deinit 타이밍에 의존하지 않음)
        if masterFd >= 0 {
            Darwin.close(masterFd)
            masterFd = -1
        }

        // 자식 프로세스 종료
        if childPid > 0 {
            kill(childPid, SIGHUP)
            childPid = 0
        }
    }
}

// MARK: - SpecialKey

extension PTYController {
    enum SpecialKey {
        case ctrlC
        case ctrlD
        case ctrlZ
        case enter
        case tab

        var bytes: Data {
            switch self {
            case .ctrlC: Data([0x03])
            case .ctrlD: Data([0x04])
            case .ctrlZ: Data([0x1A])
            case .enter: Data([0x0D])
            case .tab: Data([0x09])
            }
        }
    }
}
