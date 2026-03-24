import Testing
import Foundation
@testable import Geobuk

@Suite("APIMethodRouter - Team 핸들러")
@MainActor
struct TeamAPITests {

    // MARK: - 단위 테스트

    @Test("pane.registerTeammate_유효한params_등록성공")
    func registerTeammate_valid_succeeds() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "pane.registerTeammate",
            params: [
                "surfaceId": .string("mate-1"),
                "name": .string("explorer"),
                "color": .string("blue"),
                "leaderSurfaceId": .string("leader-1")
            ],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error == nil)

        let mates = TeamPaneTracker.shared.teammates(for: "leader-1")
        #expect(mates.count == 1)
        #expect(mates[0].name == "explorer")
        #expect(mates[0].color == "blue")

        TeamPaneTracker.shared.removeAllForLeader(surfaceId: "leader-1")
    }

    @Test("pane.registerTeammate_여러팀원연속등록_성공")
    func registerTeammate_multiple_succeeds() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)

        for (i, name) in ["explorer", "writer", "tester"].enumerated() {
            let request = JSONRPCRequest(
                jsonrpc: "2.0",
                method: "pane.registerTeammate",
                params: [
                    "surfaceId": .string("mate-\(i)"),
                    "name": .string(name),
                    "color": .string("blue"),
                    "leaderSurfaceId": .string("leader-1")
                ],
                id: i + 1
            )
            let response = await router.route(request)
            #expect(response.error == nil)
        }

        #expect(TeamPaneTracker.shared.teammates(for: "leader-1").count == 3)
        TeamPaneTracker.shared.removeAllForLeader(surfaceId: "leader-1")
    }

    // MARK: - 네거티브 테스트

    @Test("pane.registerTeammate_surfaceId없음_에러")
    func registerTeammate_missingSurfaceId_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "pane.registerTeammate",
            params: [
                "name": .string("explorer"),
                "color": .string("blue"),
                "leaderSurfaceId": .string("leader-1")
            ],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
        #expect(response.error?.code == JSONRPCErrorCode.invalidParams.rawValue)
    }

    @Test("pane.registerTeammate_name없음_에러")
    func registerTeammate_missingName_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "pane.registerTeammate",
            params: [
                "surfaceId": .string("mate-1"),
                "color": .string("blue"),
                "leaderSurfaceId": .string("leader-1")
            ],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    @Test("pane.registerTeammate_color없음_에러")
    func registerTeammate_missingColor_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "pane.registerTeammate",
            params: [
                "surfaceId": .string("mate-1"),
                "name": .string("explorer"),
                "leaderSurfaceId": .string("leader-1")
            ],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    @Test("pane.registerTeammate_leaderSurfaceId없음_에러")
    func registerTeammate_missingLeaderId_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "pane.registerTeammate",
            params: [
                "surfaceId": .string("mate-1"),
                "name": .string("explorer"),
                "color": .string("blue")
            ],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    @Test("pane.registerTeammate_params없음_에러")
    func registerTeammate_noParams_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "pane.registerTeammate",
            params: nil,
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
        #expect(response.error?.code == JSONRPCErrorCode.invalidParams.rawValue)
    }

    @Test("pane.registerTeammate_빈params_에러")
    func registerTeammate_emptyParams_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "pane.registerTeammate",
            params: [:],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    // MARK: - pane.split 네거티브

    @Test("pane.split_sourcePaneId없음_에러")
    func paneSplit_missingSourceId_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "pane.split",
            params: [:],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
        #expect(response.error?.code == JSONRPCErrorCode.invalidParams.rawValue)
    }

    @Test("pane.split_params없음_에러")
    func paneSplit_noParams_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "pane.split",
            params: nil,
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    // MARK: - pane.sendKeys 네거티브

    @Test("pane.sendKeys_paneId없음_에러")
    func paneSendKeys_missingPaneId_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "pane.sendKeys",
            params: ["text": .string("hello")],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    @Test("pane.sendKeys_미등록paneId_에러")
    func paneSendKeys_unknownPaneId_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "pane.sendKeys",
            params: ["paneId": .string("nonexistent"), "text": .string("hello")],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
        #expect(response.error?.code == JSONRPCErrorCode.internalError.rawValue)
    }

    // MARK: - pane.kill 네거티브

    @Test("pane.kill_paneId없음_에러")
    func paneKill_missingPaneId_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "pane.kill",
            params: [:],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    @Test("pane.kill_미등록paneId_에러")
    func paneKill_unknownPaneId_error() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "pane.kill",
            params: ["paneId": .string("nonexistent")],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }

    // MARK: - 퍼징 테스트

    @Test("fuzz_랜덤API호출_크래시없음")
    func fuzz_randomAPICalls_noCrash() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let router = APIMethodRouter(sessionManager: sessionManager)

        let methods = ["pane.registerTeammate", "pane.split", "pane.sendKeys", "pane.kill", "unknown.method"]
        let keys = ["surfaceId", "name", "color", "leaderSurfaceId", "paneId", "text", "sourcePaneId", "direction"]
        let values: [AnyCodable] = [.string("test"), .string(""), .int(42), .bool(true), .null]

        for i in 0..<100 {
            let method = methods.randomElement()!
            var params: [String: AnyCodable] = [:]
            let paramCount = Int.random(in: 0..<5)
            for _ in 0..<paramCount {
                params[keys.randomElement()!] = values.randomElement()!
            }

            let request = JSONRPCRequest(
                jsonrpc: "2.0",
                method: method,
                params: params.isEmpty ? nil : params,
                id: i
            )
            _ = await router.route(request)
        }
        // 크래시 없으면 성공

        // cleanup
        for i in 0..<5 { TeamPaneTracker.shared.removeAllForLeader(surfaceId: "leader-\(i)") }
        TeamPaneTracker.shared.removeAllForLeader(surfaceId: "test")
    }
}
