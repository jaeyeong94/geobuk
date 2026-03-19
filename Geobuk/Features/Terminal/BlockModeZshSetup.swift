import Foundation

/// 블록 입력 모드용 ZDOTDIR 설정
/// 임시 디렉토리에 리소스의 .zshrc/.zshenv를 복사하여 프롬프트 테마 비활성화
final class BlockModeZshSetup {
    /// 임시 ZDOTDIR 경로 (앱 수명 동안 유지)
    nonisolated(unsafe) private(set) static var zdotdir: String = ""

    /// 명시적 초기화 (앱 시작 시 호출)
    static func initialize() {
        let dir = NSTemporaryDirectory() + "geobuk-zdotdir"
        let fm = FileManager.default
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // 리소스에서 .zshrc 복사
        if let src = Bundle.main.path(forResource: "geobuk-block-mode", ofType: "zshrc") {
            try? fm.removeItem(atPath: dir + "/.zshrc")
            try? fm.copyItem(atPath: src, toPath: dir + "/.zshrc")
        }

        // 리소스에서 .zshenv 복사
        if let src = Bundle.main.path(forResource: "geobuk-block-mode", ofType: "zshenv") {
            try? fm.removeItem(atPath: dir + "/.zshenv")
            try? fm.copyItem(atPath: src, toPath: dir + "/.zshenv")
        }

        zdotdir = dir
    }
}
