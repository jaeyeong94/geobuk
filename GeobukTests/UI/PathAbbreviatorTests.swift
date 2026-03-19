import Testing
import Foundation
@testable import Geobuk

@Suite("PathAbbreviator - 경로 축약")
struct PathAbbreviatorTests {

    @Test("홈디렉토리_물결표로축약")
    func homeDirectory_abbreviatedToTilde() {
        let home = NSHomeDirectory()
        #expect(PathAbbreviator.abbreviate(home) == "~")
    }

    @Test("홈하위경로_물결표접두사로축약")
    func homeSubpath_abbreviatedWithTilde() {
        let home = NSHomeDirectory()
        let path = home + "/Documents/project"
        #expect(PathAbbreviator.abbreviate(path) == "~/Documents/project")
    }

    @Test("홈외부경로_그대로반환")
    func outsideHome_returnedAsIs() {
        let path = "/usr/local/bin"
        #expect(PathAbbreviator.abbreviate(path) == "/usr/local/bin")
    }

    @Test("루트경로_그대로반환")
    func rootPath_returnedAsIs() {
        #expect(PathAbbreviator.abbreviate("/") == "/")
    }

    @Test("빈문자열_그대로반환")
    func emptyString_returnedAsIs() {
        #expect(PathAbbreviator.abbreviate("") == "")
    }
}
