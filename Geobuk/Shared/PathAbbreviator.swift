import Foundation

/// 파일 경로를 사용자 표시용으로 축약하는 유틸리티
enum PathAbbreviator {
    /// 홈 디렉토리를 ~ 로 치환하여 경로를 축약한다
    static func abbreviate(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
