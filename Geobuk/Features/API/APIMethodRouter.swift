import Foundation

/// API 메서드 라우팅
/// JSON-RPC 2.0 요청을 적절한 SessionManager 메서드로 라우팅
@MainActor
final class APIMethodRouter {
    private let sessionManager: SessionManager

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
    }

    /// 요청을 라우팅하여 응답 생성
    func route(_ request: JSONRPCRequest) async -> JSONRPCResponse {
        switch request.method {
        case "session.list":
            return handleSessionList(request)
        case "session.create":
            return handleSessionCreate(request)
        case "session.destroy":
            return handleSessionDestroy(request)
        case "session.sendKeys":
            return handleSessionSendKeys(request)
        case "session.sendSpecialKey":
            return handleSessionSendSpecialKey(request)
        case "session.captureOutput":
            return handleSessionCaptureOutput(request)
        case "session.exists":
            return handleSessionExists(request)
        default:
            return .error(
                code: JSONRPCErrorCode.methodNotFound.rawValue,
                message: "Method not found: \(request.method)",
                id: request.id
            )
        }
    }

    // MARK: - 핸들러

    private func handleSessionList(_ request: JSONRPCRequest) -> JSONRPCResponse {
        let sessions = sessionManager.listSessions()
        let result: [AnyCodable] = sessions.map { session in
            .dictionary([
                "name": .string(session.name),
                "headless": .bool(session.isHeadless),
                "pid": .int(Int(session.pid))
            ])
        }
        return .success(result: .array(result), id: request.id)
    }

    private func handleSessionCreate(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let params = request.params,
              let name = params["name"]?.stringValue else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Missing required parameter: name",
                id: request.id
            )
        }

        let cwd = params["cwd"]?.stringValue
        let headless = params["headless"]?.boolValue ?? true

        do {
            let sessionName = try sessionManager.createSession(name: name, cwd: cwd, headless: headless)
            return .success(result: .string(sessionName), id: request.id)
        } catch {
            return .error(
                code: JSONRPCErrorCode.internalError.rawValue,
                message: error.localizedDescription,
                id: request.id
            )
        }
    }

    private func handleSessionDestroy(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let params = request.params,
              let name = params["name"]?.stringValue else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Missing required parameter: name",
                id: request.id
            )
        }

        do {
            try sessionManager.destroySession(name: name)
            return .success(result: .null, id: request.id)
        } catch {
            return .error(
                code: JSONRPCErrorCode.internalError.rawValue,
                message: error.localizedDescription,
                id: request.id
            )
        }
    }

    private func handleSessionSendKeys(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let params = request.params,
              let name = params["name"]?.stringValue else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Missing required parameter: name",
                id: request.id
            )
        }

        let text = params["text"]?.stringValue ?? ""

        do {
            try sessionManager.sendKeys(sessionName: name, text: text)
            return .success(result: .null, id: request.id)
        } catch {
            return .error(
                code: JSONRPCErrorCode.internalError.rawValue,
                message: error.localizedDescription,
                id: request.id
            )
        }
    }

    private func handleSessionSendSpecialKey(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let params = request.params,
              let name = params["name"]?.stringValue,
              let key = params["key"]?.stringValue else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Missing required parameters: name, key",
                id: request.id
            )
        }

        do {
            try sessionManager.sendSpecialKey(sessionName: name, key: key)
            return .success(result: .null, id: request.id)
        } catch {
            return .error(
                code: JSONRPCErrorCode.internalError.rawValue,
                message: error.localizedDescription,
                id: request.id
            )
        }
    }

    private func handleSessionCaptureOutput(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let params = request.params,
              let name = params["name"]?.stringValue else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Missing required parameter: name",
                id: request.id
            )
        }

        let lines = params["lines"]?.intValue ?? 100

        do {
            let output = try sessionManager.captureOutput(sessionName: name, lines: lines)
            return .success(result: .string(output), id: request.id)
        } catch {
            return .error(
                code: JSONRPCErrorCode.internalError.rawValue,
                message: error.localizedDescription,
                id: request.id
            )
        }
    }

    private func handleSessionExists(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let params = request.params,
              let name = params["name"]?.stringValue else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Missing required parameter: name",
                id: request.id
            )
        }

        let exists = sessionManager.sessionExists(name: name)
        return .success(result: .bool(exists), id: request.id)
    }
}
