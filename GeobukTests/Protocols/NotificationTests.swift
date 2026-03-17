import Testing
import Foundation
@testable import Geobuk

@Suite("GeobukNotification")
struct GeobukNotificationTests {
    @Test("init_필수필드설정_정상생성")
    func init_requiredFields_createsSuccessfully() {
        let notification = GeobukNotification(
            source: "claude-session",
            title: "Permission Required",
            body: "Claude wants to edit file.swift",
            priority: .immediate
        )

        #expect(notification.source == "claude-session")
        #expect(notification.title == "Permission Required")
        #expect(notification.body == "Claude wants to edit file.swift")
        #expect(notification.priority == .immediate)
    }

    @Test("init_고유ID생성_중복없음")
    func init_uniqueIds_noDuplicates() {
        let n1 = GeobukNotification(source: "test", title: "t", body: "b", priority: .normal)
        let n2 = GeobukNotification(source: "test", title: "t", body: "b", priority: .normal)
        #expect(n1.id != n2.id)
    }

    @Test("init_타임스탬프자동설정_현재시간근처")
    func init_timestamp_nearCurrentTime() {
        let before = Date()
        let notification = GeobukNotification(source: "test", title: "t", body: "b", priority: .normal)
        let after = Date()

        #expect(notification.timestamp >= before)
        #expect(notification.timestamp <= after)
    }

    @Test("priority_immediate_즉시타입")
    func priority_immediate() {
        let n = GeobukNotification(source: "s", title: "t", body: "b", priority: .immediate)
        #expect(n.priority == .immediate)
    }

    @Test("priority_normal_일반타입")
    func priority_normal() {
        let n = GeobukNotification(source: "s", title: "t", body: "b", priority: .normal)
        #expect(n.priority == .normal)
    }
}
