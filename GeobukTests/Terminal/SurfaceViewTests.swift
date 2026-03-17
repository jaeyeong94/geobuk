import Testing
import AppKit
@testable import Geobuk

@Suite("GhosttySurfaceView")
struct SurfaceViewTests {

    // MARK: - 초기화

    @Test("init_뷰생성_firstResponder수락")
    @MainActor
    func init_viewCreated_acceptsFirstResponder() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let view = GhosttySurfaceView(app: app)
        #expect(view.acceptsFirstResponder == true)
    }

    @Test("init_surface생성_nil아님")
    @MainActor
    func init_surfaceCreated_notNil() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let view = GhosttySurfaceView(app: app)
        #expect(view.hasSurface == true)
        view.close()
    }

    // MARK: - 크기 변경

    @Test("sizeDidChange_유효한크기_에러없음")
    @MainActor
    func sizeDidChange_validSize_noError() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let view = GhosttySurfaceView(app: app)
        defer { view.close() }

        view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        view.sizeDidChange(CGSize(width: 800, height: 600))
    }

    // MARK: - 포커스

    @Test("setFocus_true_에러없음")
    @MainActor
    func setFocus_true_noError() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let view = GhosttySurfaceView(app: app)
        defer { view.close() }

        view.setFocusState(true)
        view.setFocusState(false)
    }

    // MARK: - 정리

    @Test("close_surface해제_hasSurface_false")
    @MainActor
    func close_surfaceReleased_hasSurfaceFalse() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let view = GhosttySurfaceView(app: app)
        view.close()
        #expect(view.hasSurface == false)
    }

    @Test("close_중복호출_안전")
    @MainActor
    func close_multipleCalls_safe() throws {
        let app = GhosttyApp()
        try app.create()
        defer { app.destroy() }

        let view = GhosttySurfaceView(app: app)
        view.close()
        view.close()
        #expect(view.hasSurface == false)
    }
}
