import Foundation

/// 알림 우선순위
enum NotificationPriority: Sendable {
    /// 즉시 전달 (permission_request, 세션 완료, 에러)
    case immediate

    /// 일반 (토큰 카운트, 진행률, 도구 실행) - 100ms 코얼레싱
    case normal
}

/// 앱 내부 알림 이벤트
struct GeobukNotification: Identifiable, Sendable {
    let id: UUID
    let source: String
    let title: String
    let body: String
    let priority: NotificationPriority
    let timestamp: Date

    init(source: String, title: String, body: String, priority: NotificationPriority) {
        self.id = UUID()
        self.source = source
        self.title = title
        self.body = body
        self.priority = priority
        self.timestamp = Date()
    }
}

/// 알림 소스 프로토콜 - 의존성 역전을 위한 추상화
/// Domain 레이어에 정의, Infrastructure/Platform 레이어에서 구현
protocol NotificationSource: AnyObject, Sendable {
    /// 알림 이벤트 스트림
    var notifications: AsyncStream<GeobukNotification> { get }
}
