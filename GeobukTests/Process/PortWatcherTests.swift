import Testing
import Foundation
@testable import Geobuk

@Suite("PortWatcher - 포트 감시")
struct PortWatcherTests {

    // MARK: - listeningPorts

    @Test("listeningPorts_현재프로세스_크래시없음")
    func listeningPorts_currentProcess_noCrash() {
        let ports = PortWatcher.listeningPorts(for: getpid())
        // 테스트 프로세스는 일반적으로 포트를 리슨하지 않음
        _ = ports
    }

    @Test("listeningPorts_존재하지않는PID_빈배열반환")
    func listeningPorts_nonExistentPid_returnsEmpty() {
        let ports = PortWatcher.listeningPorts(for: 99999999)
        #expect(ports.isEmpty)
    }

    @Test("listeningPorts_음수PID_빈배열반환")
    func listeningPorts_negativePid_returnsEmpty() {
        let ports = PortWatcher.listeningPorts(for: -1)
        #expect(ports.isEmpty)
    }

    @Test("listeningPorts_PID0_크래시없음")
    func listeningPorts_pidZero_noCrash() {
        let ports = PortWatcher.listeningPorts(for: 0)
        _ = ports
    }

    // MARK: - Sendable 준수

    @Test("PortWatcher_Sendable준수")
    func portWatcher_isSendable() {
        let watcher = PortWatcher()
        let sendableCheck: any Sendable = watcher
        #expect(sendableCheck is PortWatcher)
    }
}
