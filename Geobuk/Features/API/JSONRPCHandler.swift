import Foundation

// MARK: - AnyCodable

/// JSON의 임의 값을 표현하는 enum 기반 래퍼
enum AnyCodable: Sendable, Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([AnyCodable])
    case dictionary([String: AnyCodable])

    // MARK: - 값 추출 편의 프로퍼티

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let v) = self { return v }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    var arrayValue: [AnyCodable]? {
        if case .array(let v) = self { return v }
        return nil
    }

    var dictionaryValue: [String: AnyCodable]? {
        if case .dictionary(let v) = self { return v }
        return nil
    }
}

// MARK: - Codable

extension AnyCodable: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        if let v = try? container.decode(Bool.self) {
            self = .bool(v)
            return
        }
        if let v = try? container.decode(Int.self) {
            self = .int(v)
            return
        }
        if let v = try? container.decode(Double.self) {
            self = .double(v)
            return
        }
        if let v = try? container.decode(String.self) {
            self = .string(v)
            return
        }
        if let v = try? container.decode([AnyCodable].self) {
            self = .array(v)
            return
        }
        if let v = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(v)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        case .array(let v): try container.encode(v)
        case .dictionary(let v): try container.encode(v)
        }
    }
}

// MARK: - JSON-RPC 2.0 요청

struct JSONRPCRequest: Codable, Sendable {
    let jsonrpc: String
    let method: String
    let params: [String: AnyCodable]?
    let id: Int?
}

// MARK: - JSON-RPC 2.0 응답

struct JSONRPCResponse: Codable, Sendable {
    let jsonrpc: String
    let result: AnyCodable?
    let error: JSONRPCError?
    let id: Int?

    /// 성공 응답 생성
    static func success(result: AnyCodable, id: Int?) -> JSONRPCResponse {
        JSONRPCResponse(jsonrpc: "2.0", result: result, error: nil, id: id)
    }

    /// 에러 응답 생성
    static func error(code: Int, message: String, id: Int?) -> JSONRPCResponse {
        JSONRPCResponse(
            jsonrpc: "2.0",
            result: nil,
            error: JSONRPCError(code: code, message: message),
            id: id
        )
    }
}

// MARK: - JSON-RPC 2.0 에러

struct JSONRPCError: Codable, Sendable {
    let code: Int
    let message: String
}

// MARK: - 표준 에러 코드

enum JSONRPCErrorCode: Int, Sendable {
    case parseError = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams = -32602
    case internalError = -32603
}
