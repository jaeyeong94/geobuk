import SwiftUI

/// 앱 전역 상태를 관리하는 Observable 객체
@Observable
final class AppState {
    /// Ghostty 앱 인스턴스 초기화 여부
    var isGhosttyInitialized = false

    /// 현재 활성 워크스페이스 인덱스
    var activeWorkspaceIndex = 0

    /// 소켓 서버 실행 상태
    var isSocketServerRunning = false
}
