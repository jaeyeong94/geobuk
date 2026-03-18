import Foundation

/// PTY 출력 로그 파일 관리
/// 각 패널의 PTY 출력을 script(1) 래퍼를 통해 파일에 기록하고 tail
/// 모든 메서드는 FileManager 기반의 스레드 안전한 연산만 수행
final class PTYLogManager {
    /// 로그 디렉토리
    static let logDirectory: String = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("Geobuk/pty-logs").path
    }()

    /// 패널 ID별 로그 파일 경로
    static func logPath(for paneId: UUID) -> String {
        (logDirectory as NSString).appendingPathComponent("\(paneId.uuidString).log")
    }

    /// script(1) 래퍼 명령어 생성
    /// macOS: script -q -F <logfile> $SHELL
    static func scriptCommand(for paneId: UUID) -> String {
        // 디렉토리가 없으면 미리 생성
        initialize()
        let path = logPath(for: paneId)
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        // 경로에 공백이 있을 수 있으므로 인용 부호 필수 (Application Support 등)
        return "script -q -F '\(path)' \(shell)"
    }

    /// 로그 디렉토리 초기화 (앱 시작 시 이전 로그 정리)
    static func initialize() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: logDirectory) {
            try? fm.createDirectory(
                atPath: logDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    /// 특정 패널의 로그 파일 삭제
    static func cleanup(paneId: UUID) {
        let path = logPath(for: paneId)
        try? FileManager.default.removeItem(atPath: path)
    }

    /// 모든 로그 파일 삭제
    static func cleanupAll() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: logDirectory) else { return }
        for file in files {
            let fullPath = (logDirectory as NSString).appendingPathComponent(file)
            try? fm.removeItem(atPath: fullPath)
        }
    }
}
