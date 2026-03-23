import Foundation

/// Socket API에서 패널을 제어하기 위한 싱글톤 컨트롤러
/// ContentView가 초기화 시 콜백을 등록하면, API 핸들러가 이를 통해 패널을 조작한다
@MainActor
final class PaneController {
    static let shared = PaneController()
    private init() {}

    /// 패널 분할 콜백: (sourcePaneId, direction) → 새 패널의 surfaceId
    var onSplitPane: ((_ sourcePaneId: String, _ direction: String) -> String?)?

    /// 패널에 키 입력 전송: (surfaceId, text) → 성공 여부
    var onSendKeys: ((_ surfaceId: String, _ text: String) -> Bool)?

    /// 패널 닫기: (surfaceId) → 성공 여부
    var onKillPane: ((_ surfaceId: String) -> Bool)?

    /// 패널 분할 실행
    func splitPane(sourcePaneId: String, direction: String) -> String? {
        return onSplitPane?(sourcePaneId, direction)
    }

    /// 패널에 키 전송
    func sendKeys(surfaceId: String, text: String) -> Bool {
        return onSendKeys?(surfaceId, text) ?? false
    }

    /// 패널 닫기
    func killPane(surfaceId: String) -> Bool {
        return onKillPane?(surfaceId) ?? false
    }
}
