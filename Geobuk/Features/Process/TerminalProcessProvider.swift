import Darwin
import Foundation
import Observation

/// TTY 보유 프로세스 정보 (터미널에서 실행된 프로세스만)
struct TerminalProcess: Identifiable, Sendable {
    let pid: pid_t
    let name: String
    let command: String       // 전체 명령어 (args)
    let tty: String           // TTY 이름 (ttys001 등)
    let cpuPercent: Double    // CPU 사용률
    let memoryMB: UInt64      // RSS (MB)
    let elapsedSeconds: Int   // 실행 시간 (초)
    let listeningPorts: [UInt16]  // 리스닝 포트 목록

    var id: pid_t { pid }

    /// 실행 시간을 사람이 읽을 수 있는 형태로 변환
    var formattedUptime: String {
        if elapsedSeconds < 60 { return "\(elapsedSeconds)s" }
        if elapsedSeconds < 3600 { return "\(elapsedSeconds / 60)m \(elapsedSeconds % 60)s" }
        let hours = elapsedSeconds / 3600
        let mins = (elapsedSeconds % 3600) / 60
        return "\(hours)h \(mins)m"
    }
}

/// TTY 보유 프로세스를 주기적으로 수집하는 프로바이더
@MainActor
@Observable
final class TerminalProcessProvider {

    /// 수집된 프로세스 목록 (CPU 사용률 내림차순)
    private(set) var processes: [TerminalProcess] = []

    /// 폴링 태스크
    private var pollingTask: Task<Void, Never>?

    /// 폴링 간격 (초)
    static let pollingInterval: TimeInterval = 3.0

    // MARK: - 모니터링 제어

    func startMonitoring() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let result = await Task.detached(priority: .utility) {
                    TerminalProcessProvider.fetchTerminalProcesses()
                }.value
                self.processes = result
                try? await Task.sleep(for: .seconds(Self.pollingInterval))
            }
        }
    }

    func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - 편의 접근자

    /// CPU 사용률 상위 프로세스
    var topByCPU: [TerminalProcess] {
        processes.sorted { $0.cpuPercent > $1.cpuPercent }
    }

    /// 메모리 사용량 상위 프로세스
    var topByMemory: [TerminalProcess] {
        processes.sorted { $0.memoryMB > $1.memoryMB }
    }

    /// 리스닝 포트가 있는 프로세스
    var withPorts: [TerminalProcess] {
        processes.filter { !$0.listeningPorts.isEmpty }
    }

    /// 5분 이상 실행 중인 프로세스 (실행 시간 내림차순)
    var longRunning: [TerminalProcess] {
        processes.filter { $0.elapsedSeconds >= 300 }
            .sorted { $0.elapsedSeconds > $1.elapsedSeconds }
    }

    // MARK: - 데이터 수집

    /// TTY 보유 프로세스를 수집한다 (nonisolated, 백그라운드 호출 가능)
    nonisolated static func fetchTerminalProcesses() -> [TerminalProcess] {
        let psOutput = ProcessRunner.run(
            "/bin/ps",
            arguments: ["-eo", "pid,tty,pcpu,rss,etime,args"]
        ).output
        guard let psOutput else { return [] }

        let portMap = fetchListeningPortMap()
        return parsePsOutput(psOutput, portMap: portMap)
    }

    /// ps 출력을 파싱한다
    nonisolated static func parsePsOutput(_ output: String, portMap: [pid_t: [UInt16]] = [:]) -> [TerminalProcess] {
        let shellNames: Set<String> = ["zsh", "-zsh", "bash", "-bash", "login", "sh", "fish"]
        let skipNames: Set<String> = ["ps", "grep", "awk", "sed", "cat", "tail"]
        var results: [TerminalProcess] = []

        let lines = output.components(separatedBy: "\n")
        for line in lines.dropFirst() { // 헤더 건너뜀
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // pid tty %cpu rss etime args (6개 필드, 마지막은 공백 포함 가능)
            let parts = trimmed.split(separator: " ", maxSplits: 5, omittingEmptySubsequences: true)
            guard parts.count >= 6 else { continue }

            guard let pid = pid_t(parts[0]) else { continue }
            let tty = String(parts[1])
            guard tty != "??" else { continue }

            guard let cpu = Double(parts[2]) else { continue }
            guard let rssKB = UInt64(parts[3]) else { continue }
            let etime = String(parts[4])
            let args = String(parts[5])

            let name = extractProcessName(from: args)

            if shellNames.contains(name) { continue }
            if skipNames.contains(name) { continue }
            if name.hasPrefix("<") { continue } // <defunct> 등 제외

            let elapsed = parseElapsedTime(etime)
            let ports = portMap[pid] ?? []

            results.append(TerminalProcess(
                pid: pid,
                name: name,
                command: args,
                tty: tty,
                cpuPercent: cpu,
                memoryMB: rssKB / 1024,
                elapsedSeconds: elapsed,
                listeningPorts: ports
            ))
        }

        return results.sorted { $0.cpuPercent > $1.cpuPercent }
    }

    /// PID → 리스닝 포트 맵을 구축한다
    nonisolated private static func fetchListeningPortMap() -> [pid_t: [UInt16]] {
        let output = ProcessRunner.run(
            "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpn"]
        ).output
        guard let output else { return [:] }
        return parseLsofForPortMap(output)
    }

    /// lsof -Fpn 출력을 파싱하여 PID → 포트 맵을 반환한다
    nonisolated static func parseLsofForPortMap(_ output: String) -> [pid_t: [UInt16]] {
        var portMap: [pid_t: [UInt16]] = [:]
        var currentPid: pid_t = 0

        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("p") {
                // "p12345" → PID
                if let pid = pid_t(line.dropFirst()) {
                    currentPid = pid
                }
            } else if line.hasPrefix("n") {
                // "n*:3000" or "n127.0.0.1:8080"
                guard let colonIdx = line.lastIndex(of: ":") else { continue }
                let portStr = String(line[line.index(after: colonIdx)...])
                if let port = UInt16(portStr), currentPid > 0 {
                    portMap[currentPid, default: []].append(port)
                }
            }
        }

        return portMap
    }

    /// args 문자열에서 프로세스 이름을 추출한다
    nonisolated private static func extractProcessName(from args: String) -> String {
        let firstArg = args.split(separator: " ").first.map(String.init) ?? args
        // /usr/bin/node → node
        return (firstArg as NSString).lastPathComponent
    }

    /// etime 형식을 초로 변환한다 (MM:SS, HH:MM:SS, D-HH:MM:SS)
    nonisolated static func parseElapsedTime(_ etime: String) -> Int {
        let trimmed = etime.trimmingCharacters(in: .whitespaces)

        // D-HH:MM:SS 형식
        if trimmed.contains("-") {
            let dayParts = trimmed.split(separator: "-")
            guard dayParts.count == 2, let days = Int(dayParts[0]) else { return 0 }
            return days * 86400 + parseHMS(String(dayParts[1]))
        }

        return parseHMS(trimmed)
    }

    /// HH:MM:SS 또는 MM:SS 를 초로 변환
    nonisolated private static func parseHMS(_ str: String) -> Int {
        let parts = str.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 2: return parts[0] * 60 + parts[1]       // MM:SS
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]  // HH:MM:SS
        default: return 0
        }
    }

}
