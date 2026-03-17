import Testing
@testable import Geobuk

@Suite("StreamJSONEvent")
struct StreamJSONEventTests {
    @Test("sessionInit_세션ID포함")
    func sessionInit_containsSessionId() {
        let event = StreamJSONEvent.sessionInit(sessionId: "abc-123")
        if case .sessionInit(let id) = event {
            #expect(id == "abc-123")
        } else {
            Issue.record("Expected sessionInit event")
        }
    }

    @Test("toolUse_도구정보포함")
    func toolUse_containsToolInfo() {
        let event = StreamJSONEvent.toolUse(id: "tool-1", name: "Edit", input: "{}")
        if case .toolUse(let id, let name, let input) = event {
            #expect(id == "tool-1")
            #expect(name == "Edit")
            #expect(input == "{}")
        } else {
            Issue.record("Expected toolUse event")
        }
    }

    @Test("usage_토큰카운트포함")
    func usage_containsTokenCounts() {
        let event = StreamJSONEvent.usage(inputTokens: 1000, outputTokens: 500)
        if case .usage(let input, let output) = event {
            #expect(input == 1000)
            #expect(output == 500)
        } else {
            Issue.record("Expected usage event")
        }
    }
}

@Suite("OSCEvent")
struct OSCEventTests {
    @Test("notification_제목본문포함")
    func notification_containsTitleAndBody() {
        let event = OSCEvent.notification(title: "Alert", body: "Something happened")
        if case .notification(let title, let body) = event {
            #expect(title == "Alert")
            #expect(body == "Something happened")
        } else {
            Issue.record("Expected notification event")
        }
    }

    @Test("setTitle_타이틀문자열포함")
    func setTitle_containsTitle() {
        let event = OSCEvent.setTitle("My Terminal")
        if case .setTitle(let title) = event {
            #expect(title == "My Terminal")
        } else {
            Issue.record("Expected setTitle event")
        }
    }
}

@Suite("ParsedEvent")
struct ParsedEventTests {
    @Test("streamJSON_이벤트래핑")
    func streamJSON_wrapsEvent() {
        let inner = StreamJSONEvent.result(text: "done")
        let event = ParsedEvent.streamJSON(inner)
        if case .streamJSON(.result(let text)) = event {
            #expect(text == "done")
        } else {
            Issue.record("Expected streamJSON.result event")
        }
    }

    @Test("text_일반텍스트")
    func text_plainText() {
        let event = ParsedEvent.text("hello world")
        if case .text(let str) = event {
            #expect(str == "hello world")
        } else {
            Issue.record("Expected text event")
        }
    }
}
