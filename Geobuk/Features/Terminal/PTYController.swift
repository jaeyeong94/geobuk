import Foundation

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
        // Phase 1에서 구현:
        // 1. forkpty(&masterFd, nil, nil, nil) → childPid
        // 2. 자식 프로세스에서 execvp(shell, args)
        // 3. 부모에서 DispatchIO 채널 생성
        // 4. 비동기 읽기 루프 시작
        isActive = true
    }

    /// PTY에 데이터 쓰기
    func write(_ data: Data) {
        guard isActive, masterFd >= 0 else { return }
        // DispatchIO write
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
