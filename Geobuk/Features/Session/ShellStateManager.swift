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

    /// surfaceId -> 캐시된 리스닝 포트
    private(set) var cachedListeningPorts: [String: [UInt16]] = [:]

    /// 포트/프로세스 폴링 태스크
    private var portPollingTask: Task<Void, Never>?

    /// TTY 이름이 유효한 형식인지 검증한다
    /// 허용 패턴: /dev/ttys?[0-9]+ 또는 ttys?[0-9]+
    nonisolated static func isValidTTYName(_ tty: String) -> Bool {
        guard !tty.isEmpty, !tty.contains("\0"), !tty.contains(" ") else { return false }
        // /dev/ 접두사 제거
        let name = tty.hasPrefix("/dev/") ? String(tty.dropFirst(5)) : tty
        // ttys?[0-9]+ 패턴 검증
        guard name.hasPrefix("tty") else { return false }
        let afterTty = name.dropFirst(3) // "tty" 이후
        let digits: Substring
        if afterTty.hasPrefix("s") {
            digits = afterTty.dropFirst(1) // "ttys" 이후
        } else {
            digits = afterTty // "tty" 이후
        }
        return !digits.isEmpty && digits.allSatisfy(\.isNumber)
    }

    /// TTY 이름을 등록한다 (유효하지 않은 TTY 이름은 거부)
    func reportTty(surfaceId: String, tty: String) {
        guard Self.isValidTTYName(tty) else {
            GeobukLogger.warn(.shell, "Invalid TTY name rejected", context: ["surfaceId": surfaceId, "tty": tty])
            return
        }
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

        // 셸 상태 전환 알림
        if state == "prompt" {
            NotificationCenter.default.post(
                name: .geobukShellPromptReady,
                object: nil,
                userInfo: ["surfaceId": surfaceId]
            )
        } else if state == "running" {
            NotificationCenter.default.post(
                name: .geobukShellCommandStarted,
                object: nil,
                userInfo: ["surfaceId": surfaceId, "command": command ?? ""]
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
    /// 셸이 명령 실행을 시작할 때 발생 (userInfo: ["surfaceId": String, "command": String])
    static let geobukShellCommandStarted = Notification.Name("geobukShellCommandStarted")
    /// 터미널 검색 상태 변경 (검색 시작/종료/결과 업데이트)
    static let geobukSearchStateChanged = Notification.Name("geobukSearchStateChanged")
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

    // MARK: - Cached Process/Port Info (비동기 갱신)

    /// 포트/프로세스 정보 폴링을 시작한다 (5초 주기)
    func startPortPolling() {
        guard portPollingTask == nil else { return }
        portPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshPortsForAllSurfaces()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    /// 포트/프로세스 정보 폴링을 중지한다
    func stopPortPolling() {
        portPollingTask?.cancel()
        portPollingTask = nil
    }

    /// 패널의 캐시된 리스닝 포트를 반환한다 (동기, View에서 안전하게 호출 가능)
    func listeningPortsForSurface(_ surfaceId: String) -> [UInt16] {
        cachedListeningPorts[surfaceId] ?? []
    }

    /// 모든 surface의 포트 정보를 백그라운드에서 갱신한다
    private func refreshPortsForAllSurfaces() async {
        let surfaceIds = Array(ttyNames.keys)
        let ttyMap = ttyNames

        let results = await Task.detached(priority: .utility) {
            var portMap: [String: [UInt16]] = [:]
            for surfaceId in surfaceIds {
                guard let tty = ttyMap[surfaceId] else { continue }
                let ttyShort = tty.replacingOccurrences(of: "/dev/", with: "")
                let procs = ShellStateManager.processesOnTTY(ttyShort)
                guard !procs.isEmpty else { continue }
                let pids = procs.map { $0.pid }
                let ports = ShellStateManager.listeningPortsForPIDs(pids)
                if !ports.isEmpty {
                    portMap[surfaceId] = ports
                }
            }
            return portMap
        }.value

        cachedListeningPorts = results
    }

    /// TTY에서 실행 중인 프로세스 조회 (ps -t)
    nonisolated static func processesOnTTY(_ ttyName: String) -> [ProcInfo] {
        guard let output = ProcessRunner.run("/bin/ps", arguments: ["-t", ttyName, "-o", "pid=,comm="]).output else {
            return []
        }
        return parsePsOutput(output)
    }

    /// ps 출력을 파싱한다
    nonisolated static func parsePsOutput(_ output: String) -> [ProcInfo] {
        let shellNames: Set<String> = ["zsh", "-zsh", "bash", "-bash", "login", "sh"]
        var results: [ProcInfo] = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
            guard parts.count == 2, let pid = Int32(parts[0]) else { continue }
            let name = String(parts[1])
            if shellNames.contains(name) || name.hasSuffix("/zsh") || name.hasSuffix("/bash") { continue }
            results.append(ProcInfo(pid: pid, parentPid: 0, name: name))
        }
        return results
    }

    /// PID 목록의 리스닝 포트 조회 (lsof)
    nonisolated static func listeningPortsForPIDs(_ pids: [pid_t]) -> [UInt16] {
        guard !pids.isEmpty else { return [] }
        let pidList = pids.map { String($0) }.joined(separator: ",")

        guard let output = ProcessRunner.run("/usr/sbin/lsof", arguments: ["-nP", "-a", "-p", pidList, "-iTCP", "-sTCP:LISTEN", "-Fn"]).output else {
            return []
        }

        var ports: Set<UInt16> = []
        for line in output.components(separatedBy: "\n") {
            guard line.hasPrefix("n"), let colonIdx = line.lastIndex(of: ":") else { continue }
            let portStr = String(line[line.index(after: colonIdx)...])
            if let port = UInt16(portStr) {
                ports.insert(port)
            }
        }
        return Array(ports).sorted()
    }
}
