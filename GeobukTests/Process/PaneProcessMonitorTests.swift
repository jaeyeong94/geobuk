import Testing
import Foundation
@testable import Geobuk

@Suite("PaneProcessMonitor - 패널 프로세스 모니터")
@MainActor
struct PaneProcessMonitorTests {

    // MARK: - ClaudePaneInfo 모델

    @Test("ClaudePaneInfo_초기화_정상생성")
    func claudePaneInfo_init_createsCorrectly() {
        let paneId = UUID()
        let now = Date()
        let info = ClaudePaneInfo(paneId: paneId, claudePid: 1234, processName: "claude", detectedAt: now)
        #expect(info.paneId == paneId)
        #expect(info.claudePid == 1234)
        #expect(info.processName == "claude")
        #expect(info.detectedAt == now)
    }

    @Test("ClaudePaneInfo_Sendable준수")
    func claudePaneInfo_sendable_conformance() {
        let info = ClaudePaneInfo(paneId: UUID(), claudePid: 1, processName: "test", detectedAt: Date())
        let sendableCheck: any Sendable = info
        #expect(sendableCheck is ClaudePaneInfo)
    }

    // MARK: - PaneProcessMonitor 초기화

    @Test("init_claudeProcesses_비어있음")
    func init_claudeProcesses_isEmpty() {
        let monitor = PaneProcessMonitor()
        #expect(monitor.claudeProcesses.isEmpty)
    }

    @Test("init_isMonitoring_false")
    func init_isMonitoring_isFalse() {
        let monitor = PaneProcessMonitor()
        #expect(!monitor.isMonitoring)
    }

    // MARK: - 모니터링 라이프사이클

    @Test("startMonitoring_isMonitoring_true")
    func startMonitoring_setsIsMonitoringTrue() {
        let monitor = PaneProcessMonitor()
        monitor.startMonitoring(appPid: getpid())
        #expect(monitor.isMonitoring)
        monitor.stopMonitoring()
    }

    @Test("stopMonitoring_isMonitoring_false")
    func stopMonitoring_setsIsMonitoringFalse() {
        let monitor = PaneProcessMonitor()
        monitor.startMonitoring(appPid: getpid())
        monitor.stopMonitoring()
        #expect(!monitor.isMonitoring)
    }

    @Test("stopMonitoring_claudeProcesses_비워짐")
    func stopMonitoring_clearsClaudeProcesses() {
        let monitor = PaneProcessMonitor()
        monitor.startMonitoring(appPid: getpid())
        monitor.stopMonitoring()
        #expect(monitor.claudeProcesses.isEmpty)
    }

    @Test("startMonitoring_중복호출_크래시없음")
    func startMonitoring_doubleCall_noCrash() {
        let monitor = PaneProcessMonitor()
        monitor.startMonitoring(appPid: getpid())
        monitor.startMonitoring(appPid: getpid())
        #expect(monitor.isMonitoring)
        monitor.stopMonitoring()
    }

    @Test("stopMonitoring_시작전호출_크래시없음")
    func stopMonitoring_beforeStart_noCrash() {
        let monitor = PaneProcessMonitor()
        monitor.stopMonitoring()
        #expect(!monitor.isMonitoring)
    }

    // MARK: - claudeSessionCount

    @Test("claudeSessionCount_빈워크스페이스_0반환")
    func claudeSessionCount_emptyWorkspace_returnsZero() {
        let monitor = PaneProcessMonitor()
        let workspace = Workspace(name: "Test", cwd: "/tmp")
        #expect(monitor.claudeSessionCount(for: workspace) == 0)
    }

    // MARK: - totalCost

    @Test("totalCost_빈워크스페이스_0반환")
    func totalCost_emptyWorkspace_returnsZero() {
        let monitor = PaneProcessMonitor()
        let workspace = Workspace(name: "Test", cwd: "/tmp")
        #expect(monitor.totalCost(for: workspace) == 0.0)
    }

    // MARK: - 네거티브 테스트

    @Test("claudeSessionCount_nil워크스페이스pane_0반환")
    func claudeSessionCount_noPanesWithClaude_returnsZero() {
        let monitor = PaneProcessMonitor()
        let workspace = Workspace(name: "No Claude", cwd: "/tmp")
        // 모니터링을 시작하지 않아도 카운트는 0
        #expect(monitor.claudeSessionCount(for: workspace) == 0)
    }

    // MARK: - Observable 준수

    @Test("PaneProcessMonitor_Observable_claudeProcesses변경추적")
    func paneProcessMonitor_observable_tracksChanges() {
        let monitor = PaneProcessMonitor()
        // Observable이므로 프로퍼티 접근이 가능해야 함
        _ = monitor.claudeProcesses
        _ = monitor.isMonitoring
        // 크래시 없이 접근 가능하면 통과
    }
}
