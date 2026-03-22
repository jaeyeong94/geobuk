import SwiftUI

/// 알림 패널 — 전체 알림 히스토리와 읽지 않은 알림을 표시한다
struct NotificationPanelView: View {
    var coordinator: NotificationCoordinator?

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack(spacing: 6) {
                Text("Notifications")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                let unread = coordinator?.unreadCount ?? 0
                if unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                }

                Spacer()

                Button(action: { coordinator?.clearHistory() }) {
                    Text("Clear All")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity((coordinator?.allNotifications.isEmpty ?? true) ? 0.4 : 1.0)
                .disabled(coordinator?.allNotifications.isEmpty ?? true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // 알림 목록
            let notifications = coordinator?.allNotifications ?? []
            if notifications.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No notifications")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(notifications) { notification in
                            NotificationRowView(
                                notification: notification,
                                isUnread: coordinator?.unreadNotifications.contains(where: { $0.id == notification.id }) ?? false,
                                onTap: { coordinator?.markAsRead(notification.id) }
                            )
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Notification Row

private struct NotificationRowView: View {
    let notification: GeobukNotification
    let isUnread: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 우선순위 색상 도트
            Circle()
                .fill(priorityColor)
                .frame(width: 7, height: 7)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    // 소스 아이콘
                    Text(sourceIcon)
                        .font(.system(size: 11))

                    // 제목
                    Text(notification.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    // 상대 시간
                    Text(relativeTimeString(from: notification.timestamp))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // 본문
                if !notification.body.isEmpty {
                    Text(notification.body)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            isUnread
                ? Color.accentColor.opacity(0.08)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var priorityColor: Color {
        switch notification.priority {
        case .immediate: return .red
        case .normal: return .gray
        }
    }

    private var sourceIcon: String {
        if notification.source.hasPrefix("claude:") { return "🤖" }
        if notification.source.hasPrefix("shell:") { return "💻" }
        return "🔔"
    }
}

// MARK: - Relative Time Formatter

private func relativeTimeString(from date: Date) -> String {
    let elapsed = Date().timeIntervalSince(date)
    switch elapsed {
    case ..<60:
        let secs = max(1, Int(elapsed))
        return "\(secs)s ago"
    case ..<3600:
        let mins = Int(elapsed / 60)
        return "\(mins)m ago"
    case ..<86400:
        let hours = Int(elapsed / 3600)
        return "\(hours)h ago"
    default:
        let days = Int(elapsed / 86400)
        return "\(days)d ago"
    }
}
