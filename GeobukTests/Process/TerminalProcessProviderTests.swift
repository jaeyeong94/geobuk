import Testing
import Foundation
@testable import Geobuk

@Suite("TerminalProcessProvider - TTY 프로세스 수집")
struct TerminalProcessProviderTests {

    // MARK: - ps 출력 파싱

    @Suite("ps 출력 파싱")
    struct ParsePsTests {

        @Test("정상입력_프로세스파싱")
        func validInput_parseProcesses() {
            let output = """
              PID TTY       %CPU    RSS     ELAPSED ARGS
            12345 ttys001  45.2  320000    2:13:05 node server.js
            12346 ttys001  12.1   65536       5:30 claude --model opus
            12347 ttys002   3.4   87040    1:30:00 python train.py
            """
            let results = TerminalProcessProvider.parsePsOutput(output)
            #expect(results.count == 3)
            #expect(results[0].name == "node")
            #expect(results[0].cpuPercent == 45.2)
            #expect(results[0].memoryMB == 312) // 320000 / 1024
            #expect(results[0].command == "node server.js")
        }

        @Test("TTY없는프로세스_제외")
        func noTTY_excluded() {
            let output = """
              PID TTY       %CPU    RSS     ELAPSED ARGS
            12345 ??       1.0  10000       0:05 launchd
            12346 ttys001  2.0  20000       1:00 node app.js
            """
            let results = TerminalProcessProvider.parsePsOutput(output)
            #expect(results.count == 1)
            #expect(results[0].name == "node")
        }

        @Test("셸프로세스_제외")
        func shellProcesses_excluded() {
            let output = """
              PID TTY       %CPU    RSS     ELAPSED ARGS
            12345 ttys001  0.1   5000       0:01 zsh
            12346 ttys001  0.1   5000       0:01 -zsh
            12347 ttys001  0.1   5000       0:01 bash
            12348 ttys001  2.0  20000       1:00 node app.js
            12349 ttys001  0.0   1000       0:00 ps
            """
            let results = TerminalProcessProvider.parsePsOutput(output)
            #expect(results.count == 1)
            #expect(results[0].name == "node")
        }

        @Test("CPU내림차순정렬")
        func sortedByCPU() {
            let output = """
              PID TTY       %CPU    RSS     ELAPSED ARGS
            12345 ttys001   3.0  10000       0:05 python
            12346 ttys001  45.0  20000       1:00 node
            12347 ttys001  12.0  15000       0:30 claude
            """
            let results = TerminalProcessProvider.parsePsOutput(output)
            #expect(results[0].name == "node")
            #expect(results[1].name == "claude")
            #expect(results[2].name == "python")
        }

        @Test("빈입력_빈배열")
        func emptyInput_emptyResult() {
            let results = TerminalProcessProvider.parsePsOutput("")
            #expect(results.isEmpty)
        }

        @Test("포트맵연동")
        func withPortMap() {
            let output = """
              PID TTY       %CPU    RSS     ELAPSED ARGS
            12345 ttys001  10.0  100000       1:00 node server.js
            """
            let portMap: [pid_t: [UInt16]] = [12345: [3000, 3001]]
            let results = TerminalProcessProvider.parsePsOutput(output, portMap: portMap)
            #expect(results[0].listeningPorts == [3000, 3001])
        }
    }

    // MARK: - elapsed time 파싱

    @Suite("실행 시간 파싱")
    struct ElapsedTimeTests {

        @Test("MM:SS_형식")
        func minutesSeconds() {
            #expect(TerminalProcessProvider.parseElapsedTime("05:30") == 330)
        }

        @Test("HH:MM:SS_형식")
        func hoursMinutesSeconds() {
            #expect(TerminalProcessProvider.parseElapsedTime("2:13:05") == 7985)
        }

        @Test("D-HH:MM:SS_형식")
        func daysFormat() {
            #expect(TerminalProcessProvider.parseElapsedTime("1-02:30:00") == 95400)
        }

        @Test("0:00_형식")
        func zero() {
            #expect(TerminalProcessProvider.parseElapsedTime("0:00") == 0)
        }
    }

    // MARK: - lsof 포트맵 파싱

    @Suite("lsof 포트맵 파싱")
    struct PortMapTests {

        @Test("정상출력_포트맵생성")
        func validOutput_portMap() {
            let output = """
            p12345
            n*:3000
            n127.0.0.1:3001
            p12346
            n*:8080
            """
            let portMap = TerminalProcessProvider.parseLsofForPortMap(output)
            #expect(portMap[12345] == [3000, 3001])
            #expect(portMap[12346] == [8080])
        }

        @Test("빈출력_빈맵")
        func emptyOutput_emptyMap() {
            let portMap = TerminalProcessProvider.parseLsofForPortMap("")
            #expect(portMap.isEmpty)
        }
    }

    // MARK: - formattedUptime

    @Suite("실행 시간 포맷")
    struct UptimeFormatTests {

        @Test("초단위")
        func seconds() {
            let proc = TerminalProcess(pid: 1, name: "test", command: "test", tty: "ttys001",
                                       cpuPercent: 0, memoryMB: 0, elapsedSeconds: 45, listeningPorts: [])
            #expect(proc.formattedUptime == "45s")
        }

        @Test("분단위")
        func minutes() {
            let proc = TerminalProcess(pid: 1, name: "test", command: "test", tty: "ttys001",
                                       cpuPercent: 0, memoryMB: 0, elapsedSeconds: 330, listeningPorts: [])
            #expect(proc.formattedUptime == "5m 30s")
        }

        @Test("시간단위")
        func hours() {
            let proc = TerminalProcess(pid: 1, name: "test", command: "test", tty: "ttys001",
                                       cpuPercent: 0, memoryMB: 0, elapsedSeconds: 7985, listeningPorts: [])
            #expect(proc.formattedUptime == "2h 13m")
        }
    }

    // MARK: - 편의 접근자

    @Suite("필터링")
    struct FilterTests {

        @Test("실제시스템_TTY프로세스수집")
        func realSystem_fetchProcesses() {
            let processes = TerminalProcessProvider.fetchTerminalProcesses()
            // 최소한 현재 테스트 프로세스가 TTY를 가질 수 있음
            // 크래시 없이 실행되면 통과
            _ = processes
        }
    }
}
