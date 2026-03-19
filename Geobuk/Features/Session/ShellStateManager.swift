import Foundation

/// 셸의 상태 정보 (prompt 대기 중 또는 명령 실행 중)
struct ShellState: Sendable {
    /// "prompt" (유휴) 또는 "running" (명령 실행 중)
    let state: String
    /// 실행 중인 명령어 (state가 "running"일 때만 유효)
    let command: String?
    /// 상태가 마지막으로 업데이트된 시각
    let updatedAt: Date
}

/// Surface별 TTY 이름과 셸 상태를 추적하는 매니저
/// 셸 통합 스크립트가 소켓을 통해 보고하는 정보를 저장한다
@MainActor
@Observable
final class ShellStateManager {
    /// surfaceId -> TTY 이름 (예: "/dev/ttys001")
    private(set) var ttyNames: [String: String] = [:]

    /// surfaceId -> 셸 상태
    private(set) var shellStates: [String: ShellState] = [:]

    /// TTY 이름을 등록한다
    func reportTty(surfaceId: String, tty: String) {
        ttyNames[surfaceId] = tty
        GeobukLogger.info(.shell, "TTY reported", context: ["surfaceId": surfaceId, "tty": tty])
    }

    /// 셸 상태를 업데이트한다
    func reportState(surfaceId: String, state: String, command: String?) {
        shellStates[surfaceId] = ShellState(
            state: state,
            command: command,
            updatedAt: Date()
        )
        GeobukLogger.debug(.shell, "Shell state changed", context: ["surfaceId": surfaceId, "state": state, "command": command ?? ""])

        // 프롬프트 상태로 전환 시 알림 발송 (명령 완료 감지용)
        if state == "prompt" {
            NotificationCenter.default.post(
                name: .geobukShellPromptReady,
                object: nil,
                userInfo: ["surfaceId": surfaceId]
            )
        }
    }

    /// Surface 제거 시 관련 데이터를 정리한다
    func removeSurface(surfaceId: String) {
        ttyNames.removeValue(forKey: surfaceId)
        shellStates.removeValue(forKey: surfaceId)
        GeobukLogger.debug(.shell, "Surface removed", context: ["surfaceId": surfaceId])
    }

}

// MARK: - Notifications

extension Notification.Name {
    /// 셸이 프롬프트 상태로 전환될 때 발생 (userInfo: ["surfaceId": String])
    static let geobukShellPromptReady = Notification.Name("geobukShellPromptReady")
}

extension ShellStateManager {
    /// 사이드바 표시용 프로세스 이름을 반환한다
    func displayProcessName(for surfaceId: String) -> String? {
        guard let shellState = shellStates[surfaceId] else { return nil }
        if shellState.state == "running", let command = shellState.command {
            return command
        }
        return nil
    }

    /// 패널의 TTY에서 실행 중인 프로세스 목록 (셸 제외)
    func processesForSurface(_ surfaceId: String) -> [ProcInfo] {
        guard let tty = ttyNames[surfaceId] else { return [] }
        // /dev/ttys014 → ttys014
        let ttyShort = tty.replacingOccurrences(of: "/dev/", with: "")
        return Self.processesOnTTY(ttyShort)
    }

    /// 패널의 프로세스들이 리스닝하는 포트 목록
    func listeningPortsForSurface(_ surfaceId: String) -> [UInt16] {
        let procs = processesForSurface(surfaceId)
        guard !procs.isEmpty else { return [] }
        let pids = procs.map { $0.pid }
        return Self.listeningPortsForPIDs(pids)
    }

    /// TTY에서 실행 중인 프로세스 조회 (ps -t)
    private static func processesOnTTY(_ ttyName: String) -> [ProcInfo] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-t", ttyName, "-o", "pid=,comm="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
        } catch { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var results: [ProcInfo] = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
            guard parts.count == 2, let pid = Int32(parts[0]) else { continue }
            let name = String(parts[1])
            // 셸 자체는 제외 (zsh, bash, login)
            let shellNames = ["zsh", "-zsh", "bash", "-bash", "login", "sh"]
            if shellNames.contains(name) || name.hasSuffix("/zsh") || name.hasSuffix("/bash") { continue }
            results.append(ProcInfo(pid: pid, parentPid: 0, name: name))
        }
        return results
    }

    /// PID 목록의 리스닝 포트 조회 (lsof)
    private static func listeningPortsForPIDs(_ pids: [pid_t]) -> [UInt16] {
        guard !pids.isEmpty else { return [] }
        let pidList = pids.map { String($0) }.joined(separator: ",")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-nP", "-a", "-p", pidList, "-iTCP", "-sTCP:LISTEN", "-Fn"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
        } catch { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var ports: Set<UInt16> = []
        for line in output.components(separatedBy: "\n") {
            // "n*:3000" or "n127.0.0.1:8080"
            guard line.hasPrefix("n"), let colonIdx = line.lastIndex(of: ":") else { continue }
            let portStr = String(line[line.index(after: colonIdx)...])
            if let port = UInt16(portStr) {
                ports.insert(port)
            }
        }
        return Array(ports).sorted()
    }
}
