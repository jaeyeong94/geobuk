import Testing
import Foundation
@testable import Geobuk

@Suite("NotificationCoordinator - 알림 코디네이터")
@MainActor
struct NotificationCoordinatorTests {

    // MARK: - 초기 상태

    @Test("init_초기상태_unreadCount0")
    func init_initialState_unreadCountIsZero() {
        let coordinator = NotificationCoordinator()
        #expect(coordinator.unreadCount == 0)
    }

    @Test("init_초기상태_hasUnreadFalse")
    func init_initialState_hasUnreadIsFalse() {
        let coordinator = NotificationCoordinator()
        #expect(coordinator.hasUnread == false)
    }

    @Test("init_초기상태_allNotifications비어있음")
    func init_initialState_allNotificationsEmpty() {
        let coordinator = NotificationCoordinator()
        #expect(coordinator.allNotifications.isEmpty)
    }

    @Test("init_기본설정_longCommandThreshold30초")
    func init_defaults_longCommandThreshold30() {
        UserDefaults.standard.removeObject(forKey: "notif.longCommandThreshold")
        let coordinator = NotificationCoordinator()
        #expect(coordinator.longCommandThreshold == 30)
    }

    @Test("init_기본설정_nativeNotificationsEnabled기본true")
    func init_defaults_nativeNotificationsEnabledTrue() {
        UserDefaults.standard.removeObject(forKey: "notif.nativeEnabled")
        let coordinator = NotificationCoordinator()
        #expect(coordinator.nativeNotificationsEnabled == true)
    }

    // MARK: - 설정 변경

    @Test("longCommandThreshold_변경_UserDefaults에저장됨")
    func longCommandThreshold_changed_persistedToUserDefaults() {
        let coordinator = NotificationCoordinator()
        coordinator.longCommandThreshold = 60
        #expect(UserDefaults.standard.object(forKey: "notif.longCommandThreshold") as? TimeInterval == 60)
    }

    @Test("nativeNotificationsEnabled_변경_UserDefaults에저장됨")
    func nativeNotificationsEnabled_changed_persistedToUserDefaults() {
        let coordinator = NotificationCoordinator()
        coordinator.nativeNotificationsEnabled = false
        #expect(UserDefaults.standard.object(forKey: "notif.nativeEnabled") as? Bool == false)
    }

    // MARK: - post() - immediate 우선순위

    @Test("post_immediate_unreadNotifications에추가됨")
    func post_immediatePriority_addedToUnreadNotifications() {
        let coordinator = NotificationCoordinator()
        let notification = GeobukNotification(source: "test", title: "Test", body: "Body", priority: .immediate)
        coordinator.post(notification)
        #expect(coordinator.unreadNotifications.count == 1)
        #expect(coordinator.unreadNotifications[0].id == notification.id)
    }

    @Test("post_immediate_allNotifications에추가됨")
    func post_immediatePriority_addedToAllNotifications() {
        let coordinator = NotificationCoordinator()
        let notification = GeobukNotification(source: "test", title: "Test", body: "Body", priority: .immediate)
        coordinator.post(notification)
        #expect(coordinator.allNotifications.count == 1)
        #expect(coordinator.allNotifications[0].id == notification.id)
    }

    @Test("post_immediate_unreadCount증가")
    func post_immediatePriority_incrementsUnreadCount() {
        let coordinator = NotificationCoordinator()
        coordinator.post(GeobukNotification(source: "s1", title: "T1", body: "B1", priority: .immediate))
        coordinator.post(GeobukNotification(source: "s2", title: "T2", body: "B2", priority: .immediate))
        #expect(coordinator.unreadCount == 2)
    }

    @Test("post_immediate_hasUnreadTrue")
    func post_immediatePriority_hasUnreadBecomesTrue() {
        let coordinator = NotificationCoordinator()
        coordinator.post(GeobukNotification(source: "s", title: "T", body: "B", priority: .immediate))
        #expect(coordinator.hasUnread == true)
    }

    // MARK: - post() - normal 우선순위 (버퍼링)

    @Test("post_normal_버퍼링됨_즉시unreadNotifications에없음")
    func post_normalPriority_buffered_notImmediatelyInUnread() {
        let coordinator = NotificationCoordinator()
        let notification = GeobukNotification(source: "test", title: "Test", body: "Body", priority: .normal)
        coordinator.post(notification)
        // normal은 코얼레싱 타이머 후 flush되므로 즉시는 unread에 없음
        #expect(coordinator.unreadNotifications.isEmpty)
    }

    @Test("post_normal_버퍼링됨_즉시allNotifications에없음")
    func post_normalPriority_buffered_notImmediatelyInAllNotifications() {
        let coordinator = NotificationCoordinator()
        let notification = GeobukNotification(source: "test", title: "Test", body: "Body", priority: .normal)
        coordinator.post(notification)
        // normal은 코얼레싱 타이머 후 flush되므로 즉시는 allNotifications에 없음
        #expect(coordinator.allNotifications.isEmpty)
    }

    // MARK: - handleClaudeEvent

    @Test("handleClaudeEvent_toolExecuting_알림생성됨")
    func handleClaudeEvent_toolExecuting_createsNotification() {
        let coordinator = NotificationCoordinator()
        coordinator.handleClaudeEvent(
            phase: .toolExecuting,
            sessionId: "sess-1",
            toolName: "Bash",
            costUSD: 0.01
        )
        #expect(coordinator.allNotifications.count == 1)
        #expect(coordinator.allNotifications[0].title == "Claude: Tool Use")
        #expect(coordinator.allNotifications[0].body == "Bash")
    }

    @Test("handleClaudeEvent_toolExecuting_toolName없으면unknown")
    func handleClaudeEvent_toolExecuting_nilToolName_usesUnknown() {
        let coordinator = NotificationCoordinator()
        coordinator.handleClaudeEvent(
            phase: .toolExecuting,
            sessionId: "sess-2",
            toolName: nil,
            costUSD: 0.0
        )
        #expect(coordinator.allNotifications[0].body == "unknown")
    }

    @Test("handleClaudeEvent_sessionComplete_알림생성됨")
    func handleClaudeEvent_sessionComplete_createsNotification() {
        let coordinator = NotificationCoordinator()
        coordinator.handleClaudeEvent(
            phase: .sessionComplete,
            sessionId: "sess-3",
            toolName: nil,
            costUSD: 0.05
        )
        #expect(coordinator.allNotifications.count == 1)
        #expect(coordinator.allNotifications[0].title == "Claude session complete")
    }

    @Test("handleClaudeEvent_waitingForInput_알림생성됨")
    func handleClaudeEvent_waitingForInput_createsNotification() {
        let coordinator = NotificationCoordinator()
        coordinator.handleClaudeEvent(
            phase: .waitingForInput,
            sessionId: "sess-4",
            toolName: "Edit",
            costUSD: 0.0
        )
        #expect(coordinator.allNotifications.count == 1)
        #expect(coordinator.allNotifications[0].title == "Claude is waiting for input")
        #expect(coordinator.allNotifications[0].body.contains("Edit"))
    }

    @Test("handleClaudeEvent_idle_알림생성안됨")
    func handleClaudeEvent_idle_noNotification() {
        let coordinator = NotificationCoordinator()
        coordinator.handleClaudeEvent(
            phase: .idle,
            sessionId: "sess-5",
            toolName: nil,
            costUSD: 0.0
        )
        #expect(coordinator.allNotifications.isEmpty)
    }

    @Test("handleClaudeEvent_responding_알림생성안됨")
    func handleClaudeEvent_responding_noNotification() {
        let coordinator = NotificationCoordinator()
        coordinator.handleClaudeEvent(
            phase: .responding,
            sessionId: "sess-6",
            toolName: nil,
            costUSD: 0.0
        )
        #expect(coordinator.allNotifications.isEmpty)
    }

    @Test("handleClaudeEvent_sessionActive_알림생성안됨")
    func handleClaudeEvent_sessionActive_noNotification() {
        let coordinator = NotificationCoordinator()
        coordinator.handleClaudeEvent(
            phase: .sessionActive,
            sessionId: "sess-7",
            toolName: nil,
            costUSD: 0.0
        )
        #expect(coordinator.allNotifications.isEmpty)
    }

    @Test("handleClaudeEvent_surfaceId포함_source에surfaceId포함됨")
    func handleClaudeEvent_withSurfaceId_sourceContainsSurfaceId() {
        let coordinator = NotificationCoordinator()
        coordinator.handleClaudeEvent(
            phase: .toolExecuting,
            sessionId: "sess-8",
            toolName: "Read",
            costUSD: 0.0,
            surfaceId: "pane-42"
        )
        let source = coordinator.allNotifications[0].source
        #expect(source.contains("pane-42"))
    }

    // MARK: - commandStarted / commandFinished

    @Test("commandStarted_시작시각기록됨")
    func commandStarted_recordsStartTime() {
        let coordinator = NotificationCoordinator()
        // commandStarted 호출 후 commandFinished가 startTime을 사용할 수 있어야 한다
        coordinator.commandStarted(surfaceId: "pane-1")
        // threshold보다 충분히 짧으므로 알림 없음
        coordinator.longCommandThreshold = 9999
        coordinator.commandFinished(surfaceId: "pane-1", command: "ls")
        // 임계값 초과 안 했으므로 알림 없음
        #expect(coordinator.allNotifications.isEmpty)
    }

    @Test("commandFinished_임계값초과_알림생성됨")
    func commandFinished_elapsedExceedsThreshold_createsNotification() {
        let coordinator = NotificationCoordinator()
        coordinator.longCommandThreshold = 0  // 모든 경과 시간이 임계값 초과
        coordinator.commandStarted(surfaceId: "pane-2")
        coordinator.commandFinished(surfaceId: "pane-2", command: "make build")
        #expect(coordinator.allNotifications.count == 1)
        #expect(coordinator.allNotifications[0].title.contains("make build"))
    }

    @Test("commandFinished_임계값미만_알림생성안됨")
    func commandFinished_elapsedBelowThreshold_noNotification() {
        let coordinator = NotificationCoordinator()
        coordinator.longCommandThreshold = 9999  // 매우 높은 임계값
        coordinator.commandStarted(surfaceId: "pane-3")
        coordinator.commandFinished(surfaceId: "pane-3", command: "echo hello")
        #expect(coordinator.allNotifications.isEmpty)
    }

    @Test("commandFinished_commandNil_기본제목사용")
    func commandFinished_nilCommand_usesDefaultTitle() {
        let coordinator = NotificationCoordinator()
        coordinator.longCommandThreshold = 0
        coordinator.commandStarted(surfaceId: "pane-4")
        coordinator.commandFinished(surfaceId: "pane-4", command: nil)
        #expect(coordinator.allNotifications.count == 1)
        #expect(coordinator.allNotifications[0].title.contains("Command"))
    }

    @Test("commandFinished_started없이호출_알림생성안됨")
    func commandFinished_withoutCommandStarted_noNotification() {
        let coordinator = NotificationCoordinator()
        coordinator.longCommandThreshold = 0
        coordinator.commandFinished(surfaceId: "pane-unknown", command: "ls")
        #expect(coordinator.allNotifications.isEmpty)
    }

    // MARK: - markAsRead(id)

    @Test("markAsRead_id지정_해당알림제거됨")
    func markAsRead_specificId_removesNotification() {
        let coordinator = NotificationCoordinator()
        let n1 = GeobukNotification(source: "s1", title: "T1", body: "B", priority: .immediate)
        let n2 = GeobukNotification(source: "s2", title: "T2", body: "B", priority: .immediate)
        coordinator.post(n1)
        coordinator.post(n2)
        coordinator.markAsRead(n1.id)
        #expect(coordinator.unreadNotifications.count == 1)
        #expect(coordinator.unreadNotifications[0].id == n2.id)
    }

    @Test("markAsRead_존재하지않는id_변화없음")
    func markAsRead_nonExistentId_noChange() {
        let coordinator = NotificationCoordinator()
        let n = GeobukNotification(source: "s", title: "T", body: "B", priority: .immediate)
        coordinator.post(n)
        coordinator.markAsRead(UUID())  // 존재하지 않는 id
        #expect(coordinator.unreadNotifications.count == 1)
    }

    // MARK: - markAllAsRead(source:)

    @Test("markAllAsRead_source지정_해당소스알림제거됨")
    func markAllAsRead_source_removesMatchingNotifications() {
        let coordinator = NotificationCoordinator()
        coordinator.post(GeobukNotification(source: "shell:pane-1", title: "T1", body: "B", priority: .immediate))
        coordinator.post(GeobukNotification(source: "claude:sess:pane-1", title: "T2", body: "B", priority: .immediate))
        coordinator.post(GeobukNotification(source: "shell:pane-2", title: "T3", body: "B", priority: .immediate))
        coordinator.markAllAsRead(source: "pane-1")
        // pane-1을 포함하는 소스의 알림 2개가 제거되고 pane-2만 남음
        #expect(coordinator.unreadNotifications.count == 1)
        #expect(coordinator.unreadNotifications[0].source.contains("pane-2"))
    }

    @Test("markAllAsRead_source매칭없음_변화없음")
    func markAllAsRead_sourceNoMatch_noChange() {
        let coordinator = NotificationCoordinator()
        coordinator.post(GeobukNotification(source: "shell:pane-5", title: "T", body: "B", priority: .immediate))
        coordinator.markAllAsRead(source: "pane-99")
        #expect(coordinator.unreadNotifications.count == 1)
    }

    // MARK: - markAllAsRead()

    @Test("markAllAsRead_전체_모든알림제거됨")
    func markAllAsRead_all_removesAllNotifications() {
        let coordinator = NotificationCoordinator()
        coordinator.post(GeobukNotification(source: "s1", title: "T1", body: "B", priority: .immediate))
        coordinator.post(GeobukNotification(source: "s2", title: "T2", body: "B", priority: .immediate))
        coordinator.markAllAsRead()
        #expect(coordinator.unreadNotifications.isEmpty)
        #expect(coordinator.unreadCount == 0)
        #expect(coordinator.hasUnread == false)
    }

    // MARK: - clearHistory

    @Test("clearHistory_모든히스토리삭제됨")
    func clearHistory_clearsEverything() {
        let coordinator = NotificationCoordinator()
        coordinator.post(GeobukNotification(source: "s1", title: "T1", body: "B", priority: .immediate))
        coordinator.post(GeobukNotification(source: "s2", title: "T2", body: "B", priority: .immediate))
        coordinator.clearHistory()
        #expect(coordinator.allNotifications.isEmpty)
        #expect(coordinator.unreadNotifications.isEmpty)
        #expect(coordinator.unreadCount == 0)
    }

    // MARK: - maxHistory 제한 (100개)

    @Test("maxHistory_100개초과시_최신100개만유지")
    func maxHistory_over100_keepsLatest100() {
        let coordinator = NotificationCoordinator()
        for i in 0..<110 {
            coordinator.post(GeobukNotification(
                source: "s\(i)",
                title: "T\(i)",
                body: "B",
                priority: .immediate
            ))
        }
        #expect(coordinator.allNotifications.count == 100)
    }

    @Test("maxHistory_정확히100개_100개유지")
    func maxHistory_exactly100_keeps100() {
        let coordinator = NotificationCoordinator()
        for i in 0..<100 {
            coordinator.post(GeobukNotification(
                source: "s\(i)",
                title: "T\(i)",
                body: "B",
                priority: .immediate
            ))
        }
        #expect(coordinator.allNotifications.count == 100)
    }
}
