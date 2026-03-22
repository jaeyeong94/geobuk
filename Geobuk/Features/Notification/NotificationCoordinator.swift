import AppKit
import Foundation
import Observation
import UserNotifications

/// 모든 알림 소스를 수집하고 관리하는 중앙 코디네이터
/// Claude 이벤트, 셸 명령 완료, 시스템 이벤트를 하나의 알림 스트림으로 통합
@MainActor
@Observable
final class NotificationCoordinator {

    init() {
        let defaults = UserDefaults.standard
        self.nativeNotificationsEnabled = defaults.object(forKey: "notif.nativeEnabled") as? Bool ?? true
        self.longCommandThreshold = defaults.object(forKey: "notif.longCommandThreshold") as? TimeInterval ?? 30
    }

    // MARK: - Public State

    /// 읽지 않은 알림 목록 (최신 순)
    private(set) var unreadNotifications: [GeobukNotification] = []

    /// 전체 알림 히스토리 (최신 순, 최대 100개)
    private(set) var allNotifications: [GeobukNotification] = []

    /// 현재 활성 알림 (패널 링 표시용, 해제 전까지 유지)
    private(set) var activeAlerts: [PaneAlert] = []

    /// 읽지 않은 알림 수
    var unreadCount: Int { unreadNotifications.count }

    /// 알림이 있는지
    var hasUnread: Bool { !unreadNotifications.isEmpty }

    // MARK: - Settings (UserDefaults 영속)

    /// macOS 네이티브 알림 활성화 여부
    var nativeNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(nativeNotificationsEnabled, forKey: "notif.nativeEnabled") }
    }

    /// 장시간 명령 완료 알림 임계값 (초)
    var longCommandThreshold: TimeInterval {
        didSet { UserDefaults.standard.set(longCommandThreshold, forKey: "notif.longCommandThreshold") }
    }

    // MARK: - Private

    private static let maxHistory = 100

    /// 코얼레싱 타이머 (normal 우선순위)
    private var coalescingBuffer: [GeobukNotification] = []
    private var coalescingTask: Task<Void, Never>?

    /// 명령 시작 시각 추적 (surfaceId → 시작 시각)
    private var commandStartTimes: [String: Date] = [:]

    // MARK: - 알림 발행

    /// 알림을 발행한다
    func post(_ notification: GeobukNotification) {
        switch notification.priority {
        case .immediate:
            deliverImmediate(notification)
        case .normal:
            bufferForCoalescing(notification)
        }
    }

    /// Claude 세션 이벤트로부터 알림을 생성한다
    /// surfaceId: Claude가 실행 중인 패널의 viewId (링 표시용)
    func handleClaudeEvent(phase: AISessionPhase, sessionId: String, toolName: String?, costUSD: Double, surfaceId: String? = nil) {
        // source에 surfaceId를 포함하여 패널 링 매칭 가능하게 함
        let source = surfaceId.map { "claude:\(sessionId):\($0)" } ?? "claude:\(sessionId)"

        switch phase {
        case .toolExecuting:
            let tool = toolName ?? "unknown"
            post(GeobukNotification(
                source: source,
                title: "Claude: Tool Use",
                body: tool,
                priority: .immediate
            ))

        case .waitingForInput:
            let tool = toolName ?? "unknown"
            post(GeobukNotification(
                source: source,
                title: "Claude is waiting for input",
                body: "Permission required for: \(tool)",
                priority: .immediate
            ))

        case .sessionComplete:
            let costStr = SessionFormatter.formatCost(costUSD)
            post(GeobukNotification(
                source: source,
                title: "Claude session complete",
                body: "Cost: \(costStr)",
                priority: .immediate
            ))

        default:
            break
        }
    }

    /// 셸 명령 시작을 기록한다
    func commandStarted(surfaceId: String) {
        commandStartTimes[surfaceId] = Date()
    }

    /// 셸 명령 완료 시 장시간 실행이면 알림을 생성한다
    func commandFinished(surfaceId: String, command: String?) {
        guard let startTime = commandStartTimes.removeValue(forKey: surfaceId) else { return }
        let elapsed = Date().timeIntervalSince(startTime)

        if elapsed >= longCommandThreshold {
            let duration = SessionFormatter.formatElapsedTime(elapsed)
            let cmd = command ?? "Command"
            post(GeobukNotification(
                source: "shell:\(surfaceId)",
                title: "\(cmd) finished",
                body: "Completed in \(duration)",
                priority: .immediate
            ))
        }
    }

    // MARK: - 알림 해제

    /// 특정 알림을 읽음 처리한다
    func markAsRead(_ id: UUID) {
        unreadNotifications.removeAll { $0.id == id }
        activeAlerts.removeAll { $0.notificationId == id }
        updateDockBadge()
    }

    /// 특정 소스의 모든 알림을 읽음 처리한다 (사용자가 패널을 직접 포커스할 때만 호출)
    /// source는 surfaceId — 알림의 source("shell:{id}", "claude:{id}")에 포함되는지 검사
    func markAllAsRead(source: String) {
        unreadNotifications.removeAll { $0.source.contains(source) }
        activeAlerts.removeAll { $0.source.contains(source) }
        updateDockBadge()
    }

    /// 모든 알림을 읽음 처리한다
    func markAllAsRead() {
        unreadNotifications.removeAll()
        activeAlerts.removeAll()
        updateDockBadge()
    }

    /// 히스토리를 모두 삭제한다
    func clearHistory() {
        allNotifications.removeAll()
        unreadNotifications.removeAll()
        activeAlerts.removeAll()
        updateDockBadge()
    }

    // MARK: - Dock Badge

    /// Dock 아이콘 뱃지를 읽지 않은 알림 수로 갱신한다
    private func updateDockBadge() {
        let count = unreadNotifications.count

        // NSApp.dockTile 방식 (기본)
        let label = count > 0 ? "\(count)" : nil
        NSApp.dockTile.badgeLabel = label
        NSApp.dockTile.display()

        // UNUserNotificationCenter 방식 (macOS 14+ Dock 뱃지 연동)
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error {
                GeobukLogger.debug(.app, "setBadgeCount failed: \(error.localizedDescription)")
            }
        }

    }

    // MARK: - 패널별 알림 조회

    /// 특정 surfaceId에 대한 활성 알림이 있는지
    func hasAlert(for surfaceId: String) -> Bool {
        activeAlerts.contains { $0.source.contains(surfaceId) }
    }

    /// 특정 surfaceId의 알림 색상 (링 표시용)
    func alertColor(for surfaceId: String) -> PaneAlertType? {
        activeAlerts.first { $0.source.contains(surfaceId) }?.type
    }

    // MARK: - Private

    private func deliverImmediate(_ notification: GeobukNotification) {
        addToHistory(notification)
        unreadNotifications.insert(notification, at: 0)

        // 패널 알림 타입 결정
        let alertType: PaneAlertType
        if notification.title.contains("waiting") {
            alertType = .permissionRequest   // 빨강 펄스
        } else if notification.title.contains("Tool Use") {
            alertType = .commandComplete     // 파랑
        } else if notification.title.contains("complete") {
            alertType = .sessionComplete     // 초록
        } else {
            alertType = .commandComplete     // 파랑 (기본)
        }
        activeAlerts.append(PaneAlert(
            notificationId: notification.id,
            source: notification.source,
            type: alertType,
            timestamp: notification.timestamp
        ))

        // Dock 뱃지 갱신
        updateDockBadge()

        // macOS 네이티브 알림 (앱이 비활성일 때)
        if nativeNotificationsEnabled {
            sendNativeNotification(notification)
        }

        // NotificationCenter 브로드캐스트 (UI 갱신용)
        NotificationCenter.default.post(name: .geobukNotificationPosted, object: notification)

        GeobukLogger.info(.app, "Notification posted (immediate)", context: ["title": notification.title])
    }

    private func bufferForCoalescing(_ notification: GeobukNotification) {
        coalescingBuffer.append(notification)

        coalescingTask?.cancel()
        coalescingTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            guard !Task.isCancelled else { return }
            flushCoalescingBuffer()
        }
    }

    private func flushCoalescingBuffer() {
        guard !coalescingBuffer.isEmpty else { return }

        // 같은 소스의 알림은 마지막 것만 유지
        var latestBySource: [String: GeobukNotification] = [:]
        for notification in coalescingBuffer {
            latestBySource[notification.source] = notification
        }
        coalescingBuffer.removeAll()

        for notification in latestBySource.values {
            addToHistory(notification)
        }
    }

    private func addToHistory(_ notification: GeobukNotification) {
        allNotifications.insert(notification, at: 0)
        if allNotifications.count > Self.maxHistory {
            allNotifications = Array(allNotifications.prefix(Self.maxHistory))
        }
    }

    // MARK: - macOS Native Notification

    private func sendNativeNotification(_ notification: GeobukNotification) {
        // 앱이 활성 상태이면 네이티브 알림 스킵
        guard !NSApplication.shared.isActive else { return }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: nil // 즉시 전달
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                GeobukLogger.warn(.app, "Native notification failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Models

/// 패널에 표시할 알림 상태
struct PaneAlert: Identifiable, Sendable {
    let id = UUID()
    let notificationId: UUID
    let source: String
    let type: PaneAlertType
    let timestamp: Date
}

/// 패널 알림 유형 (링 색상 결정)
enum PaneAlertType: Sendable {
    case permissionRequest  // 빨강
    case sessionComplete    // 초록
    case commandComplete    // 파랑
    case error              // 노랑
}

// MARK: - Notification Names

extension Notification.Name {
    /// 새 알림이 발행되었을 때 (object: GeobukNotification)
    static let geobukNotificationPosted = Notification.Name("geobukNotificationPosted")
    /// 패널의 알림 링 해제 (object: surfaceId String)
    static let geobukDismissRing = Notification.Name("geobukDismissRing")
}
