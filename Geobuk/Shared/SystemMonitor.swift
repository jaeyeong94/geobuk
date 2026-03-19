import Darwin
import Foundation
import Observation

// MARK: - Data Models

/// 프로세스 CPU/메모리 정보
struct ProcessStat: Identifiable, Sendable {
    let pid: pid_t
    let name: String
    let cpuPercent: Double
    let memoryMB: UInt64
    var id: pid_t { pid }
}

/// 리스닝 포트 정보
struct PortInfo: Identifiable, Sendable {
    let pid: pid_t
    let processName: String
    let port: UInt16
    let address: String
    var id: String { "\(pid)-\(port)" }
}

// MARK: - Internal Network Bytes Result

struct NetworkBytesResult: Sendable {
    let bytesIn: UInt64
    let bytesOut: UInt64
}

// MARK: - SystemMonitor

/// 시스템 리소스 모니터 (CPU, Memory, Network, Process, Port)
@MainActor
@Observable
final class SystemMonitor {

    // MARK: - Public State

    /// 시스템 CPU 사용률 (0.0 ~ 1.0)
    private(set) var cpuUsage: Double = 0

    /// 시스템 메모리 (MB)
    private(set) var memoryUsed: UInt64 = 0
    private(set) var memoryTotal: UInt64 = 0

    /// 네트워크 I/O (bytes/sec)
    private(set) var networkBytesIn: UInt64 = 0
    private(set) var networkBytesOut: UInt64 = 0

    /// CPU 사용률 상위 프로세스
    private(set) var topProcessesByCPU: [ProcessStat] = []

    /// Memory 사용률 상위 프로세스
    private(set) var topProcessesByMemory: [ProcessStat] = []

    /// 사용자 리스닝 포트 목록
    private(set) var listeningPorts: [PortInfo] = []

    // MARK: - Private State

    private var pollingTask: Task<Void, Never>?
    private var previousCPUTicks: CPUTicksSnapshot?
    private var previousNetworkBytes: NetworkBytesResult?
    private var portRefreshCounter: Int = 0

    /// 포트 갱신 주기 (3초 폴링 * 10 = 30초마다)
    private static let portRefreshEvery: Int = 10

    // MARK: - 모니터링 제어

    /// 모니터링 시작 (폴링 간격: 3초)
    func startMonitoring() {
        guard pollingTask == nil else { return }
        GeobukLogger.info(.process, "SystemMonitor started")

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    /// 모니터링 중지
    func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
        GeobukLogger.info(.process, "SystemMonitor stopped")
    }

    // MARK: - 폴링 사이클

    private func tick() async {
        updateCPU()
        updateMemory()
        updateNetwork()
        await updateTopProcesses()
        portRefreshCounter += 1
        if portRefreshCounter >= Self.portRefreshEvery {
            portRefreshCounter = 0
            await updateListeningPorts()
        }
    }

    // MARK: - CPU

    private struct CPUTicksSnapshot {
        let user: UInt64
        let system: UInt64
        let idle: UInt64
        let nice: UInt64
    }

    private func readCPUTicks() -> CPUTicksSnapshot? {
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicksSnapshot(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    private func updateCPU() {
        guard let current = readCPUTicks() else { return }
        defer { previousCPUTicks = current }
        guard let prev = previousCPUTicks else { return }

        let userDelta = current.user > prev.user ? current.user - prev.user : 0
        let systemDelta = current.system > prev.system ? current.system - prev.system : 0
        let idleDelta = current.idle > prev.idle ? current.idle - prev.idle : 0
        let niceDelta = current.nice > prev.nice ? current.nice - prev.nice : 0

        cpuUsage = Self.cpuUsageFromDeltas(
            userDelta: userDelta,
            systemDelta: systemDelta,
            idleDelta: idleDelta,
            niceDelta: niceDelta
        )
    }

    // MARK: - Memory

    nonisolated static func readTotalMemory() -> UInt64 {
        var size: size_t = MemoryLayout<UInt64>.size
        var value: UInt64 = 0
        withUnsafeMutablePointer(to: &value) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: size) { bytes in
                var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
                sysctl(&mib, 2, bytes, &size, nil, 0)
            }
        }
        return value
    }

    private func updateMemory() {
        memoryTotal = Self.readTotalMemory() / 1024 / 1024

        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        var info = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let ps = UInt64(pageSize)
        let active = UInt64(info.active_count)
        let inactive = UInt64(info.inactive_count)
        let wired = UInt64(info.wire_count)
        memoryUsed = (active + inactive + wired) * ps / 1024 / 1024
    }

    // MARK: - Network I/O

    nonisolated static func readNetworkBytes(interface: String = "en0") -> NetworkBytesResult {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return NetworkBytesResult(bytesIn: 0, bytesOut: 0) }
        defer { freeifaddrs(ifaddr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var cursor = ifaddr
        while let current = cursor {
            let name = String(cString: current.pointee.ifa_name)
            if name == interface,
               current.pointee.ifa_addr != nil,
               current.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK),
               let data = current.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                totalIn += UInt64(data.pointee.ifi_ibytes)
                totalOut += UInt64(data.pointee.ifi_obytes)
            }
            cursor = current.pointee.ifa_next
        }
        return NetworkBytesResult(bytesIn: totalIn, bytesOut: totalOut)
    }

    private func updateNetwork() {
        let current = Self.readNetworkBytes()
        defer { previousNetworkBytes = current }
        guard let prev = previousNetworkBytes else { return }

        let inDelta = current.bytesIn >= prev.bytesIn ? current.bytesIn - prev.bytesIn : 0
        let outDelta = current.bytesOut >= prev.bytesOut ? current.bytesOut - prev.bytesOut : 0

        // bytes/sec (폴링 간격 3초로 나눔)
        networkBytesIn = inDelta / 3
        networkBytesOut = outDelta / 3
    }

    // MARK: - Top Processes

    private func updateTopProcesses() async {
        let stats = await Task.detached(priority: .utility) {
            SystemMonitor.fetchProcessStats()
        }.value

        topProcessesByCPU = Array(stats.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(10))
        topProcessesByMemory = Array(stats.sorted { $0.memoryMB > $1.memoryMB }.prefix(10))
    }

    /// proc_listallpids + proc_pidinfo로 프로세스 목록과 메모리를 읽는다
    /// subprocess 없이 native Darwin API를 사용한다
    nonisolated static func fetchProcessStats() -> [ProcessStat] {
        let estimatedCount = proc_listallpids(nil, 0)
        guard estimatedCount > 0 else { return [] }

        let bufferSize = Int(estimatedCount) * 2
        var pids = [pid_t](repeating: 0, count: bufferSize)
        let actualBytes = proc_listallpids(&pids, Int32(bufferSize * MemoryLayout<pid_t>.size))
        guard actualBytes > 0 else { return [] }

        let actualCount = Int(actualBytes) / MemoryLayout<pid_t>.size
        var stats: [ProcessStat] = []
        stats.reserveCapacity(actualCount)

        for i in 0..<actualCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var taskInfo = proc_taskallinfo()
            let taskInfoSize = Int32(MemoryLayout<proc_taskallinfo>.size)
            let ret = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &taskInfo, taskInfoSize)
            guard ret > 0 else { continue }

            // 메모리: resident size (bytes → MB)
            let memoryMB = taskInfo.ptinfo.pti_resident_size / (1024 * 1024)

            // CPU: total_user + total_system (나노초) — 누적값 기반 상대 순위
            let cpuNano = taskInfo.ptinfo.pti_total_user + taskInfo.ptinfo.pti_total_system
            let cpuScore = Double(cpuNano) / 1e9

            var nameBuffer = [CChar](repeating: 0, count: 4096)
            let nameLen = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name = nameLen > 0 ? String(cString: nameBuffer) : "unknown"

            stats.append(ProcessStat(pid: pid, name: name, cpuPercent: cpuScore, memoryMB: memoryMB))
        }

        return stats
    }

    nonisolated static func parsePsOutput(_ output: String) -> [ProcessStat] {
        var stats: [ProcessStat] = []
        let lines = output.components(separatedBy: "\n")
        // 헤더 라인 건너뜀
        for line in lines.dropFirst() {
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count >= 4 else { continue }
            guard let pid = pid_t(parts[0]),
                  let cpu = Double(parts[1]),
                  let rssKB = UInt64(parts[2]) else { continue }
            let name = String(parts[3]).components(separatedBy: "/").last ?? String(parts[3])
            stats.append(ProcessStat(
                pid: pid,
                name: name,
                cpuPercent: cpu,
                memoryMB: rssKB / 1024
            ))
        }
        return stats
    }

    // MARK: - Listening Ports

    private func updateListeningPorts() async {
        let ports = await Task.detached(priority: .utility) {
            SystemMonitor.fetchListeningPorts()
        }.value
        listeningPorts = ports
    }

    nonisolated(unsafe) static let systemProcessNames: Set<String> = [
        "launchd", "mDNSResponder", "rapportd", "sharingd",
        "ControlCenter", "loginwindow", "configd", "airportd",
        "SystemUIServer", "distnoted", "lsd", "nsurlsessiond",
        "CommCenter", "syncdefaultsd"
    ]

    /// lsof로 리스닝 포트 목록을 읽는다 (nonisolated — 백그라운드 태스크에서 호출 가능)
    nonisolated static func fetchListeningPorts() -> [PortInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return parseLsofPortOutput(output)
    }

    nonisolated static func parseLsofPortOutput(_ output: String) -> [PortInfo] {
        var ports: [PortInfo] = []
        var seen: Set<String> = []
        let lines = output.components(separatedBy: "\n")

        for line in lines.dropFirst() {
            guard line.contains("LISTEN") else { continue }
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            // lsof columns: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            guard cols.count >= 9 else { continue }

            let processName = String(cols[0])
            guard let pid = pid_t(cols[1]) else { continue }

            // Skip system processes
            guard !systemProcessNames.contains(processName) else { continue }

            // lsof real format: "host:port (LISTEN)" = two tokens
            // NAME column is second-to-last; last is "(LISTEN)"
            guard cols.count >= 10 else { continue }
            let nameCol = String(cols[cols.count - 2])
            guard let lastColon = nameCol.lastIndex(of: ":") else { continue }
            let portStr = String(nameCol[nameCol.index(after: lastColon)...])
                .replacingOccurrences(of: "(LISTEN)", with: "")
                .trimmingCharacters(in: .whitespaces)
            guard let port = UInt16(portStr) else { continue }

            let hostPart = String(nameCol[..<lastColon])
            let address = hostPart == "*" ? "*" : hostPart

            let key = "\(pid)-\(port)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            ports.append(PortInfo(pid: pid, processName: processName, port: port, address: address))
        }

        return ports.sorted { $0.port < $1.port }
    }
}

// MARK: - CPU Delta Calculator (testable)

extension SystemMonitor {
    /// CPU 델타에서 사용률을 계산한다 (테스트용)
    nonisolated static func cpuUsageFromDeltas(userDelta: UInt64, systemDelta: UInt64, idleDelta: UInt64, niceDelta: UInt64) -> Double {
        let total = userDelta + systemDelta + idleDelta + niceDelta
        guard total > 0 else { return 0 }
        return Double(userDelta + systemDelta) / Double(total)
    }
}
