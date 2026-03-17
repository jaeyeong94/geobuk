import Testing
import Foundation
@testable import Geobuk

@Suite("StreamJSONParser")
struct StreamJSONParserTests {

    // MARK: - 단위 테스트 (Unit Tests)

    @Test("feed_유효한initJSON_sessionInit이벤트반환")
    func feed_validInitJSON_returnsSessionInitEvent() async {
        let parser = StreamJSONParser()
        let json = "{\"type\":\"system\",\"subtype\":\"init\",\"session_id\":\"sess-001\",\"tools\":[]}\n"
        let events = await parser.feed(Data(json.utf8))
        #expect(events.count == 1)
        if case .sessionInit(let sessionId) = events.first {
            #expect(sessionId == "sess-001")
        } else {
            Issue.record("Expected sessionInit event")
        }
    }

    @Test("feed_assistantText_assistantMessage이벤트반환")
    func feed_assistantTextJSON_returnsAssistantMessageEvent() async {
        let parser = StreamJSONParser()
        let json = "{\"type\":\"assistant\",\"subtype\":\"text\",\"text\":\"Hello world\"}\n"
        let events = await parser.feed(Data(json.utf8))
        #expect(events.count == 1)
        if case .assistantMessage(let text) = events.first {
            #expect(text == "Hello world")
        } else {
            Issue.record("Expected assistantMessage event")
        }
    }

    @Test("feed_toolUseJSON_toolUse이벤트반환")
    func feed_toolUseJSON_returnsToolUseEvent() async {
        let parser = StreamJSONParser()
        let json = "{\"type\":\"assistant\",\"subtype\":\"tool_use\",\"id\":\"tu-1\",\"name\":\"Edit\",\"input\":{\"file\":\"a.swift\"}}\n"
        let events = await parser.feed(Data(json.utf8))
        #expect(events.count == 1)
        if case .toolUse(let id, let name, _) = events.first {
            #expect(id == "tu-1")
            #expect(name == "Edit")
        } else {
            Issue.record("Expected toolUse event")
        }
    }

    @Test("feed_toolResultJSON_toolResult이벤트반환")
    func feed_toolResultJSON_returnsToolResultEvent() async {
        let parser = StreamJSONParser()
        let json = "{\"type\":\"result\",\"subtype\":\"tool_result\",\"tool_use_id\":\"tu-1\",\"content\":\"success\"}\n"
        let events = await parser.feed(Data(json.utf8))
        #expect(events.count == 1)
        if case .toolResult(let id, let content) = events.first {
            #expect(id == "tu-1")
            #expect(content == "success")
        } else {
            Issue.record("Expected toolResult event")
        }
    }

    @Test("feed_resultSuccessWithUsage_resultAndUsage이벤트반환")
    func feed_resultSuccessWithUsage_returnsResultAndUsageEvents() async {
        let parser = StreamJSONParser()
        let json = "{\"type\":\"result\",\"subtype\":\"success\",\"result\":\"done\",\"duration_ms\":1234,\"usage\":{\"input_tokens\":100,\"output_tokens\":200}}\n"
        let events = await parser.feed(Data(json.utf8))
        #expect(events.count == 2)
        if case .result(let text) = events.first {
            #expect(text == "done")
        } else {
            Issue.record("Expected result event, got \(String(describing: events.first))")
        }
        if case .usage(let input, let output) = events.last {
            #expect(input == 100)
            #expect(output == 200)
        } else {
            Issue.record("Expected usage event, got \(String(describing: events.last))")
        }
    }

    @Test("feed_permissionRequestJSON_permissionRequest이벤트반환")
    func feed_permissionRequestJSON_returnsPermissionRequestEvent() async {
        let parser = StreamJSONParser()
        let json = "{\"type\":\"assistant\",\"subtype\":\"permission_request\",\"tool_name\":\"Bash\"}\n"
        let events = await parser.feed(Data(json.utf8))
        #expect(events.count == 1)
        if case .permissionRequest(let toolName) = events.first {
            #expect(toolName == "Bash")
        } else {
            Issue.record("Expected permissionRequest event")
        }
    }

    @Test("feed_알수없는타입_unknown이벤트반환")
    func feed_unknownType_returnsUnknownEvent() async {
        let parser = StreamJSONParser()
        let json = "{\"type\":\"custom\",\"subtype\":\"special\",\"data\":\"value\"}\n"
        let events = await parser.feed(Data(json.utf8))
        #expect(events.count == 1)
        if case .unknown(let type, _) = events.first {
            #expect(type == "custom")
        } else {
            Issue.record("Expected unknown event")
        }
    }

    @Test("feed_복수이벤트한번에전달_모든이벤트반환")
    func feed_multipleEventsInOneFeed_returnsAllEvents() async {
        let parser = StreamJSONParser()
        let json = "{\"type\":\"system\",\"subtype\":\"init\",\"session_id\":\"s1\",\"tools\":[]}\n{\"type\":\"assistant\",\"subtype\":\"text\",\"text\":\"hi\"}\n"
        let events = await parser.feed(Data(json.utf8))
        #expect(events.count == 2)
        if case .sessionInit = events[0] {} else {
            Issue.record("Expected sessionInit as first event")
        }
        if case .assistantMessage = events[1] {} else {
            Issue.record("Expected assistantMessage as second event")
        }
    }

    // MARK: - 네거티브 테스트 (Negative Tests)

    @Test("feed_빈데이터_빈배열반환")
    func feed_emptyData_returnsEmptyArray() async {
        let parser = StreamJSONParser()
        let events = await parser.feed(Data())
        #expect(events.isEmpty)
    }

    @Test("feed_비JSON텍스트_무시")
    func feed_nonJSONText_ignored() async {
        let parser = StreamJSONParser()
        let text = "This is regular terminal output\n"
        let events = await parser.feed(Data(text.utf8))
        #expect(events.isEmpty)
    }

    @Test("feed_잘못된JSON_크래시없이무시")
    func feed_malformedJSON_ignoredWithoutCrash() async {
        let parser = StreamJSONParser()
        let text = "{broken json here\n"
        let events = await parser.feed(Data(text.utf8))
        #expect(events.isEmpty)
    }

    @Test("feed_type필드없는JSON_무시")
    func feed_jsonWithoutType_ignored() async {
        let parser = StreamJSONParser()
        let json = "{\"subtype\":\"text\",\"text\":\"no type field\"}\n"
        let events = await parser.feed(Data(json.utf8))
        #expect(events.isEmpty)
    }

    @Test("feed_부분라인버퍼링_완전한라인이올때까지대기")
    func feed_partialLine_buffersUntilComplete() async {
        let parser = StreamJSONParser()
        // Feed first half without newline
        let part1 = "{\"type\":\"assistant\",\"subtype\":\"text\""
        let events1 = await parser.feed(Data(part1.utf8))
        #expect(events1.isEmpty)

        // Feed second half with newline
        let part2 = ",\"text\":\"hello\"}\n"
        let events2 = await parser.feed(Data(part2.utf8))
        #expect(events2.count == 1)
        if case .assistantMessage(let text) = events2.first {
            #expect(text == "hello")
        } else {
            Issue.record("Expected assistantMessage event after completing partial line")
        }
    }

    @Test("feed_JSON과비JSON혼재_JSONのみパース")
    func feed_mixedJSONAndNonJSON_onlyParsesJSON() async {
        let parser = StreamJSONParser()
        let text = "Some terminal output\n{\"type\":\"assistant\",\"subtype\":\"text\",\"text\":\"parsed\"}\nMore terminal output\n"
        let events = await parser.feed(Data(text.utf8))
        #expect(events.count == 1)
        if case .assistantMessage(let t) = events.first {
            #expect(t == "parsed")
        } else {
            Issue.record("Expected assistantMessage event")
        }
    }

    @Test("feed_UTF8멀티바이트문자_정상파싱")
    func feed_utf8MultibyteCharacters_parsesCorrectly() async {
        let parser = StreamJSONParser()
        let json = "{\"type\":\"assistant\",\"subtype\":\"text\",\"text\":\"한글 테스트 🎉 日本語\"}\n"
        let events = await parser.feed(Data(json.utf8))
        #expect(events.count == 1)
        if case .assistantMessage(let text) = events.first {
            #expect(text == "한글 테스트 🎉 日本語")
        } else {
            Issue.record("Expected assistantMessage with Unicode text")
        }
    }

    @Test("reset_버퍼클리어_부분라인폐기")
    func reset_clearsBuffer_partialLineDiscarded() async {
        let parser = StreamJSONParser()
        // Feed partial line
        let part = "{\"type\":\"assistant\""
        _ = await parser.feed(Data(part.utf8))
        // Reset
        await parser.reset()
        // Feed a new complete line
        let json = "{\"type\":\"system\",\"subtype\":\"init\",\"session_id\":\"new\",\"tools\":[]}\n"
        let events = await parser.feed(Data(json.utf8))
        #expect(events.count == 1)
        if case .sessionInit(let id) = events.first {
            #expect(id == "new")
        } else {
            Issue.record("Expected sessionInit after reset")
        }
    }

    @Test("feed_resultSuccess_usage없음_result만반환")
    func feed_resultSuccessWithoutUsage_returnsResultOnly() async {
        let parser = StreamJSONParser()
        let json = "{\"type\":\"result\",\"subtype\":\"success\",\"result\":\"done\"}\n"
        let events = await parser.feed(Data(json.utf8))
        #expect(events.count == 1)
        if case .result(let text) = events.first {
            #expect(text == "done")
        } else {
            Issue.record("Expected result event without usage")
        }
    }

    // MARK: - 퍼징 테스트 (Fuzz Tests)

    @Test("feed_랜덤바이트_크래시없음")
    func feed_randomBytes_doesNotCrash() async {
        let parser = StreamJSONParser()
        for _ in 0..<100 {
            let size = Int.random(in: 0...1024)
            var bytes = [UInt8](repeating: 0, count: size)
            for i in 0..<size {
                bytes[i] = UInt8.random(in: 0...255)
            }
            let data = Data(bytes)
            _ = await parser.feed(data)
        }
        // If we get here without crashing, the test passes
    }

    @Test("feed_개행문자만_빈결과")
    func feed_onlyNewlines_emptyResults() async {
        let parser = StreamJSONParser()
        let data = Data("\n\n\n\n\n".utf8)
        let events = await parser.feed(data)
        #expect(events.isEmpty)
    }

    @Test("feed_매우큰JSON행_크래시없음")
    func feed_veryLargeLine_doesNotCrash() async {
        let parser = StreamJSONParser()
        let bigText = String(repeating: "a", count: 100_000)
        let json = "{\"type\":\"assistant\",\"subtype\":\"text\",\"text\":\"\(bigText)\"}\n"
        let events = await parser.feed(Data(json.utf8))
        #expect(events.count == 1)
    }

    @Test("feed_결과에캐시토큰포함_정상파싱")
    func feed_resultWithCacheTokens_parsesCorrectly() async {
        let parser = StreamJSONParser()
        let json = "{\"type\":\"result\",\"subtype\":\"success\",\"result\":\"ok\",\"usage\":{\"input_tokens\":100,\"output_tokens\":200,\"cache_read_tokens\":50,\"cache_write_tokens\":30}}\n"
        let events = await parser.feed(Data(json.utf8))
        // Should have result + usage
        #expect(events.count == 2)
    }
}
