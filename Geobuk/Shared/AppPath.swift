import Foundation

/// Geobuk 앱의 파일 시스템 경로를 관리하는 유틸리티
enum AppPath {
    /// ~/Library/Application Support/Geobuk/
    static let appSupport: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let geobukDir = url.appendingPathComponent("Geobuk")
        try? FileManager.default.createDirectory(at: geobukDir, withIntermediateDirectories: true)
        return geobukDir
    }()

    /// ~/Library/Application Support/Geobuk/ as String path
    static var appSupportPath: String { appSupport.path }
}
