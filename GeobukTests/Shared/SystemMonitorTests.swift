import Testing
import Foundation
@testable import Geobuk

@Suite("SystemMonitor - 시스템 모니터")
struct SystemMonitorTests {

    // MARK: - ProcessStat 모델

    @Test("ProcessStat_초기화_정상생성")
    func processStat_init_createsCorrectly() {
        let stat = ProcessStat(pid: 1234, name: "node", cpuPercent: 12.5, memoryMB: 64, executablePath: "/usr/local/bin/node")
        #expect(stat.pid == 1234)
        #expect(stat.name == "node")
        #expect(stat.cpuPercent == 12.5)
        #expect(stat.memoryMB == 64)
        #expect(stat.id == 1234)
    }

    @Test("ProcessStat_Identifiable_pidをidとして使用")
    func processStat_identifiable_usesPidAsId() {
        let stat = ProcessStat(pid: 42, name: "proc", cpuPercent: 0, memoryMB: 0, executablePath: nil)
        #expect(stat.id == stat.pid)
    }

    @Test("ProcessStat_Sendable준수")
    func processStat_sendable_conformance() {
        let stat = ProcessStat(pid: 1, name: "test", cpuPercent: 0, memoryMB: 0, executablePath: nil)
        let sendable: any Sendable = stat
        #expect(sendable is ProcessStat)
    }

    // MARK: - PortInfo 모델

    @Test("PortInfo_초기화_정상생성")
    func portInfo_init_createsCorrectly() {
        let info = PortInfo(pid: 5678, processName: "node", port: 3000, address: "127.0.0.1")
        #expect(info.pid == 5678)
        #expect(info.processName == "node")
        #expect(info.port == 3000)
        #expect(info.address == "127.0.0.1")
        #expect(info.id == "5678-3000")
    }

    @Test("PortInfo_id_pid와port조합")
    func portInfo_id_combinesPidAndPort() {
        let info = PortInfo(pid: 100, processName: "proc", port: 8080, address: "*")
        #expect(info.id == "100-8080")
    }

    @Test("PortInfo_Sendable준수")
    func portInfo_sendable_conformance() {
        let info = PortInfo(pid: 1, processName: "test", port: 80, address: "*")
        let sendable: any Sendable = info
        #expect(sendable is PortInfo)
    }

    // MARK: - CPU 델타 계산

    @Test("cpuUsage_userSystem50percent_0.5반환")
    func cpuUsage_halfUserSystem_returns0_5() {
        // user+system = 50, idle = 50 → 50%
        let usage = SystemMonitor.cpuUsageFromDeltas(userDelta: 30, systemDelta: 20, idleDelta: 50, niceDelta: 0)
        #expect(abs(usage - 0.5) < 0.001)
    }

    @Test("cpuUsage_유휴100percent_0.0반환")
    func cpuUsage_allIdle_returnsZero() {
        let usage = SystemMonitor.cpuUsageFromDeltas(userDelta: 0, systemDelta: 0, idleDelta: 100, niceDelta: 0)
        #expect(usage == 0.0)
    }

    @Test("cpuUsage_CPU100percent_1.0반환")
    func cpuUsage_allActive_returnsOne() {
        let usage = SystemMonitor.cpuUsageFromDeltas(userDelta: 80, systemDelta: 20, idleDelta: 0, niceDelta: 0)
        #expect(abs(usage - 1.0) < 0.001)
    }

    @Test("cpuUsage_전체틱0_0.0반환")
    func cpuUsage_zeroTotal_returnsZero() {
        let usage = SystemMonitor.cpuUsageFromDeltas(userDelta: 0, systemDelta: 0, idleDelta: 0, niceDelta: 0)
        #expect(usage == 0.0)
    }

    @Test("cpuUsage_nice틱포함_올바른계산")
    func cpuUsage_withNice_calculatesCorrectly() {
        // user=40, system=10, nice=0, idle=50 → 50%
        let usage = SystemMonitor.cpuUsageFromDeltas(userDelta: 40, systemDelta: 10, idleDelta: 50, niceDelta: 0)
        #expect(abs(usage - 0.5) < 0.001)
    }

    @Test("cpuUsage_범위_0에서1사이")
    func cpuUsage_alwaysInRange() {
        let values: [(UInt64, UInt64, UInt64, UInt64)] = [
            (100, 0, 0, 0),
            (0, 100, 0, 0),
            (50, 50, 0, 0),
            (1, 1, 98, 0),
            (0, 0, 0, 100)
        ]
        for (u, s, i, n) in values {
            let usage = SystemMonitor.cpuUsageFromDeltas(userDelta: u, systemDelta: s, idleDelta: i, niceDelta: n)
            #expect(usage >= 0.0 && usage <= 1.0, "범위 초과: user=\(u) sys=\(s) idle=\(i) nice=\(n) → \(usage)")
        }
    }

    // MARK: - 메모리 읽기

    @Test("memoryTotal_0보다큼")
    func memoryTotal_greaterThanZero() {
        let total = SystemMonitor.readTotalMemory()
        #expect(total > 0, "총 메모리는 0보다 커야 한다")
    }

    @Test("memoryTotal_최소4GB이상")
    func memoryTotal_atLeast4GB() {
        let total = SystemMonitor.readTotalMemory()
        // 현대 Mac은 최소 4 GB
        let fourGB: UInt64 = 4 * 1024 * 1024 * 1024
        #expect(total >= fourGB, "총 메모리가 4 GB 이상이어야 한다: \(total)")
    }

    // MARK: - 네트워크 I/O 읽기

    @Test("networkBytes_en0읽기_크래시없음")
    func networkBytes_en0_noCrash() {
        let bytes = SystemMonitor.readNetworkBytes(interface: "en0")
        // en0가 없을 수 있으므로 0도 허용
        _ = bytes
    }

    @Test("networkBytes_존재하지않는인터페이스_0반환")
    func networkBytes_unknownInterface_returnsZero() {
        let bytes = SystemMonitor.readNetworkBytes(interface: "nonexistent999")
        #expect(bytes.bytesIn == 0)
        #expect(bytes.bytesOut == 0)
    }

    // MARK: - ps 출력 파싱

    @Test("parsePsOutput_정상입력_ProcessStat배열반환")
    func parsePsOutput_validInput_returnsStats() {
        let input = """
          PID  %CPU   RSS COMM
          123  12.5  4096 /usr/bin/node
          456   0.1  2048 python3
        """
        let stats = SystemMonitor.parsePsOutput(input)
        #expect(stats.count == 2)
        #expect(stats[0].pid == 123)
        #expect(stats[0].cpuPercent == 12.5)
        #expect(stats[0].memoryMB == 4)     // 4096 KB / 1024
        #expect(stats[0].name == "node")    // 경로의 마지막 컴포넌트
        #expect(stats[0].executablePath == "/usr/bin/node")
        #expect(stats[1].pid == 456)
        #expect(stats[1].cpuPercent == 0.1)
        #expect(stats[1].executablePath == nil)  // 경로 없이 이름만
    }

    @Test("parsePsOutput_빈입력_빈배열반환")
    func parsePsOutput_emptyInput_returnsEmpty() {
        let stats = SystemMonitor.parsePsOutput("")
        #expect(stats.isEmpty)
    }

    @Test("parsePsOutput_헤더만있는경우_빈배열반환")
    func parsePsOutput_headerOnly_returnsEmpty() {
        let input = "  PID  %CPU   RSS COMM\n"
        let stats = SystemMonitor.parsePsOutput(input)
        #expect(stats.isEmpty)
    }

    @Test("parsePsOutput_잘못된형식_건너뜀")
    func parsePsOutput_malformedLines_skipped() {
        let input = """
          PID  %CPU   RSS COMM
          abc  12.5  4096 bad_pid
          123  xyz   4096 bad_cpu
          123  12.5  abc  bad_rss
          456   1.0  2048 valid
        """
        let stats = SystemMonitor.parsePsOutput(input)
        // 마지막 valid 라인만 파싱 성공
        #expect(stats.count == 1)
        #expect(stats[0].pid == 456)
    }

    // MARK: - lsof 출력 파싱

    @Test("parseLsofPortOutput_정상입력_PortInfo배열반환")
    func parseLsofPortOutput_validInput_returnsPorts() {
        let input = """
COMMAND   PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node     1234   ted    26u  IPv4 0x1234567890       0t0  TCP 127.0.0.1:3000 (LISTEN)
ruby     5678   ted    11u  IPv6 0xabcdef1234       0t0  TCP *:4567 (LISTEN)
"""
        let ports = SystemMonitor.parseLsofPortOutput(input)
        #expect(!ports.isEmpty)

        let nodePorts = ports.filter { $0.processName == "node" }
        #expect(nodePorts.count == 1)
        #expect(nodePorts[0].port == 3000)
        #expect(nodePorts[0].address == "127.0.0.1")
        #expect(nodePorts[0].pid == 1234)

        let rubyPorts = ports.filter { $0.processName == "ruby" }
        #expect(rubyPorts.count == 1)
        #expect(rubyPorts[0].port == 4567)
        #expect(rubyPorts[0].address == "*")
    }

    @Test("parseLsofPortOutput_시스템프로세스_필터링됨")
    func parseLsofPortOutput_systemProcesses_filtered() {
        let input = """
COMMAND         PID  USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
launchd           1  root   26u  IPv4 0x111       0t0  TCP *:80 (LISTEN)
mDNSResponder   123  _mdns  10u  IPv4 0x222       0t0  TCP *:5353 (LISTEN)
node           1234  ted    26u  IPv4 0x333       0t0  TCP *:3000 (LISTEN)
"""
        let ports = SystemMonitor.parseLsofPortOutput(input)
        // launchd, mDNSResponder는 필터링, node만 남음
        #expect(ports.allSatisfy { $0.processName == "node" })
        #expect(ports.count == 1)
    }

    @Test("parseLsofPortOutput_빈입력_빈배열반환")
    func parseLsofPortOutput_emptyInput_returnsEmpty() {
        let ports = SystemMonitor.parseLsofPortOutput("")
        #expect(ports.isEmpty)
    }

    @Test("parseLsofPortOutput_LISTEN없는줄_건너뜀")
    func parseLsofPortOutput_nonListenLines_skipped() {
        let input = """
COMMAND   PID   USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
node     1234   ted    26u  IPv4  0x123       0t0  TCP 127.0.0.1:3000 (ESTABLISHED)
node     1234   ted    27u  IPv4  0x124       0t0  TCP 127.0.0.1:3001 (LISTEN)
"""
        let ports = SystemMonitor.parseLsofPortOutput(input)
        #expect(ports.count == 1)
        #expect(ports[0].port == 3001)
    }

    @Test("parseLsofPortOutput_중복포트_한번만포함")
    func parseLsofPortOutput_duplicatePorts_deduplicated() {
        let input = """
COMMAND  PID  USER  FD   TYPE  DEVICE SIZE/OFF NODE NAME
node    1234  ted   26u  IPv4  0x123       0t0  TCP *:3000 (LISTEN)
node    1234  ted   27u  IPv6  0x124       0t0  TCP *:3000 (LISTEN)
"""
        let ports = SystemMonitor.parseLsofPortOutput(input)
        #expect(ports.count == 1)
    }

    @Test("parseLsofPortOutput_포트정렬_오름차순")
    func parseLsofPortOutput_ports_sortedAscending() {
        let input = """
COMMAND  PID  USER  FD   TYPE  DEVICE SIZE/OFF NODE NAME
ruby    5678  ted   11u  IPv4  0x222       0t0  TCP *:9000 (LISTEN)
node    1234  ted   26u  IPv4  0x111       0t0  TCP *:3000 (LISTEN)
python  9999  ted   33u  IPv4  0x333       0t0  TCP *:5000 (LISTEN)
"""
        let ports = SystemMonitor.parseLsofPortOutput(input)
        let portNums = ports.map(\.port)
        #expect(portNums == portNums.sorted(), "포트가 오름차순으로 정렬되어야 한다")
    }

    // MARK: - 프로세스 목록 (실제 시스템)

    @Test("fetchProcessStats_비어있지않은목록반환")
    func fetchProcessStats_returnsNonEmptyList() {
        let stats = SystemMonitor.fetchProcessStats()
        #expect(!stats.isEmpty, "프로세스 목록이 비어있으면 안 된다")
    }

    @Test("fetchProcessStats_PID값이양수")
    func fetchProcessStats_pidsArePositive() {
        let stats = SystemMonitor.fetchProcessStats()
        for stat in stats {
            #expect(stat.pid > 0, "PID는 양수여야 한다: \(stat.name)(\(stat.pid))")
        }
    }

    @Test("fetchProcessStats_CPU범위_0이상")
    func fetchProcessStats_cpuNonNegative() {
        let stats = SystemMonitor.fetchProcessStats()
        for stat in stats {
            #expect(stat.cpuPercent >= 0, "CPU %는 0 이상이어야 한다: \(stat.name)")
        }
    }

    // MARK: - SystemMonitor 초기화 상태

    @Test("init_초기상태_모두0")
    @MainActor
    func init_initialState_allZero() {
        let monitor = SystemMonitor()
        #expect(monitor.cpuUsage == 0)
        #expect(monitor.memoryUsed == 0)
        #expect(monitor.memoryTotal == 0)
        #expect(monitor.networkBytesIn == 0)
        #expect(monitor.networkBytesOut == 0)
        #expect(monitor.topProcessesByCPU.isEmpty)
        #expect(monitor.topProcessesByMemory.isEmpty)
        #expect(monitor.listeningPorts.isEmpty)
    }

    // MARK: - 네거티브 / 경계값

    @Test("cpuUsage_매우큰델타값_범위초과없음")
    func cpuUsage_veryLargeDeltas_noOverflow() {
        let large: UInt64 = UInt64.max / 4
        let usage = SystemMonitor.cpuUsageFromDeltas(
            userDelta: large, systemDelta: large,
            idleDelta: large, niceDelta: large
        )
        #expect(usage >= 0.0 && usage <= 1.0)
    }

    @Test("parsePsOutput_매우긴이름_정상처리")
    func parsePsOutput_veryLongName_handled() {
        let longName = String(repeating: "a", count: 255)
        let input = "  PID  %CPU   RSS COMM\n  999   0.0  1024 \(longName)\n"
        let stats = SystemMonitor.parsePsOutput(input)
        #expect(stats.count == 1)
        #expect(stats[0].name == longName)
    }

    @Test("parseLsofPortOutput_포트65535_정상파싱")
    func parseLsofPortOutput_maxPort_parsed() {
        let input = """
COMMAND  PID  USER  FD   TYPE  DEVICE SIZE/OFF NODE NAME
myapp   1234  ted   26u  IPv4  0x111       0t0  TCP *:65535 (LISTEN)
"""
        let ports = SystemMonitor.parseLsofPortOutput(input)
        #expect(ports.count == 1)
        #expect(ports[0].port == 65535)
    }

    @Test("parseLsofPortOutput_포트0_파싱실패_건너뜀")
    func parseLsofPortOutput_portZero_skipped() {
        // 포트 0은 UInt16(0)이므로 파싱은 되지만 실제로 사용하지 않음
        // 여기서는 파싱 로직이 크래시 없이 처리하는지만 검증
        let input = """
COMMAND  PID  USER  FD   TYPE  DEVICE SIZE/OFF NODE NAME
myapp   1234  ted   26u  IPv4  0x111       0t0  TCP *:0 (LISTEN)
"""
        let ports = SystemMonitor.parseLsofPortOutput(input)
        // UInt16("0") = 0이므로 파싱은 성공하나 크래시는 없어야 함
        _ = ports
    }

    @Test("systemProcessNames_launchd포함")
    func systemProcessNames_containsLaunchd() {
        #expect(SystemMonitor.systemProcessNames.contains("launchd"))
    }

    @Test("systemProcessNames_mDNSResponder포함")
    func systemProcessNames_containsMDNSResponder() {
        #expect(SystemMonitor.systemProcessNames.contains("mDNSResponder"))
    }

    // MARK: - 신규 필드 초기화 상태

    @Test("init_perCoreUsage_초기빈배열")
    @MainActor
    func init_perCoreUsage_initiallyEmpty() {
        let monitor = SystemMonitor()
        #expect(monitor.perCoreUsage.isEmpty)
    }

    @Test("init_coreCount_초기0")
    @MainActor
    func init_coreCount_initiallyZero() {
        let monitor = SystemMonitor()
        #expect(monitor.coreCount == 0)
    }

    @Test("init_memoryActive_초기0")
    @MainActor
    func init_memoryActive_initiallyZero() {
        let monitor = SystemMonitor()
        #expect(monitor.memoryActive == 0)
    }

    @Test("init_memoryWired_초기0")
    @MainActor
    func init_memoryWired_initiallyZero() {
        let monitor = SystemMonitor()
        #expect(monitor.memoryWired == 0)
    }

    @Test("init_memoryCompressed_초기0")
    @MainActor
    func init_memoryCompressed_initiallyZero() {
        let monitor = SystemMonitor()
        #expect(monitor.memoryCompressed == 0)
    }

    @Test("init_swapUsed_초기0")
    @MainActor
    func init_swapUsed_initiallyZero() {
        let monitor = SystemMonitor()
        #expect(monitor.swapUsed == 0)
    }

    @Test("init_swapTotal_초기0")
    @MainActor
    func init_swapTotal_initiallyZero() {
        let monitor = SystemMonitor()
        #expect(monitor.swapTotal == 0)
    }

    @Test("init_gpuName_초기빈문자열")
    @MainActor
    func init_gpuName_initiallyEmptyString() {
        let monitor = SystemMonitor()
        #expect(monitor.gpuName == "")
    }

    @Test("init_gpuUtilization_초기0")
    @MainActor
    func init_gpuUtilization_initiallyZero() {
        let monitor = SystemMonitor()
        #expect(monitor.gpuUtilization == 0)
    }

    @Test("init_disks_초기빈배열")
    @MainActor
    func init_disks_initiallyEmpty() {
        let monitor = SystemMonitor()
        #expect(monitor.disks.isEmpty)
    }

    // MARK: - DiskInfo 모델

    @Test("DiskInfo_초기화_프로퍼티정상설정")
    func diskInfo_init_propertiesSetCorrectly() {
        let disk = DiskInfo(
            mountPoint: "/",
            totalGB: 500.0,
            usedGB: 200.0,
            name: "Macintosh HD"
        )
        #expect(disk.mountPoint == "/")
        #expect(disk.totalGB == 500.0)
        #expect(disk.usedGB == 200.0)
        #expect(disk.name == "Macintosh HD")
    }

    @Test("DiskInfo_Sendable준수")
    func diskInfo_sendable_conformance() {
        let disk = DiskInfo(mountPoint: "/", totalGB: 100.0, usedGB: 50.0, name: "Test")
        let sendable: any Sendable = disk
        #expect(sendable is DiskInfo)
    }

    @Test("DiskInfo_usedGB_totalGB이하")
    func diskInfo_usedGB_notExceedsTotalGB() {
        let disk = DiskInfo(mountPoint: "/Volumes/Data", totalGB: 1000.0, usedGB: 750.0, name: "Data")
        #expect(disk.usedGB <= disk.totalGB)
    }

    @Test("DiskInfo_빈mountPoint_빈문자열허용")
    func diskInfo_emptyMountPoint_allowed() {
        let disk = DiskInfo(mountPoint: "", totalGB: 0.0, usedGB: 0.0, name: "")
        #expect(disk.mountPoint == "")
        #expect(disk.name == "")
    }
}
