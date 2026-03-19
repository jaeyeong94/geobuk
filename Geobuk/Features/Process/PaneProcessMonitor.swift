import Foundation
import Observation

/// 패널에서 감지된 Claude 프로세스 정보
struct ClaudePaneInfo: Sendable {
    let paneId: UUID
    let claudePid: pid_t
    let processName: String
    let detectedAt: Date
}

/// 패널별 프로세스를 주기적으로 스캔하여 Claude 세션을 감지하는 모니터
/// 각 패널의 PTY 자식 프로세스를 탐색하여 Claude Code 프로세스를 찾는다
@MainActor
@Observable
final class PaneProcessMonitor {

    /// 패널별 감지된 Claude 프로세스 정보 (paneId -> info)
    private(set) var claudeProcesses: [UUID: ClaudePaneInfo] = [:]

    /// 모니터링 중인지 여부
    private(set) var isMonitoring: Bool = false

    /// 폴링 태스크
    private var pollingTask: Task<Void, Never>?

    /// 앱 프로세스 PID (자식 프로세스 탐색의 시작점)
    private var appPid: pid_t = 0

    /// 포커스된 워크스페이스의 패널 ID 목록 (적응형 폴링용)
    private var focusedPaneIds: Set<UUID> = []

    /// 폴링 간격 (초) - 포커스 상태
    static let focusedPollingInterval: TimeInterval = 2.0

    /// 폴링 간격 (초) - 백그라운드 상태
    static let backgroundPollingInterval: TimeInterval = 10.0

    // MARK: - 모니터링 제어

    /// 모니터링을 시작한다
    /// - Parameter appPid: 앱 프로세스 PID (기본값: 현재 프로세스)
    func startMonitoring(appPid: pid_t = getpid()) {
        // 이미 모니터링 중이면 기존 태스크를 중지
        pollingTask?.cancel()

        self.appPid = appPid
        isMonitoring = true
        GeobukLogger.info(.process, "Process monitoring started", context: ["appPid": "\(appPid)"])

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.scanProcesses()
                try? await Task.sleep(for: .seconds(Self.focusedPollingInterval))
            }
        }
    }

    /// 모니터링을 중지한다
    func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
        isMonitoring = false
        claudeProcesses.removeAll()
        GeobukLogger.info(.process, "Process monitoring stopped")
    }

    /// 포커스된 패널 ID 목록을 업데이트한다 (적응형 폴링용)
    func updateFocusedPanes(_ paneIds: Set<UUID>) {
        focusedPaneIds = paneIds
    }

    // MARK: - 워크스페이스별 정보

    /// 워크스페이스의 패널에서 감지된 Claude 세션 수를 반환한다
    func claudeSessionCount(for workspace: Workspace) -> Int {
        let paneIds = Set(workspace.splitManager.root.allLeaves().map(\.id))
        return claudeProcesses.values.filter { paneIds.contains($0.paneId) }.count
    }

    /// 워크스페이스별 총 비용을 반환한다 (추후 연동)
    func totalCost(for workspace: Workspace) -> Double {
        return 0.0
    }

    // MARK: - 프로세스 스캔

    /// 앱의 모든 자식 프로세스를 스캔하여 Claude 세션을 감지한다
    private func scanProcesses() async {
        guard isMonitoring else { return }

        let all = ProcessTreeScanner.allProcesses()
        // 앱의 직계 자식 찾기 (shell/login 프로세스들)
        let appChildren = all.filter { $0.parentPid == appPid }

        var newClaudeProcesses: [UUID: ClaudePaneInfo] = [:]

        GeobukLogger.debug(.process, "Scan cycle", context: ["children": "\(appChildren.count)", "totalProcesses": "\(all.count)"])

        // 각 직계 자식의 서브트리에서 Claude 프로세스 탐색
        for child in appChildren {
            if let claudeProc = findClaudeInSubtree(pid: child.pid, allProcesses: all) {
                // 직계 자식의 PID를 기반으로 패널 매핑 시도
                // 현재는 임시로 UUID를 생성 (실제로는 surface-PID 매핑 필요)
                // 기존에 같은 Claude PID로 감지된 항목이 있으면 재사용
                if let existing = claudeProcesses.values.first(where: { $0.claudePid == claudeProc.pid }) {
                    newClaudeProcesses[existing.paneId] = existing
                } else {
                    let paneId = UUID() // 실제 패널 매핑은 Phase 6에서
                    newClaudeProcesses[paneId] = ClaudePaneInfo(
                        paneId: paneId,
                        claudePid: claudeProc.pid,
                        processName: claudeProc.name,
                        detectedAt: Date()
                    )
                    GeobukLogger.info(.process, "Claude process detected", context: ["pid": "\(claudeProc.pid)", "name": claudeProc.name])
                }
            }
        }

        // 사라진 Claude 프로세스 감지
        let lostPids = Set(claudeProcesses.values.map(\.claudePid)).subtracting(newClaudeProcesses.values.map(\.claudePid))
        for pid in lostPids {
            GeobukLogger.info(.process, "Claude process lost", context: ["pid": "\(pid)"])
        }

        claudeProcesses = newClaudeProcesses
    }

    /// 특정 PID의 서브트리에서 Claude 프로세스를 찾는다
    private func findClaudeInSubtree(pid: pid_t, allProcesses: [ProcInfo]) -> ProcInfo? {
        // 자기 자신이 Claude인지 확인
        if let proc = allProcesses.first(where: { $0.pid == pid }) {
            let lowerName = proc.name.lowercased()
            if lowerName.contains("claude") {
                return proc
            }
        }

        // 자식 프로세스 재귀 탐색
        let children = allProcesses.filter { $0.parentPid == pid }
        for child in children {
            if let found = findClaudeInSubtree(pid: child.pid, allProcesses: allProcesses) {
                return found
            }
        }
        return nil
    }
}
