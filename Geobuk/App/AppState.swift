import SwiftUI

/// 앱 전역 상태를 관리하는 Observable 객체
@Observable
final class AppState {
    /// 싱글톤 인스턴스
    @MainActor
    static let shared = AppState()

    /// Ghostty 앱 인스턴스 초기화 여부
    private(set) var isGhosttyInitialized = false

    /// 소켓 서버 실행 상태
    private(set) var isSocketServerRunning = false

    func markGhosttyInitialized() { isGhosttyInitialized = true }
    func markSocketServerRunning(_ running: Bool) { isSocketServerRunning = running }
}
