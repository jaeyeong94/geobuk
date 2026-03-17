import Testing
import Foundation
@testable import Geobuk

@Suite("APIMethodRouter - API 메서드 라우팅")
struct APIMethodRouterTests {

    // MARK: - session.list

    @Test("session.list_빈목록_빈배열반환")
    @MainActor
    func sessionList_empty_returnsEmptyArray() async {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(jsonrpc: "2.0", method: "session.list", params: nil, id: 1)
        let response = await router.route(request)
        #expect(response.error == nil)
        #expect(response.id == 1)
    }

    @Test("session.list_세션있으면_배열반환")
    @MainActor
    func sessionList_withSessions_returnsArray() async throws {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        _ = try manager.createSession(name: "list-test", cwd: nil, headless: true)
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(jsonrpc: "2.0", method: "session.list", params: nil, id: 1)
        let response = await router.route(request)
        #expect(response.error == nil)
        manager.destroyAllSessions()
    }

    // MARK: - session.create

    @Test("session.create_유효한params_성공")
    @MainActor
    func sessionCreate_validParams_succeeds() async {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.create",
            params: ["name": .string("new-session"), "headless": .bool(true)],
            id: 2
        )
        let response = await router.route(request)
        #expect(response.error == nil)
        #expect(manager.sessionExists(name: "new-session"))
        manager.destroyAllSessions()
    }

    @Test("session.create_name없음_에러")
    @MainActor
    func sessionCreate_missingName_error() async {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.create",
            params: [:],
            id: 3
        )
        let response = await router.route(request)
        #expect(response.error != nil)
        #expect(response.error?.code == JSONRPCErrorCode.invalidParams.rawValue)
    }

    @Test("session.create_중복이름_에러")
    @MainActor
    func sessionCreate_duplicateName_error() async throws {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        _ = try manager.createSession(name: "dup-api", cwd: nil, headless: true)
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.create",
            params: ["name": .string("dup-api")],
            id: 4
        )
        let response = await router.route(request)
        #expect(response.error != nil)
        manager.destroyAllSessions()
    }

    // MARK: - session.destroy

    @Test("session.destroy_존재하는세션_성공")
    @MainActor
    func sessionDestroy_existing_succeeds() async throws {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        _ = try manager.createSession(name: "destroy-api", cwd: nil, headless: true)
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.destroy",
            params: ["name": .string("destroy-api")],
            id: 5
        )
        let response = await router.route(request)
        #expect(response.error == nil)
        #expect(!manager.sessionExists(name: "destroy-api"))
    }

    @Test("session.destroy_존재하지않는세션_에러")
    @MainActor
    func sessionDestroy_nonExisting_error() async {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.destroy",
            params: ["name": .string("ghost")],
            id: 6
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    // MARK: - session.sendKeys

    @Test("session.sendKeys_유효_성공")
    @MainActor
    func sessionSendKeys_valid_succeeds() async throws {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        _ = try manager.createSession(name: "keys-api", cwd: nil, headless: true)
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.sendKeys",
            params: ["name": .string("keys-api"), "text": .string("hello")],
            id: 7
        )
        let response = await router.route(request)
        #expect(response.error == nil)
        manager.destroyAllSessions()
    }

    @Test("session.sendKeys_name없음_에러")
    @MainActor
    func sessionSendKeys_missingName_error() async {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.sendKeys",
            params: ["text": .string("hello")],
            id: 8
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    // MARK: - session.sendSpecialKey

    @Test("session.sendSpecialKey_enter_성공")
    @MainActor
    func sessionSendSpecialKey_enter_succeeds() async throws {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        _ = try manager.createSession(name: "special-api", cwd: nil, headless: true)
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.sendSpecialKey",
            params: ["name": .string("special-api"), "key": .string("enter")],
            id: 9
        )
        let response = await router.route(request)
        #expect(response.error == nil)
        manager.destroyAllSessions()
    }

    // MARK: - session.captureOutput

    @Test("session.captureOutput_유효_성공")
    @MainActor
    func sessionCaptureOutput_valid_succeeds() async throws {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        _ = try manager.createSession(name: "capture-api", cwd: nil, headless: true)
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.captureOutput",
            params: ["name": .string("capture-api"), "lines": .int(10)],
            id: 10
        )
        let response = await router.route(request)
        #expect(response.error == nil)
        manager.destroyAllSessions()
    }

    // MARK: - session.exists

    @Test("session.exists_존재하는세션_true")
    @MainActor
    func sessionExists_existing_returnsTrue() async throws {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        _ = try manager.createSession(name: "exists-api", cwd: nil, headless: true)
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.exists",
            params: ["name": .string("exists-api")],
            id: 11
        )
        let response = await router.route(request)
        #expect(response.error == nil)
        #expect(response.result == .bool(true))
        manager.destroyAllSessions()
    }

    @Test("session.exists_존재하지않는세션_false")
    @MainActor
    func sessionExists_nonExisting_returnsFalse() async {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.exists",
            params: ["name": .string("nope")],
            id: 12
        )
        let response = await router.route(request)
        #expect(response.error == nil)
        #expect(response.result == .bool(false))
    }

    // MARK: - 알 수 없는 메서드

    @Test("unknownMethod_methodNotFound에러")
    @MainActor
    func unknownMethod_returnsMethodNotFound() async {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "unknown.method",
            params: nil,
            id: 99
        )
        let response = await router.route(request)
        #expect(response.error?.code == JSONRPCErrorCode.methodNotFound.rawValue)
    }

    // MARK: - params가 nil인 경우

    @Test("session.create_params없음_에러")
    @MainActor
    func sessionCreate_noParams_error() async {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.create",
            params: nil,
            id: 100
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }
}
