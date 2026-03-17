import Testing
import AppKit
@testable import Geobuk

@Suite("GhosttyApp")
struct GhosttyAppTests {

    // MARK: - 초기화

    @Test("init_ghosttyInit호출_성공")
    @MainActor
    func init_ghosttyInitSuccess() {
        let app = GhosttyApp()
        #expect(app.isInitialized == false, "create() 전에는 미초기화")
    }

    @Test("create_앱인스턴스생성_초기화완료")
    @MainActor
    func create_appInstance_initialized() throws {
        let app = GhosttyApp()
        try app.create()
        #expect(app.isInitialized == true)
        app.destroy()
    }

    @Test("destroy_정리후_미초기화상태")
    @MainActor
    func destroy_afterCleanup_notInitialized() throws {
        let app = GhosttyApp()
        try app.create()
        app.destroy()
        #expect(app.isInitialized == false)
    }

    @Test("destroy_중복호출_안전")
    @MainActor
    func destroy_multipleCalls_safe() throws {
        let app = GhosttyApp()
        try app.create()
        app.destroy()
        app.destroy()
        #expect(app.isInitialized == false)
    }

    // MARK: - 설정

    @Test("ghosttyInfo_버전정보_정상조회")
    @MainActor
    func ghosttyInfo_versionAvailable() {
        let info = GhosttyTerminalAdapter.getGhosttyInfo()
        #expect(!info.version.isEmpty)
        #expect(info.buildMode == "release-fast")
    }
}
