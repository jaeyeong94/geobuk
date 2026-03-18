import Darwin
import Foundation

/// 프로세스 정보를 나타내는 구조체
/// Foundation.ProcessInfo와의 이름 충돌을 피하기 위해 ProcInfo로 명명
struct ProcInfo: Sendable, Identifiable {
    let pid: pid_t
    let parentPid: pid_t
    let name: String

    var id: pid_t { pid }
}

/// 프로세스 트리 스캐너 (libproc 기반)
/// macOS의 libproc API를 사용하여 프로세스 트리를 탐색한다
final class ProcessTreeScanner: Sendable {

    /// 시스템의 모든 프로세스 목록을 반환한다
    static func allProcesses() -> [ProcInfo] {
        // 먼저 필요한 버퍼 크기를 구한다
        let estimatedCount = proc_listallpids(nil, 0)
        guard estimatedCount > 0 else { return [] }

        // 여유를 두고 버퍼를 할당한다
        let bufferSize = Int(estimatedCount) * 2
        var pids = [pid_t](repeating: 0, count: bufferSize)
        let actualBytes = proc_listallpids(&pids, Int32(bufferSize * MemoryLayout<pid_t>.size))
        guard actualBytes > 0 else { return [] }

        let actualCount = Int(actualBytes) / MemoryLayout<pid_t>.size
        var results: [ProcInfo] = []
        results.reserveCapacity(actualCount)

        for i in 0..<actualCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var info = proc_bsdinfo()
            let infoSize = Int32(MemoryLayout<proc_bsdinfo>.size)
            let ret = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, infoSize)
            guard ret == infoSize else { continue }

            let name = processName(for: pid)
            let parentPid = pid_t(info.pbi_ppid)
            results.append(ProcInfo(pid: pid, parentPid: parentPid, name: name))
        }

        return results
    }

    /// 주어진 PID의 모든 자식 프로세스를 반환한다
    static func childProcesses(of parentPid: pid_t) -> [ProcInfo] {
        guard parentPid >= 0 else { return [] }
        return allProcesses().filter { $0.parentPid == parentPid }
    }

    /// 주어진 PID의 자식 프로세스 트리에서 특정 이름의 프로세스를 검색한다
    /// 직계 자식뿐 아니라 손자 프로세스까지 재귀적으로 탐색한다
    static func findProcess(named name: String, under parentPid: pid_t) -> ProcInfo? {
        guard !name.isEmpty, parentPid >= 0 else { return nil }

        let all = allProcesses()
        return findProcessRecursive(named: name, under: parentPid, allProcesses: all)
    }

    /// 주어진 PID의 자식 프로세스 중 Claude Code 프로세스를 찾는다
    /// Claude Code는 "claude" 이름으로 실행되거나, Node.js 프로세스로 실행된다
    static func findClaudeProcess(under parentPid: pid_t) -> ProcInfo? {
        guard parentPid >= 0 else { return nil }

        let all = allProcesses()
        return findClaudeRecursive(under: parentPid, allProcesses: all)
    }

    // MARK: - Private

    /// 프로세스 이름을 가져온다
    private static func processName(for pid: pid_t) -> String {
        // MAXPATHLEN * 4 = 4096, PROC_PIDPATHINFO_MAXSIZE 대체
        var nameBuffer = [CChar](repeating: 0, count: 4096)
        let nameLength = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        if nameLength > 0 {
            return String(cString: nameBuffer)
        }
        return ""
    }

    /// 재귀적으로 프로세스 트리를 탐색하여 특정 이름의 프로세스를 찾는다
    private static func findProcessRecursive(
        named name: String,
        under parentPid: pid_t,
        allProcesses: [ProcInfo]
    ) -> ProcInfo? {
        let children = allProcesses.filter { $0.parentPid == parentPid }
        for child in children {
            if child.name.lowercased().contains(name.lowercased()) {
                return child
            }
            if let found = findProcessRecursive(named: name, under: child.pid, allProcesses: allProcesses) {
                return found
            }
        }
        return nil
    }

    /// 재귀적으로 Claude 프로세스를 탐색한다
    private static func findClaudeRecursive(
        under parentPid: pid_t,
        allProcesses: [ProcInfo]
    ) -> ProcInfo? {
        let children = allProcesses.filter { $0.parentPid == parentPid }
        for child in children {
            let lowerName = child.name.lowercased()
            if lowerName.contains("claude") {
                return child
            }
            if let found = findClaudeRecursive(under: child.pid, allProcesses: allProcesses) {
                return found
            }
        }
        return nil
    }
}
