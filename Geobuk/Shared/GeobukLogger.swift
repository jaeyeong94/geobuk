import Foundation

/// Geobuk 앱 전역 구조화 로거
/// ~/Library/Application Support/Geobuk/geobuk.log 에 기록
/// 로그 파일은 앱 시작 시 이전 내용 유지 (append)
/// 파일 크기가 5MB 초과 시 자동 로테이션
final class GeobukLogger: Sendable {
    static let shared = GeobukLogger()

    /// 로그 컴포넌트 태그
    enum Component: String {
        case app = "App"
        case terminal = "Terminal"
        case shell = "Shell"
        case claude = "Claude"
        case socket = "Socket"
        case workspace = "Workspace"
        case process = "Process"
        case sidebar = "Sidebar"
        case config = "Config"
    }

    /// 로그 레벨
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warn = "WARN"
        case error = "ERROR"
    }

    private let logPath: String
    private let maxFileSize: UInt64 = 5 * 1024 * 1024 // 5MB
    private let queue = DispatchQueue(label: "com.geobuk.logger", qos: .utility)

    private init() {
        self.logPath = AppPath.appSupport.appendingPathComponent("geobuk.log").path
    }

    // MARK: - Public API

    static func debug(_ component: Component, _ message: String, context: [String: String] = [:]) {
        shared.log(level: .debug, component: component, message: message, context: context)
    }

    static func info(_ component: Component, _ message: String, context: [String: String] = [:]) {
        shared.log(level: .info, component: component, message: message, context: context)
    }

    static func warn(_ component: Component, _ message: String, context: [String: String] = [:]) {
        shared.log(level: .warn, component: component, message: message, context: context)
    }

    static func error(_ component: Component, _ message: String, context: [String: String] = [:]) {
        shared.log(level: .error, component: component, message: message, context: context)
    }

    static func error(_ component: Component, _ message: String, error: Error, context: [String: String] = [:]) {
        var ctx = context
        ctx["error"] = String(describing: error)
        shared.log(level: .error, component: component, message: message, context: ctx)
    }

    // MARK: - Internal

    private func log(level: Level, component: Component, message: String, context: [String: String]) {
        let timestamp = Self.timestampFormatter.string(from: Date())
        var line = "\(timestamp) [\(level.rawValue)] [\(component.rawValue)] \(message)"

        if !context.isEmpty {
            let ctxStr = context.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            line += " | \(ctxStr)"
        }

        line += "\n"

        queue.async { [weak self] in
            self?.writeLine(line)
        }
    }

    private func writeLine(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }

        // 파일 크기 체크 → 로테이션
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logPath),
           let size = attrs[.size] as? UInt64,
           size > maxFileSize {
            rotateLog()
        }

        // append 모드로 쓰기
        if FileManager.default.fileExists(atPath: logPath) {
            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: logPath, contents: data, attributes: [.posixPermissions: 0o600])
        }
    }

    private func rotateLog() {
        let backupPath = logPath + ".old"
        try? FileManager.default.removeItem(atPath: backupPath)
        try? FileManager.default.moveItem(atPath: logPath, toPath: backupPath)
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
