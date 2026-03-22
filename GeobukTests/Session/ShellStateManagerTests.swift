import Testing
import Foundation
@testable import Geobuk

@Suite("ShellStateManager - 셸 상태 관리")
struct ShellStateManagerTests {

    // MARK: - reportTty

    @Test("reportTty_유효한surfaceId와tty_저장성공")
    @MainActor
    func reportTty_valid_stores() {
        let manager = ShellStateManager()
        manager.reportTty(surfaceId: "abc-123", tty: "/dev/ttys001")
        #expect(manager.ttyNames["abc-123"] == "/dev/ttys001")
    }

    @Test("reportTty_같은surfaceId로재호출_업데이트")
    @MainActor
    func reportTty_sameId_updates() {
        let manager = ShellStateManager()
        manager.reportTty(surfaceId: "abc-123", tty: "/dev/ttys001")
        manager.reportTty(surfaceId: "abc-123", tty: "/dev/ttys002")
        #expect(manager.ttyNames["abc-123"] == "/dev/ttys002")
    }

    @Test("reportTty_여러surfaceId_각각저장")
    @MainActor
    func reportTty_multipleIds_storesAll() {
        let manager = ShellStateManager()
        manager.reportTty(surfaceId: "id-1", tty: "/dev/ttys001")
        manager.reportTty(surfaceId: "id-2", tty: "/dev/ttys002")
        #expect(manager.ttyNames.count == 2)
        #expect(manager.ttyNames["id-1"] == "/dev/ttys001")
        #expect(manager.ttyNames["id-2"] == "/dev/ttys002")
    }

    // MARK: - reportState

    @Test("reportState_prompt상태_저장성공")
    @MainActor
    func reportState_prompt_stores() {
        let manager = ShellStateManager()
        manager.reportState(surfaceId: "abc-123", state: "prompt", command: nil)
        let shellState = manager.shellStates["abc-123"]
        #expect(shellState != nil)
        #expect(shellState?.state == "prompt")
        #expect(shellState?.command == nil)
    }

    @Test("reportState_running상태와command_저장성공")
    @MainActor
    func reportState_running_storesCommand() {
        let manager = ShellStateManager()
        manager.reportState(surfaceId: "abc-123", state: "running", command: "git status")
        let shellState = manager.shellStates["abc-123"]
        #expect(shellState?.state == "running")
        #expect(shellState?.command == "git status")
    }

    @Test("reportState_상태전환_최신상태유지")
    @MainActor
    func reportState_transition_updatesToLatest() {
        let manager = ShellStateManager()
        manager.reportState(surfaceId: "abc-123", state: "running", command: "ls")
        manager.reportState(surfaceId: "abc-123", state: "prompt", command: nil)
        let shellState = manager.shellStates["abc-123"]
        #expect(shellState?.state == "prompt")
        #expect(shellState?.command == nil)
    }

    @Test("reportState_updatedAt_현재시각에가까움")
    @MainActor
    func reportState_updatedAt_isRecent() {
        let manager = ShellStateManager()
        let before = Date()
        manager.reportState(surfaceId: "abc-123", state: "prompt", command: nil)
        let after = Date()
        let shellState = manager.shellStates["abc-123"]!
        #expect(shellState.updatedAt >= before)
        #expect(shellState.updatedAt <= after)
    }

    // MARK: - Negative Tests

    @Test("reportTty_빈surfaceId_저장됨")
    @MainActor
    func reportTty_emptyId_stillStores() {
        let manager = ShellStateManager()
        manager.reportTty(surfaceId: "", tty: "/dev/ttys001")
        #expect(manager.ttyNames[""] == "/dev/ttys001")
    }

    @Test("reportTty_빈tty_검증실패로거부")
    @MainActor
    func reportTty_emptyTty_rejected() {
        let manager = ShellStateManager()
        manager.reportTty(surfaceId: "abc-123", tty: "")
        #expect(manager.ttyNames["abc-123"] == nil)
    }

    @Test("reportState_알수없는state값_그대로저장")
    @MainActor
    func reportState_unknownState_stillStores() {
        let manager = ShellStateManager()
        manager.reportState(surfaceId: "abc-123", state: "unknown", command: nil)
        #expect(manager.shellStates["abc-123"]?.state == "unknown")
    }

    @Test("존재하지않는surfaceId_조회_nil반환")
    @MainActor
    func lookup_nonExistentId_returnsNil() {
        let manager = ShellStateManager()
        #expect(manager.ttyNames["nonexistent"] == nil)
        #expect(manager.shellStates["nonexistent"] == nil)
    }

    // MARK: - displayProcessName

    @Test("displayProcessName_running상태_command반환")
    @MainActor
    func displayProcessName_running_returnsCommand() {
        let manager = ShellStateManager()
        manager.reportState(surfaceId: "abc-123", state: "running", command: "vim main.swift")
        #expect(manager.displayProcessName(for: "abc-123") == "vim main.swift")
    }

    @Test("displayProcessName_prompt상태_nil반환")
    @MainActor
    func displayProcessName_prompt_returnsNil() {
        let manager = ShellStateManager()
        manager.reportState(surfaceId: "abc-123", state: "prompt", command: nil)
        #expect(manager.displayProcessName(for: "abc-123") == nil)
    }

    @Test("displayProcessName_미등록surfaceId_nil반환")
    @MainActor
    func displayProcessName_unknownId_returnsNil() {
        let manager = ShellStateManager()
        #expect(manager.displayProcessName(for: "unknown") == nil)
    }

    // MARK: - removeSurface

    @Test("removeSurface_등록된surface_제거성공")
    @MainActor
    func removeSurface_existing_removes() {
        let manager = ShellStateManager()
        manager.reportTty(surfaceId: "abc-123", tty: "/dev/ttys001")
        manager.reportState(surfaceId: "abc-123", state: "prompt", command: nil)
        manager.removeSurface(surfaceId: "abc-123")
        #expect(manager.ttyNames["abc-123"] == nil)
        #expect(manager.shellStates["abc-123"] == nil)
    }

    @Test("removeSurface_미등록surface_에러없음")
    @MainActor
    func removeSurface_nonExisting_noError() {
        let manager = ShellStateManager()
        manager.removeSurface(surfaceId: "nonexistent")
        // Should not crash
    }
}

// MARK: - APIMethodRouter shell.* 핸들러 테스트

@Suite("APIMethodRouter - Shell Integration 라우팅")
struct APIMethodRouterShellTests {

    @Test("shell.reportTty_유효한params_성공")
    @MainActor
    func shellReportTty_valid_succeeds() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let shellStateManager = ShellStateManager()
        let router = APIMethodRouter(sessionManager: sessionManager, shellStateManager: shellStateManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "shell.reportTty",
            params: ["surfaceId": .string("abc-123"), "tty": .string("/dev/ttys001")],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error == nil)
        #expect(shellStateManager.ttyNames["abc-123"] == "/dev/ttys001")
    }

    @Test("shell.reportTty_surfaceId없음_에러")
    @MainActor
    func shellReportTty_missingSurfaceId_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let shellStateManager = ShellStateManager()
        let router = APIMethodRouter(sessionManager: sessionManager, shellStateManager: shellStateManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "shell.reportTty",
            params: ["tty": .string("/dev/ttys001")],
            id: 2
        )
        let response = await router.route(request)
        #expect(response.error != nil)
        #expect(response.error?.code == JSONRPCErrorCode.invalidParams.rawValue)
    }

    @Test("shell.reportTty_tty없음_에러")
    @MainActor
    func shellReportTty_missingTty_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let shellStateManager = ShellStateManager()
        let router = APIMethodRouter(sessionManager: sessionManager, shellStateManager: shellStateManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "shell.reportTty",
            params: ["surfaceId": .string("abc-123")],
            id: 3
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    @Test("shell.reportState_prompt상태_성공")
    @MainActor
    func shellReportState_prompt_succeeds() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let shellStateManager = ShellStateManager()
        let router = APIMethodRouter(sessionManager: sessionManager, shellStateManager: shellStateManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "shell.reportState",
            params: ["surfaceId": .string("abc-123"), "state": .string("prompt")],
            id: 4
        )
        let response = await router.route(request)
        #expect(response.error == nil)
        #expect(shellStateManager.shellStates["abc-123"]?.state == "prompt")
    }

    @Test("shell.reportState_running상태와command_성공")
    @MainActor
    func shellReportState_running_succeeds() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let shellStateManager = ShellStateManager()
        let router = APIMethodRouter(sessionManager: sessionManager, shellStateManager: shellStateManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "shell.reportState",
            params: [
                "surfaceId": .string("abc-123"),
                "state": .string("running"),
                "command": .string("git status")
            ],
            id: 5
        )
        let response = await router.route(request)
        #expect(response.error == nil)
        #expect(shellStateManager.shellStates["abc-123"]?.state == "running")
        #expect(shellStateManager.shellStates["abc-123"]?.command == "git status")
    }

    @Test("shell.reportState_surfaceId없음_에러")
    @MainActor
    func shellReportState_missingSurfaceId_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let shellStateManager = ShellStateManager()
        let router = APIMethodRouter(sessionManager: sessionManager, shellStateManager: shellStateManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "shell.reportState",
            params: ["state": .string("prompt")],
            id: 6
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    @Test("shell.reportState_state없음_에러")
    @MainActor
    func shellReportState_missingState_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let shellStateManager = ShellStateManager()
        let router = APIMethodRouter(sessionManager: sessionManager, shellStateManager: shellStateManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "shell.reportState",
            params: ["surfaceId": .string("abc-123")],
            id: 7
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    @Test("shell.reportState_params없음_에러")
    @MainActor
    func shellReportState_noParams_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let shellStateManager = ShellStateManager()
        let router = APIMethodRouter(sessionManager: sessionManager, shellStateManager: shellStateManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "shell.reportState",
            params: nil,
            id: 8
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    // MARK: - 기존 메서드 하위호환

    @Test("기존APIMethodRouter_shellStateManager없이_기존동작유지")
    @MainActor
    func existingRouter_withoutShellState_worksAsIs() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.list",
            params: nil,
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error == nil)
    }

    @Test("shell.reportTty_shellStateManager없음_methodNotFound")
    @MainActor
    func shellReportTty_noShellStateManager_methodNotFound() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "shell.reportTty",
            params: ["surfaceId": .string("abc-123"), "tty": .string("/dev/ttys001")],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
        #expect(response.error?.code == JSONRPCErrorCode.methodNotFound.rawValue)
    }
}
