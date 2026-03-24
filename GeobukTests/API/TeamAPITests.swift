import Testing
import Foundation
@testable import Geobuk

@Suite("APIMethodRouter - Team 핸들러")
@MainActor
struct TeamAPITests {

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

        // cleanup
        TeamPaneTracker.shared.removeAllForLeader(surfaceId: "leader-1")
    }

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
            id: 2
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
            id: 3
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }
}
