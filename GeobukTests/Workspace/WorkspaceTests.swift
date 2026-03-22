import Testing
import Foundation
@testable import Geobuk

@Suite("Workspace - 워크스페이스 모델")
@MainActor
struct WorkspaceTests {

    // MARK: - 초기화

    @Test("init_이름과cwd_정상생성")
    func init_nameAndCwd_createsWorkspace() {
        let workspace = Workspace(name: "Test", cwd: "/Users/test")
        #expect(workspace.name == "Test")
        #expect(workspace.cwd == "/Users/test")
    }

    @Test("init_고유ID생성")
    func init_uniqueId_generated() {
        let ws1 = Workspace(name: "A", cwd: "/tmp")
        let ws2 = Workspace(name: "B", cwd: "/tmp")
        #expect(ws1.id != ws2.id)
    }

    @Test("init_splitManager생성됨")
    func init_splitManager_created() {
        let workspace = Workspace(name: "Test", cwd: "/tmp")
        #expect(workspace.splitManager.paneCount == 1)
    }

    @Test("init_createdAt_현재시각근처")
    func init_createdAt_nearNow() {
        let before = Date()
        let workspace = Workspace(name: "Test", cwd: "/tmp")
        let after = Date()
        #expect(workspace.createdAt >= before)
        #expect(workspace.createdAt <= after)
    }

    // MARK: - 속성 변경

    @Test("name_변경가능")
    func name_canBeChanged() {
        let workspace = Workspace(name: "Original", cwd: "/tmp")
        workspace.name = "Renamed"
        #expect(workspace.name == "Renamed")
    }

    @Test("cwd_변경가능")
    func cwd_canBeChanged() {
        let workspace = Workspace(name: "Test", cwd: "/tmp")
        workspace.cwd = "/Users/new"
        #expect(workspace.cwd == "/Users/new")
    }

}
