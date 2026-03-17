import Foundation

/// Claude Code의 `--output-format stream-json` 출력을 파싱하는 액터
/// NDJSON (newline-delimited JSON) 형식의 데이터를 StreamJSONEvent로 변환한다
actor StreamJSONParser {
    private var buffer: Data = Data()

    /// 원시 PTY 출력 데이터를 받아 파싱된 이벤트 배열을 반환한다
    /// 불완전한 라인은 내부 버퍼에 보관하고 다음 호출 시 합쳐서 처리한다
    func feed(_ data: Data) -> [StreamJSONEvent] {
        guard !data.isEmpty else { return [] }

        buffer.append(data)

        var events: [StreamJSONEvent] = []
        let newline = UInt8(ascii: "\n")

        while let newlineIndex = buffer.firstIndex(of: newline) {
            let lineData = buffer[buffer.startIndex..<newlineIndex]
            buffer = Data(buffer[buffer.index(after: newlineIndex)...])

            guard !lineData.isEmpty else { continue }

            if let event = parseLine(lineData) {
                events.append(contentsOf: event)
            }
        }

        return events
    }

    /// 파서 상태 초기화
    func reset() {
        buffer = Data()
    }

    // MARK: - Private

    /// 단일 라인 데이터를 JSON으로 파싱하여 이벤트로 변환
    private func parseLine(_ data: Data) -> [StreamJSONEvent]? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = jsonObject["type"] as? String else {
            return nil
        }

        let subtype = jsonObject["subtype"] as? String ?? ""
        let raw = String(data: data, encoding: .utf8) ?? ""

        switch (type, subtype) {
        case ("system", "init"):
            let sessionId = jsonObject["session_id"] as? String ?? ""
            return [.sessionInit(sessionId: sessionId)]

        case ("assistant", "text"):
            let text = jsonObject["text"] as? String ?? ""
            return [.assistantMessage(text: text)]

        case ("assistant", "tool_use"):
            let id = jsonObject["id"] as? String ?? ""
            let name = jsonObject["name"] as? String ?? ""
            let inputString: String
            if let inputObj = jsonObject["input"] {
                if let inputData = try? JSONSerialization.data(withJSONObject: inputObj),
                   let str = String(data: inputData, encoding: .utf8) {
                    inputString = str
                } else {
                    inputString = String(describing: inputObj)
                }
            } else {
                inputString = ""
            }
            return [.toolUse(id: id, name: name, input: inputString)]

        case ("result", "tool_result"):
            let id = jsonObject["tool_use_id"] as? String ?? ""
            let content = jsonObject["content"] as? String ?? ""
            return [.toolResult(id: id, content: content)]

        case ("assistant", "permission_request"):
            let toolName = jsonObject["tool_name"] as? String ?? ""
            return [.permissionRequest(toolName: toolName)]

        case ("result", "success"):
            let resultText = jsonObject["result"] as? String ?? ""
            var events: [StreamJSONEvent] = [.result(text: resultText)]
            if let usage = jsonObject["usage"] as? [String: Any] {
                let inputTokens = usage["input_tokens"] as? Int ?? 0
                let outputTokens = usage["output_tokens"] as? Int ?? 0
                events.append(.usage(inputTokens: inputTokens, outputTokens: outputTokens))
            }
            return events

        default:
            return [.unknown(type: type, raw: raw)]
        }
    }
}
