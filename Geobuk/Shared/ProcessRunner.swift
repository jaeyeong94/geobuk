import Foundation

/// 외부 프로세스 실행 유틸리티
enum ProcessRunner {
    /// 동기적으로 프로세스를 실행하고 stdout을 반환한다 (nonisolated — 백그라운드 호출 가능)
    /// - Parameters:
    ///   - executable: 실행 파일 경로 (예: "/usr/bin/git")
    ///   - arguments: 인자 배열
    ///   - currentDirectory: 작업 디렉토리 (nil이면 현재 디렉토리)
    ///   - environment: 추가 환경변수 (기존 환경에 merge)
    /// - Returns: (stdout 문자열, 종료 코드). 실행 실패 시 (nil, -1)
    static func run(
        _ executable: String,
        arguments: [String] = [],
        currentDirectory: String? = nil,
        environment: [String: String]? = nil
    ) -> (output: String?, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let dir = currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
        }
        if let env = environment {
            process.environment = ProcessInfo.processInfo.environment.merging(env) { _, new in new }
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            GeobukLogger.warn(.process, "Command execution failed: \(error.localizedDescription)")
            return (nil, -1)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8)
        return (output, process.terminationStatus)
    }

    /// 실행 결과의 stdout만 반환 (성공 시에만)
    static func output(
        _ executable: String,
        arguments: [String] = [],
        currentDirectory: String? = nil,
        environment: [String: String]? = nil
    ) -> String? {
        let result = run(executable, arguments: arguments, currentDirectory: currentDirectory, environment: environment)
        guard result.exitCode == 0 else { return nil }
        return result.output?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
