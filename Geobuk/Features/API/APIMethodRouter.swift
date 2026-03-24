import Foundation

/// API 메서드 라우팅
/// JSON-RPC 2.0 요청을 적절한 SessionManager 메서드로 라우팅
@MainActor
final class APIMethodRouter {
    private let sessionManager: SessionManager
    private let shellStateManager: ShellStateManager?

    init(sessionManager: SessionManager, shellStateManager: ShellStateManager? = nil) {
        self.sessionManager = sessionManager
        self.shellStateManager = shellStateManager
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
        case "shell.reportTty":
            return handleShellReportTty(request)
        case "shell.reportState":
            return handleShellReportState(request)
        case "pane.split":
            return handlePaneSplit(request)
        case "pane.sendKeys":
            return handlePaneSendKeys(request)
        case "pane.kill":
            return handlePaneKill(request)
        case "pane.registerTeammate":
            return handlePaneRegisterTeammate(request)
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

    /// sendKeys 최대 페이로드 크기 (64KB)
    private static let maxSendKeysSize = 65_536

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

        guard text.utf8.count <= Self.maxSendKeysSize else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Text payload exceeds maximum size of \(Self.maxSendKeysSize) bytes",
                id: request.id
            )
        }

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

    // MARK: - Shell Integration 핸들러

    private func handleShellReportTty(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let shellStateManager else {
            return .error(
                code: JSONRPCErrorCode.methodNotFound.rawValue,
                message: "Shell state manager not available",
                id: request.id
            )
        }

        guard let params = request.params,
              let surfaceId = params["surfaceId"]?.stringValue,
              let tty = params["tty"]?.stringValue else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Missing required parameters: surfaceId, tty",
                id: request.id
            )
        }

        guard ShellStateManager.isValidTTYName(tty) else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Invalid TTY name: \(tty)",
                id: request.id
            )
        }

        shellStateManager.reportTty(surfaceId: surfaceId, tty: tty)
        return .success(result: .null, id: request.id)
    }

    private func handleShellReportState(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let shellStateManager else {
            return .error(
                code: JSONRPCErrorCode.methodNotFound.rawValue,
                message: "Shell state manager not available",
                id: request.id
            )
        }

        guard let params = request.params,
              let surfaceId = params["surfaceId"]?.stringValue,
              let state = params["state"]?.stringValue else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Missing required parameters: surfaceId, state",
                id: request.id
            )
        }

        let command = params["command"]?.stringValue
        shellStateManager.reportState(surfaceId: surfaceId, state: state, command: command)
        return .success(result: .null, id: request.id)
    }

    // MARK: - Pane 핸들러 (Claude Code Team 통합)

    private func handlePaneSplit(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let params = request.params,
              let sourcePaneId = params["sourcePaneId"]?.stringValue else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Missing required parameter: sourcePaneId",
                id: request.id
            )
        }

        let direction = params["direction"]?.stringValue ?? "horizontal"

        guard let newSurfaceId = PaneController.shared.splitPane(sourcePaneId: sourcePaneId, direction: direction) else {
            return .error(
                code: JSONRPCErrorCode.internalError.rawValue,
                message: "Failed to split pane",
                id: request.id
            )
        }

        return .success(result: .string(newSurfaceId), id: request.id)
    }

    private func handlePaneSendKeys(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let params = request.params,
              let paneId = params["paneId"]?.stringValue else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Missing required parameter: paneId",
                id: request.id
            )
        }

        let text = params["text"]?.stringValue ?? ""

        guard text.utf8.count <= Self.maxSendKeysSize else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Text payload exceeds maximum size",
                id: request.id
            )
        }

        let success = PaneController.shared.sendKeys(surfaceId: paneId, text: text)
        if success {
            return .success(result: .null, id: request.id)
        } else {
            return .error(
                code: JSONRPCErrorCode.internalError.rawValue,
                message: "Pane not found: \(paneId)",
                id: request.id
            )
        }
    }

    private func handlePaneKill(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let params = request.params,
              let paneId = params["paneId"]?.stringValue else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Missing required parameter: paneId",
                id: request.id
            )
        }

        let success = PaneController.shared.killPane(surfaceId: paneId)
        if success {
            return .success(result: .null, id: request.id)
        } else {
            return .error(
                code: JSONRPCErrorCode.internalError.rawValue,
                message: "Pane not found: \(paneId)",
                id: request.id
            )
        }
    }

    private func handlePaneRegisterTeammate(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let params = request.params,
              let surfaceId = params["surfaceId"]?.stringValue,
              let name = params["name"]?.stringValue,
              let color = params["color"]?.stringValue,
              let leaderSurfaceId = params["leaderSurfaceId"]?.stringValue else {
            return .error(
                code: JSONRPCErrorCode.invalidParams.rawValue,
                message: "Missing required parameters: surfaceId, name, color, leaderSurfaceId",
                id: request.id
            )
        }

        TeamPaneTracker.shared.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: surfaceId,
            name: name,
            color: color,
            leaderSurfaceId: leaderSurfaceId
        ))

        return .success(result: .null, id: request.id)
    }
}
