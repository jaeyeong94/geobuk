import Foundation

/// 셸의 상태 정보 (prompt 대기 중 또는 명령 실행 중)
struct ShellState: Sendable {
    /// "prompt" (유휴) 또는 "running" (명령 실행 중)
    let state: String
    /// 실행 중인 명령어 (state가 "running"일 때만 유효)
    let command: String?
    /// 상태가 마지막으로 업데이트된 시각
    let updatedAt: Date
}

/// Surface별 TTY 이름과 셸 상태를 추적하는 매니저
/// 셸 통합 스크립트가 소켓을 통해 보고하는 정보를 저장한다
@MainActor
@Observable
final class ShellStateManager {
    /// surfaceId -> TTY 이름 (예: "/dev/ttys001")
    private(set) var ttyNames: [String: String] = [:]

    /// surfaceId -> 셸 상태
    private(set) var shellStates: [String: ShellState] = [:]

    /// TTY 이름을 등록한다
    func reportTty(surfaceId: String, tty: String) {
        ttyNames[surfaceId] = tty
        GeobukLogger.info(.shell, "TTY reported", context: ["surfaceId": surfaceId, "tty": tty])
    }

    /// 셸 상태를 업데이트한다
    func reportState(surfaceId: String, state: String, command: String?) {
        shellStates[surfaceId] = ShellState(
            state: state,
            command: command,
            updatedAt: Date()
        )
        GeobukLogger.debug(.shell, "Shell state changed", context: ["surfaceId": surfaceId, "state": state, "command": command ?? ""])

        // 프롬프트 상태로 전환 시 알림 발송 (명령 완료 감지용)
        if state == "prompt" {
            NotificationCenter.default.post(
                name: .geobukShellPromptReady,
                object: nil,
                userInfo: ["surfaceId": surfaceId]
            )
        }
    }

    /// Surface 제거 시 관련 데이터를 정리한다
    func removeSurface(surfaceId: String) {
        ttyNames.removeValue(forKey: surfaceId)
        shellStates.removeValue(forKey: surfaceId)
        GeobukLogger.debug(.shell, "Surface removed", context: ["surfaceId": surfaceId])
    }

}

// MARK: - Notifications

extension Notification.Name {
    /// 셸이 프롬프트 상태로 전환될 때 발생 (userInfo: ["surfaceId": String])
    static let geobukShellPromptReady = Notification.Name("geobukShellPromptReady")
}

extension ShellStateManager {
    /// 사이드바 표시용 프로세스 이름을 반환한다
    /// running 상태이면 실행 중인 command를, prompt 상태이면 nil을 반환한다
    func displayProcessName(for surfaceId: String) -> String? {
        guard let shellState = shellStates[surfaceId] else { return nil }
        if shellState.state == "running", let command = shellState.command {
            return command
        }
        return nil
    }
}
