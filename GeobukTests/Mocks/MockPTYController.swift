import Foundation
@testable import Geobuk

/// 테스트용 Mock PTY 컨트롤러
/// 실제 forkpty() 호출 없이 PTY 동작을 시뮬레이션
final class MockPTYController: PTYControlling, @unchecked Sendable {
    private(set) var _childPid: pid_t = 12345
    private(set) var _isActive = false
    private(set) var writtenData: [Data] = []
    private(set) var sentSpecialKeys: [PTYController.SpecialKey] = []
    private(set) var spawnCalled = false
    private(set) var closeCalled = false
    private var onReadCallback: (@Sendable (Data) -> Void)?

    var shouldFailSpawn = false
    private let lock = NSLock()

    var childPid: pid_t { _childPid }
    var isActive: Bool { _isActive }

    func spawn(
        shell: String?,
        cwd: String,
        environment: [String: String],
        onRead: @escaping @Sendable (Data) -> Void
    ) throws {
        if shouldFailSpawn {
            throw PTYError.forkFailed
        }
        spawnCalled = true
        _isActive = true
        onReadCallback = onRead
    }

    func write(_ data: Data) {
        guard _isActive else { return }
        lock.lock()
        writtenData.append(data)
        lock.unlock()
    }

    func sendSpecialKey(_ key: PTYController.SpecialKey) {
        guard _isActive else { return }
        lock.lock()
        sentSpecialKeys.append(key)
        lock.unlock()
    }

    func close() {
        _isActive = false
        closeCalled = true
    }

    /// 테스트 헬퍼: PTY 출력 시뮬레이션
    func simulateOutput(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        onReadCallback?(data)
    }
}
