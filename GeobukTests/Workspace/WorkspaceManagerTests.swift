import Testing
import Foundation
@testable import Geobuk

@Suite("WorkspaceManager - 워크스페이스 관리")
@MainActor
struct WorkspaceManagerTests {

    // MARK: - 초기화

    @Test("init_기본워크스페이스_하나생성")
    func init_defaultWorkspace_oneCreated() {
        let manager = WorkspaceManager()
        #expect(manager.workspaces.count == 1)
        #expect(manager.workspaces[0].name == "Default")
    }

    @Test("init_activeIndex_0")
    func init_activeIndex_zero() {
        let manager = WorkspaceManager()
        #expect(manager.activeIndex == 0)
    }

    @Test("init_activeWorkspace_notNil")
    func init_activeWorkspace_notNil() {
        let manager = WorkspaceManager()
        #expect(manager.activeWorkspace != nil)
        #expect(manager.activeWorkspace?.name == "Default")
    }

    @Test("init_기본cwd_홈디렉토리")
    func init_defaultCwd_homeDirectory() {
        let manager = WorkspaceManager()
        #expect(manager.workspaces[0].cwd == NSHomeDirectory())
    }

    // MARK: - 워크스페이스 생성

    @Test("createWorkspace_이름지정_추가됨")
    func createWorkspace_withName_appended() {
        let manager = WorkspaceManager()
        let ws = manager.createWorkspace(name: "Project", cwd: "/tmp/project")
        #expect(manager.workspaces.count == 2)
        #expect(ws.name == "Project")
        #expect(ws.cwd == "/tmp/project")
    }

    @Test("createWorkspace_cwdNil_홈디렉토리")
    func createWorkspace_cwdNil_usesHome() {
        let manager = WorkspaceManager()
        let ws = manager.createWorkspace(name: "NoCwd", cwd: nil)
        #expect(ws.cwd == NSHomeDirectory())
    }

    @Test("createWorkspace_생성후활성화")
    func createWorkspace_switchesToNew() {
        let manager = WorkspaceManager()
        let ws = manager.createWorkspace(name: "New", cwd: "/tmp")
        #expect(manager.activeIndex == 1)
        #expect(manager.activeWorkspace?.id == ws.id)
    }

    @Test("createWorkspace_연속생성_올바른인덱스")
    func createWorkspace_multipleCreations_correctIndices() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Second", cwd: nil)
        _ = manager.createWorkspace(name: "Third", cwd: nil)
        #expect(manager.workspaces.count == 3)
        #expect(manager.activeIndex == 2)
    }

    // MARK: - 워크스페이스 닫기

    @Test("closeWorkspace_중간워크스페이스_제거됨")
    func closeWorkspace_middle_removed() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Second", cwd: nil)
        _ = manager.createWorkspace(name: "Third", cwd: nil)
        manager.switchToWorkspace(at: 1)

        manager.closeWorkspace(at: 1)
        #expect(manager.workspaces.count == 2)
        #expect(manager.workspaces.map(\.name) == ["Default", "Third"])
    }

    @Test("closeWorkspace_마지막하나_닫히지않음")
    func closeWorkspace_lastOne_notClosed() {
        let manager = WorkspaceManager()
        manager.closeWorkspace(at: 0)
        #expect(manager.workspaces.count == 1)
    }

    @Test("closeWorkspace_활성워크스페이스_이전으로이동")
    func closeWorkspace_active_movesToPrevious() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Second", cwd: nil)
        _ = manager.createWorkspace(name: "Third", cwd: nil)
        // active = 2 (Third)

        manager.closeWorkspace(at: 2)
        #expect(manager.activeIndex == 1)
        #expect(manager.activeWorkspace?.name == "Second")
    }

    @Test("closeWorkspace_첫번째활성_0유지")
    func closeWorkspace_firstActive_staysAtZero() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Second", cwd: nil)
        manager.switchToWorkspace(at: 0)

        manager.closeWorkspace(at: 0)
        #expect(manager.activeIndex == 0)
        #expect(manager.activeWorkspace?.name == "Second")
    }

    @Test("closeWorkspace_범위밖인덱스_아무일안함")
    func closeWorkspace_outOfBounds_noChange() {
        let manager = WorkspaceManager()
        manager.closeWorkspace(at: 5)
        #expect(manager.workspaces.count == 1)
        manager.closeWorkspace(at: -1)
        #expect(manager.workspaces.count == 1)
    }

    @Test("closeWorkspace_활성보다앞_인덱스조정")
    func closeWorkspace_beforeActive_adjustsIndex() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Second", cwd: nil)
        _ = manager.createWorkspace(name: "Third", cwd: nil)
        // activeIndex = 2 (Third)

        manager.closeWorkspace(at: 0)
        // Third는 여전히 활성, 인덱스가 1로 조정되어야 함
        #expect(manager.activeIndex == 1)
        #expect(manager.activeWorkspace?.name == "Third")
    }

    // MARK: - 워크스페이스 전환

    @Test("switchToWorkspace_유효인덱스_전환됨")
    func switchToWorkspace_validIndex_switches() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Second", cwd: nil)
        manager.switchToWorkspace(at: 0)
        #expect(manager.activeIndex == 0)
        #expect(manager.activeWorkspace?.name == "Default")
    }

    @Test("switchToWorkspace_범위밖_변경없음")
    func switchToWorkspace_outOfBounds_noChange() {
        let manager = WorkspaceManager()
        manager.switchToWorkspace(at: 5)
        #expect(manager.activeIndex == 0)
        manager.switchToWorkspace(at: -1)
        #expect(manager.activeIndex == 0)
    }

    @Test("switchToWorkspace_같은인덱스_무시")
    func switchToWorkspace_sameIndex_noOp() {
        let manager = WorkspaceManager()
        manager.switchToWorkspace(at: 0)
        #expect(manager.activeIndex == 0)
    }

    // MARK: - 워크스페이스 이름 변경

    @Test("renameWorkspace_유효인덱스_이름변경")
    func renameWorkspace_validIndex_renames() {
        let manager = WorkspaceManager()
        manager.renameWorkspace(at: 0, name: "MyTerminal")
        #expect(manager.workspaces[0].name == "MyTerminal")
    }

    @Test("renameWorkspace_범위밖_변경없음")
    func renameWorkspace_outOfBounds_noChange() {
        let manager = WorkspaceManager()
        manager.renameWorkspace(at: 5, name: "Invalid")
        #expect(manager.workspaces[0].name == "Default")
    }

    @Test("renameWorkspace_빈이름_변경안됨")
    func renameWorkspace_emptyName_notChanged() {
        let manager = WorkspaceManager()
        manager.renameWorkspace(at: 0, name: "")
        #expect(manager.workspaces[0].name == "Default")
    }

    // MARK: - 워크스페이스 이동 (재정렬)

    @Test("moveWorkspace_앞에서뒤로_순서변경")
    func moveWorkspace_frontToBack_reordered() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Second", cwd: nil)
        _ = manager.createWorkspace(name: "Third", cwd: nil)
        manager.switchToWorkspace(at: 0)

        manager.moveWorkspace(from: 0, to: 2)
        #expect(manager.workspaces.map(\.name) == ["Second", "Third", "Default"])
    }

    @Test("moveWorkspace_뒤에서앞으로_순서변경")
    func moveWorkspace_backToFront_reordered() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Second", cwd: nil)
        _ = manager.createWorkspace(name: "Third", cwd: nil)
        manager.switchToWorkspace(at: 2)

        manager.moveWorkspace(from: 2, to: 0)
        #expect(manager.workspaces.map(\.name) == ["Third", "Default", "Second"])
    }

    @Test("moveWorkspace_활성워크스페이스이동_인덱스추적")
    func moveWorkspace_activeWorkspaceMoved_indexFollows() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Second", cwd: nil)
        _ = manager.createWorkspace(name: "Third", cwd: nil)
        manager.switchToWorkspace(at: 0)
        // active = 0 (Default)

        manager.moveWorkspace(from: 0, to: 2)
        // Default가 끝으로 이동, activeIndex도 따라가야 함
        #expect(manager.activeWorkspace?.name == "Default")
    }

    @Test("moveWorkspace_범위밖_변경없음")
    func moveWorkspace_outOfBounds_noChange() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Second", cwd: nil)
        let names = manager.workspaces.map(\.name)
        manager.moveWorkspace(from: -1, to: 0)
        #expect(manager.workspaces.map(\.name) == names)
        manager.moveWorkspace(from: 0, to: 5)
        #expect(manager.workspaces.map(\.name) == names)
    }

    @Test("moveWorkspace_같은위치_변경없음")
    func moveWorkspace_samePosition_noChange() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Second", cwd: nil)
        manager.moveWorkspace(from: 0, to: 0)
        #expect(manager.workspaces.map(\.name) == ["Default", "Second"])
    }

    // MARK: - Edge Cases

    @Test("workspaces_10개이상_정상동작")
    func workspaces_tenPlus_worksCorrectly() {
        let manager = WorkspaceManager()
        for i in 1...12 {
            _ = manager.createWorkspace(name: "WS\(i)", cwd: nil)
        }
        #expect(manager.workspaces.count == 13) // 1 default + 12
        #expect(manager.activeIndex == 12)
    }

    @Test("closeWorkspace_연속닫기_마지막하나남김")
    func closeWorkspace_closeAll_leavesOne() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Second", cwd: nil)
        _ = manager.createWorkspace(name: "Third", cwd: nil)

        manager.closeWorkspace(at: 2)
        manager.closeWorkspace(at: 1)
        manager.closeWorkspace(at: 0) // 마지막 하나는 닫히지 않음
        #expect(manager.workspaces.count == 1)
    }

    @Test("각워크스페이스_독립splitManager")
    func eachWorkspace_independentSplitManager() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Second", cwd: nil)

        let ws0 = manager.workspaces[0]
        let ws1 = manager.workspaces[1]

        ws0.splitManager.splitFocusedPane(direction: .horizontal)
        #expect(ws0.splitManager.paneCount == 2)
        #expect(ws1.splitManager.paneCount == 1)
    }
}
