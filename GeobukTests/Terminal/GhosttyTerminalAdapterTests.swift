import Testing
import AppKit
@testable import Geobuk

@Suite("GhosttyTerminalAdapter")
struct GhosttyTerminalAdapterTests {

    // MARK: - C API 연동 검증

    @Test("getGhosttyInfo_C_API호출_버전정보반환")
    func getGhosttyInfo_returnsVersionInfo() {
        let info = GhosttyTerminalAdapter.getGhosttyInfo()

        // libghostty가 정상 링크되었으면 빈 문자열이 아닌 버전 반환
        #expect(!info.version.isEmpty)
        #expect(info.version != "unknown", "버전이 정상 파싱되어야 함")
    }

    @Test("getGhosttyInfo_빌드모드_releaseFast")
    func getGhosttyInfo_buildMode_isReleaseFast() {
        let info = GhosttyTerminalAdapter.getGhosttyInfo()

        // ReleaseFast로 빌드했으므로
        #expect(info.buildMode == "release-fast")
    }

    // MARK: - TerminalRenderer 프로토콜 준수

    @Test("init_placeholder뷰생성")
    func init_createsPlaceholderView() {
        let adapter = GhosttyTerminalAdapter()
        #expect(adapter.surfaceView.wantsLayer == true)
    }

    @Test("destroy_중복호출안전")
    func destroy_safeToCallMultipleTimes() {
        let adapter = GhosttyTerminalAdapter()
        adapter.destroy()
        adapter.destroy() // 두 번 호출해도 크래시 없어야 함
    }

    @Test("handleKey_surface없음_false반환")
    func handleKey_noSurface_returnsFalse() {
        let adapter = GhosttyTerminalAdapter()
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        )!
        let handled = adapter.handleKey(event)
        #expect(handled == false)
    }
}
