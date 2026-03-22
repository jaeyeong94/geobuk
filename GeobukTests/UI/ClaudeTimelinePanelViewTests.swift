import Testing
import Foundation
@testable import Geobuk

// MARK: - TimelineEventType Tests

@Suite("TimelineEventType 아이콘 매핑")
struct TimelineEventTypeTests {

    @Test("text 타입은 말풍선 아이콘을 반환한다")
    func textIcon() {
        let entry = TimelineEntry(timestamp: .now, eventType: .text, toolName: nil, description: "test")
        #expect(entry.icon == "💬")
    }

    @Test("toolUse 타입은 렌치 아이콘을 반환한다")
    func toolUseIcon() {
        let entry = TimelineEntry(timestamp: .now, eventType: .toolUse, toolName: "bash", description: "test")
        #expect(entry.icon == "🔧")
    }

    @Test("toolResult 타입은 체크마크 아이콘을 반환한다")
    func toolResultIcon() {
        let entry = TimelineEntry(timestamp: .now, eventType: .toolResult, toolName: nil, description: "test")
        #expect(entry.icon == "✅")
    }

    @Test("permission 타입은 경고 아이콘을 반환한다")
    func permissionIcon() {
        let entry = TimelineEntry(timestamp: .now, eventType: .permission, toolName: nil, description: "test")
        #expect(entry.icon == "⚠️")
    }

    @Test("result 타입은 완료 깃발 아이콘을 반환한다")
    func resultIcon() {
        let entry = TimelineEntry(timestamp: .now, eventType: .result, toolName: nil, description: "test")
        #expect(entry.icon == "🏁")
    }

    @Test("error 타입은 X 아이콘을 반환한다")
    func errorIcon() {
        let entry = TimelineEntry(timestamp: .now, eventType: .error, toolName: nil, description: "test")
        #expect(entry.icon == "❌")
    }

    @Test("모든 이벤트 타입이 비어있지 않은 아이콘을 반환한다")
    func allTypesHaveNonEmptyIcon() {
        let allTypes: [TimelineEventType] = [.text, .toolUse, .toolResult, .permission, .result, .error]
        for type_ in allTypes {
            let entry = TimelineEntry(timestamp: .now, eventType: type_, toolName: nil, description: "")
            #expect(!entry.icon.isEmpty, "이벤트 타입 \(type_)의 아이콘이 비어있어서는 안 된다")
        }
    }

    @Test("각 이벤트 타입은 고유한 아이콘을 가진다")
    func allIconsAreUnique() {
        let allTypes: [TimelineEventType] = [.text, .toolUse, .toolResult, .permission, .result, .error]
        let icons = allTypes.map { type_ -> String in
            TimelineEntry(timestamp: .now, eventType: type_, toolName: nil, description: "").icon
        }
        let uniqueIcons = Set(icons)
        #expect(uniqueIcons.count == allTypes.count, "모든 이벤트 타입의 아이콘은 고유해야 한다")
    }
}

// MARK: - TimelineEntry Creation Tests

@Suite("TimelineEntry 생성")
struct TimelineEntryCreationTests {

    @Test("toolName이 nil인 경우 정상 생성된다")
    func creationWithNilToolName() {
        let entry = TimelineEntry(timestamp: .now, eventType: .text, toolName: nil, description: "응답 중")
        #expect(entry.toolName == nil)
        #expect(entry.description == "응답 중")
        #expect(entry.eventType == .text)
    }

    @Test("toolName이 있는 경우 정상 생성된다")
    func creationWithToolName() {
        let entry = TimelineEntry(timestamp: .now, eventType: .toolUse, toolName: "bash", description: "Executing bash")
        #expect(entry.toolName == "bash")
        #expect(entry.eventType == .toolUse)
    }

    @Test("빈 description으로 생성된다")
    func creationWithEmptyDescription() {
        let entry = TimelineEntry(timestamp: .now, eventType: .text, toolName: nil, description: "")
        #expect(entry.description == "")
    }

    @Test("각 항목은 고유한 ID를 가진다")
    func entriesHaveUniqueIDs() {
        let entry1 = TimelineEntry(timestamp: .now, eventType: .text, toolName: nil, description: "first")
        let entry2 = TimelineEntry(timestamp: .now, eventType: .text, toolName: nil, description: "second")
        #expect(entry1.id != entry2.id)
    }

    @Test("같은 인자로 두 번 생성하면 ID가 다르다")
    func sameArgsProduceDifferentIDs() {
        let ts = Date(timeIntervalSince1970: 1_000_000)
        let e1 = TimelineEntry(timestamp: ts, eventType: .result, toolName: "tool", description: "desc")
        let e2 = TimelineEntry(timestamp: ts, eventType: .result, toolName: "tool", description: "desc")
        #expect(e1.id != e2.id)
    }

    @Test("타임스탬프가 정확히 저장된다")
    func timestampIsStoredCorrectly() {
        let ts = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = TimelineEntry(timestamp: ts, eventType: .text, toolName: nil, description: "test")
        #expect(entry.timestamp == ts)
    }

    @Test("빈 문자열 toolName으로 생성된다")
    func creationWithEmptyStringToolName() {
        let entry = TimelineEntry(timestamp: .now, eventType: .toolUse, toolName: "", description: "test")
        #expect(entry.toolName == "")
    }

    @Test("긴 description으로 생성된다")
    func creationWithLongDescription() {
        let longDesc = String(repeating: "a", count: 10_000)
        let entry = TimelineEntry(timestamp: .now, eventType: .text, toolName: nil, description: longDesc)
        #expect(entry.description.count == 10_000)
    }

    @Test("유니코드 description으로 생성된다")
    func creationWithUnicodeDescription() {
        let desc = "실행 중 🔧 - ツール 执行"
        let entry = TimelineEntry(timestamp: .now, eventType: .toolUse, toolName: nil, description: desc)
        #expect(entry.description == desc)
    }
}

// MARK: - formattedTime Tests

@Suite("TimelineEntry formattedTime 포맷팅")
struct TimelineEntryFormattedTimeTests {

    @Test("formattedTime은 HH:mm:ss 형식으로 반환한다")
    func formattedTimeMatchesHHmmss() {
        let ts = Date(timeIntervalSince1970: 0) // 1970-01-01 00:00:00 UTC
        let entry = TimelineEntry(timestamp: ts, eventType: .text, toolName: nil, description: "test")

        // 형식이 HH:mm:ss 패턴과 일치하는지 정규식으로 검증
        let pattern = #"^\d{2}:\d{2}:\d{2}$"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(entry.formattedTime.startIndex..., in: entry.formattedTime)
        let matched = regex?.firstMatch(in: entry.formattedTime, range: range) != nil
        #expect(matched, "formattedTime '\(entry.formattedTime)'이 HH:mm:ss 형식이 아니다")
    }

    @Test("formattedTime의 길이는 항상 8자이다")
    func formattedTimeLengthIsAlwaysEight() {
        let timestamps: [TimeInterval] = [0, 3661, 86399, 43200, 12345]
        for interval in timestamps {
            let entry = TimelineEntry(
                timestamp: Date(timeIntervalSince1970: interval),
                eventType: .text,
                toolName: nil,
                description: ""
            )
            #expect(entry.formattedTime.count == 8, "타임스탬프 \(interval)에서 길이가 8이 아니다: '\(entry.formattedTime)'")
        }
    }

    @Test("formattedTime에 콜론이 두 개 포함된다")
    func formattedTimeContainsTwoColons() {
        let entry = TimelineEntry(timestamp: Date(), eventType: .text, toolName: nil, description: "")
        let colonCount = entry.formattedTime.filter { $0 == ":" }.count
        #expect(colonCount == 2)
    }

    @Test("서로 다른 타임스탬프는 서로 다른 formattedTime을 생성할 수 있다")
    func differentTimestampsProduceDifferentFormattedTimes() {
        // 1시간 차이가 나는 두 타임스탬프
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 15
        components.hour = 10
        components.minute = 30
        components.second = 0

        guard let ts1 = calendar.date(from: components) else { return }
        components.hour = 11
        guard let ts2 = calendar.date(from: components) else { return }

        let entry1 = TimelineEntry(timestamp: ts1, eventType: .text, toolName: nil, description: "")
        let entry2 = TimelineEntry(timestamp: ts2, eventType: .text, toolName: nil, description: "")

        #expect(entry1.formattedTime != entry2.formattedTime)
    }
}

// MARK: - Negative Tests

@Suite("TimelineEntry 네거티브 케이스")
struct TimelineEntryNegativeTests {

    @Test("toolName이 nil이어도 icon 접근 시 크래시가 없다")
    func iconAccessWithNilToolName() {
        let entry = TimelineEntry(timestamp: .now, eventType: .toolUse, toolName: nil, description: "test")
        let icon = entry.icon
        #expect(!icon.isEmpty)
    }

    @Test("description이 빈 문자열이어도 formattedTime은 정상 반환한다")
    func formattedTimeWithEmptyDescription() {
        let entry = TimelineEntry(timestamp: .now, eventType: .text, toolName: nil, description: "")
        #expect(!entry.formattedTime.isEmpty)
    }

    @Test("미래 타임스탬프도 HH:mm:ss 형식으로 포맷된다")
    func futureTimestampFormatsCorrectly() {
        let futureDate = Date(timeIntervalSinceNow: 86400 * 365 * 10) // 10년 후
        let entry = TimelineEntry(timestamp: futureDate, eventType: .text, toolName: nil, description: "future")
        let pattern = #"^\d{2}:\d{2}:\d{2}$"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(entry.formattedTime.startIndex..., in: entry.formattedTime)
        let matched = regex?.firstMatch(in: entry.formattedTime, range: range) != nil
        #expect(matched)
    }

    @Test("과거 타임스탬프도 HH:mm:ss 형식으로 포맷된다")
    func pastTimestampFormatsCorrectly() {
        let pastDate = Date(timeIntervalSince1970: 1) // 1970-01-01 00:00:01 UTC
        let entry = TimelineEntry(timestamp: pastDate, eventType: .result, toolName: nil, description: "past")
        let pattern = #"^\d{2}:\d{2}:\d{2}$"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(entry.formattedTime.startIndex..., in: entry.formattedTime)
        let matched = regex?.firstMatch(in: entry.formattedTime, range: range) != nil
        #expect(matched)
    }

    @Test("특수문자가 포함된 toolName도 저장된다")
    func specialCharacterToolNameIsStored() {
        let specialTool = "tool<>\"&name"
        let entry = TimelineEntry(timestamp: .now, eventType: .toolUse, toolName: specialTool, description: "test")
        #expect(entry.toolName == specialTool)
    }

    @Test("error 타입 항목은 다른 타입과 icon이 다르다")
    func errorIconDiffersFromOthers() {
        let errorEntry = TimelineEntry(timestamp: .now, eventType: .error, toolName: nil, description: "fail")
        let textEntry = TimelineEntry(timestamp: .now, eventType: .text, toolName: nil, description: "ok")
        #expect(errorEntry.icon != textEntry.icon)
    }

    @Test("동일 timestamp의 두 항목은 독립적인 ID를 가진다")
    func sameTimestampEntriesHaveIndependentIDs() {
        let now = Date()
        var ids: Set<UUID> = []
        for _ in 0..<100 {
            let entry = TimelineEntry(timestamp: now, eventType: .text, toolName: nil, description: "")
            ids.insert(entry.id)
        }
        #expect(ids.count == 100, "100개의 항목 모두 고유한 ID를 가져야 한다")
    }
}
