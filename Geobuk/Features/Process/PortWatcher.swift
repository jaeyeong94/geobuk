import Darwin
import Foundation

/// 프로세스의 리스닝 포트를 감지하는 유틸리티
/// lsof 명령어를 사용하여 특정 PID가 리스닝하고 있는 포트 목록을 반환한다
final class PortWatcher: Sendable {

    /// 주어진 PID가 리스닝하고 있는 포트 목록을 반환한다
    /// - Parameter pid: 대상 프로세스 PID
    /// - Returns: 리스닝 중인 포트 번호 배열
    static func listeningPorts(for pid: pid_t) -> [UInt16] {
        guard pid >= 0 else { return [] }

        // lsof를 사용하여 해당 PID의 리스닝 소켓을 조회한다
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-iTCP", "-sTCP:LISTEN", "-P", "-n", "-p", "\(pid)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return parseLsofOutput(output)
    }

    /// lsof 출력에서 포트 번호를 추출한다
    static func parseLsofOutput(_ output: String) -> [UInt16] {
        var ports: Set<UInt16> = []
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            // lsof 출력 형식: ... TCP *:PORT (LISTEN)
            // 또는: ... TCP 127.0.0.1:PORT (LISTEN)
            guard line.contains("LISTEN") else { continue }

            // ":PORT" 패턴을 찾는다
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            for column in columns {
                let col = String(column)
                if col.contains(":") && (col.contains("LISTEN") || columns.last?.contains("LISTEN") == true) {
                    // "host:port" 에서 port 추출
                    if let lastColon = col.lastIndex(of: ":") {
                        let portStr = String(col[col.index(after: lastColon)...])
                            .replacingOccurrences(of: "(LISTEN)", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        if let port = UInt16(portStr) {
                            ports.insert(port)
                        }
                    }
                }
            }
        }

        return Array(ports).sorted()
    }
}
