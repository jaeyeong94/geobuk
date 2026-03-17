import XCTest

final class GeobukUITests: XCTestCase {
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // Phase 1에서 실제 UI 검증 추가
        XCTAssertTrue(app.windows.count > 0, "앱이 최소 1개의 윈도우를 표시해야 함")
    }
}
