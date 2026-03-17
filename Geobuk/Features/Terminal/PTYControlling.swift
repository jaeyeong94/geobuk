import Foundation

/// PTY 제어 프로토콜 (테스트 가능성을 위한 추상화)
protocol PTYControlling: AnyObject, Sendable {
    var childPid: pid_t { get }
    var isActive: Bool { get }

    func spawn(
        shell: String?,
        cwd: String,
        environment: [String: String],
        onRead: @escaping @Sendable (Data) -> Void
    ) throws

    func write(_ data: Data)
    func sendSpecialKey(_ key: PTYController.SpecialKey)
    func close()
}

// MARK: - PTYController conforms to PTYControlling

extension PTYController: PTYControlling {}
