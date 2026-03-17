import Testing
import Foundation
@testable import Geobuk

@Suite("JSONRPCHandler - JSON-RPC 2.0 처리")
struct JSONRPCHandlerTests {

    // MARK: - AnyCodable

    @Suite("AnyCodable")
    struct AnyCodableTests {

        @Test("string_인코딩디코딩_정확")
        func string_encodeDecodeExact() throws {
            let value = AnyCodable.string("hello")
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
            #expect(decoded == .string("hello"))
        }

        @Test("int_인코딩디코딩_정확")
        func int_encodeDecodeExact() throws {
            let value = AnyCodable.int(42)
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
            #expect(decoded == .int(42))
        }

        @Test("double_인코딩디코딩_정확")
        func double_encodeDecodeExact() throws {
            let value = AnyCodable.double(3.14)
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
            #expect(decoded == .double(3.14))
        }

        @Test("bool_인코딩디코딩_정확")
        func bool_encodeDecodeExact() throws {
            let value = AnyCodable.bool(true)
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
            #expect(decoded == .bool(true))
        }

        @Test("null_인코딩디코딩_정확")
        func null_encodeDecodeExact() throws {
            let value = AnyCodable.null
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
            #expect(decoded == .null)
        }

        @Test("array_인코딩디코딩_정확")
        func array_encodeDecodeExact() throws {
            let value = AnyCodable.array([.string("a"), .int(1)])
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
            #expect(decoded == .array([.string("a"), .int(1)]))
        }

        @Test("dictionary_인코딩디코딩_정확")
        func dictionary_encodeDecodeExact() throws {
            let value = AnyCodable.dictionary(["key": .string("value")])
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
            #expect(decoded == .dictionary(["key": .string("value")]))
        }

        @Test("stringValue_string에서추출")
        func stringValue_fromString() {
            let value = AnyCodable.string("test")
            #expect(value.stringValue == "test")
        }

        @Test("stringValue_nonString_nil")
        func stringValue_fromNonString_nil() {
            let value = AnyCodable.int(42)
            #expect(value.stringValue == nil)
        }

        @Test("intValue_int에서추출")
        func intValue_fromInt() {
            let value = AnyCodable.int(42)
            #expect(value.intValue == 42)
        }

        @Test("boolValue_bool에서추출")
        func boolValue_fromBool() {
            let value = AnyCodable.bool(false)
            #expect(value.boolValue == false)
        }
    }

    // MARK: - JSONRPCRequest 파싱

    @Suite("JSONRPCRequest - 파싱")
    struct RequestParsingTests {

        @Test("유효한요청_파싱성공")
        func validRequest_parsesSuccessfully() throws {
            let json = """
            {"jsonrpc": "2.0", "method": "session.create", "params": {"name": "test"}, "id": 1}
            """
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: json.data(using: .utf8)!)
            #expect(request.jsonrpc == "2.0")
            #expect(request.method == "session.create")
            #expect(request.id == 1)
            #expect(request.params?["name"]?.stringValue == "test")
        }

        @Test("params없는요청_파싱성공")
        func requestWithoutParams_parsesSuccessfully() throws {
            let json = """
            {"jsonrpc": "2.0", "method": "session.list", "id": 2}
            """
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: json.data(using: .utf8)!)
            #expect(request.method == "session.list")
            #expect(request.params == nil)
        }

        @Test("id없는요청_notification_파싱성공")
        func notificationRequest_parsesSuccessfully() throws {
            let json = """
            {"jsonrpc": "2.0", "method": "notify"}
            """
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: json.data(using: .utf8)!)
            #expect(request.id == nil)
        }

        @Test("복잡한params_파싱성공")
        func complexParams_parsesSuccessfully() throws {
            let json = """
            {"jsonrpc": "2.0", "method": "session.create", "params": {"name": "test", "cwd": "/tmp", "headless": true}, "id": 1}
            """
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: json.data(using: .utf8)!)
            #expect(request.params?["name"]?.stringValue == "test")
            #expect(request.params?["cwd"]?.stringValue == "/tmp")
            #expect(request.params?["headless"]?.boolValue == true)
        }
    }

    // MARK: - JSONRPCResponse 직렬화

    @Suite("JSONRPCResponse - 직렬화")
    struct ResponseSerializationTests {

        @Test("성공응답_직렬화정확")
        func successResponse_serializesCorrectly() throws {
            let response = JSONRPCResponse.success(result: .string("ok"), id: 1)
            let data = try JSONEncoder().encode(response)
            let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            #expect(dict["jsonrpc"] as? String == "2.0")
            #expect(dict["id"] as? Int == 1)
            #expect(dict["result"] as? String == "ok")
        }

        @Test("에러응답_직렬화정확")
        func errorResponse_serializesCorrectly() throws {
            let response = JSONRPCResponse.error(
                code: JSONRPCErrorCode.methodNotFound.rawValue,
                message: "Method not found",
                id: 1
            )
            let data = try JSONEncoder().encode(response)
            let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let error = dict["error"] as? [String: Any]
            #expect(error?["code"] as? Int == -32601)
            #expect(error?["message"] as? String == "Method not found")
        }

        @Test("nullResult_직렬화정확")
        func nullResult_serializesCorrectly() throws {
            let response = JSONRPCResponse.success(result: .null, id: 5)
            let data = try JSONEncoder().encode(response)
            let decoded = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
            #expect(decoded.id == 5)
        }
    }

    // MARK: - JSONRPCErrorCode

    @Suite("JSONRPCErrorCode")
    struct ErrorCodeTests {

        @Test("parseError_코드_-32700")
        func parseError_code() {
            #expect(JSONRPCErrorCode.parseError.rawValue == -32700)
        }

        @Test("invalidRequest_코드_-32600")
        func invalidRequest_code() {
            #expect(JSONRPCErrorCode.invalidRequest.rawValue == -32600)
        }

        @Test("methodNotFound_코드_-32601")
        func methodNotFound_code() {
            #expect(JSONRPCErrorCode.methodNotFound.rawValue == -32601)
        }

        @Test("invalidParams_코드_-32602")
        func invalidParams_code() {
            #expect(JSONRPCErrorCode.invalidParams.rawValue == -32602)
        }

        @Test("internalError_코드_-32603")
        func internalError_code() {
            #expect(JSONRPCErrorCode.internalError.rawValue == -32603)
        }
    }

    // MARK: - 네거티브 테스트

    @Suite("네거티브 테스트")
    struct NegativeTests {

        @Test("잘못된JSON_파싱실패")
        func invalidJSON_parsesFails() {
            let json = "not json at all"
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(JSONRPCRequest.self, from: json.data(using: .utf8)!)
            }
        }

        @Test("빈JSON객체_method필수")
        func emptyObject_methodRequired() {
            let json = """
            {}
            """
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(JSONRPCRequest.self, from: json.data(using: .utf8)!)
            }
        }

        @Test("method없는요청_파싱실패")
        func missingMethod_parsesFails() {
            let json = """
            {"jsonrpc": "2.0", "id": 1}
            """
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(JSONRPCRequest.self, from: json.data(using: .utf8)!)
            }
        }
    }
}
