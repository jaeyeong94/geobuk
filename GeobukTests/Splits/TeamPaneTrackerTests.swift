import Testing
import Foundation
@testable import Geobuk

@Suite("TeamPaneTracker - 팀원 패널 추적")
@MainActor
struct TeamPaneTrackerTests {

    // MARK: - register

    @Test("register_팀원등록_리더에서조회가능")
    func register_teammate_retrievableByLeader() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1",
            name: "explorer",
            color: "blue",
            leaderSurfaceId: "leader-1"
        ))

        let mates = tracker.teammates(for: "leader-1")
        #expect(mates.count == 1)
        #expect(mates[0].name == "explorer")
        #expect(mates[0].color == "blue")
        #expect(mates[0].surfaceId == "mate-1")
    }

    @Test("register_여러팀원_같은리더에등록")
    func register_multipleTeammates_sameLeader() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"
        ))
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-2", name: "writer", color: "green", leaderSurfaceId: "leader-1"
        ))

        let mates = tracker.teammates(for: "leader-1")
        #expect(mates.count == 2)
        #expect(mates[0].name == "explorer")
        #expect(mates[1].name == "writer")
    }

    @Test("register_다른리더_분리추적")
    func register_differentLeaders_separateTracking() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"
        ))
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-2", name: "writer", color: "green", leaderSurfaceId: "leader-2"
        ))

        #expect(tracker.teammates(for: "leader-1").count == 1)
        #expect(tracker.teammates(for: "leader-2").count == 1)
        #expect(tracker.teammates(for: "leader-1")[0].name == "explorer")
        #expect(tracker.teammates(for: "leader-2")[0].name == "writer")
    }

    @Test("register_중복surfaceId_업데이트")
    func register_duplicateSurfaceId_updates() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"
        ))
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "explorer-v2", color: "red", leaderSurfaceId: "leader-1"
        ))

        let mates = tracker.teammates(for: "leader-1")
        #expect(mates.count == 1)
        #expect(mates[0].name == "explorer-v2")
        #expect(mates[0].color == "red")
    }

    // MARK: - remove

    @Test("remove_등록된팀원_제거성공")
    func remove_registeredTeammate_removes() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"
        ))
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-2", name: "writer", color: "green", leaderSurfaceId: "leader-1"
        ))

        tracker.remove(surfaceId: "mate-1")

        let mates = tracker.teammates(for: "leader-1")
        #expect(mates.count == 1)
        #expect(mates[0].name == "writer")
    }

    @Test("remove_마지막팀원_빈배열")
    func remove_lastTeammate_emptyArray() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"
        ))

        tracker.remove(surfaceId: "mate-1")

        #expect(tracker.teammates(for: "leader-1").isEmpty)
    }

    @Test("remove_미등록surfaceId_에러없음")
    func remove_unregisteredSurfaceId_noError() {
        let tracker = TeamPaneTracker()
        tracker.remove(surfaceId: "nonexistent")
        // should not crash
    }

    // MARK: - teammates(for:)

    @Test("teammates_미등록리더_빈배열")
    func teammates_unregisteredLeader_emptyArray() {
        let tracker = TeamPaneTracker()
        #expect(tracker.teammates(for: "nonexistent").isEmpty)
    }

    // MARK: - leaderSurfaceId(for:)

    @Test("leaderSurfaceId_팀원으로조회_리더반환")
    func leaderSurfaceId_fromTeammate_returnsLeader() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"
        ))

        #expect(tracker.leaderSurfaceId(for: "mate-1") == "leader-1")
    }

    @Test("leaderSurfaceId_미등록surfaceId_nil반환")
    func leaderSurfaceId_unregistered_returnsNil() {
        let tracker = TeamPaneTracker()
        #expect(tracker.leaderSurfaceId(for: "nonexistent") == nil)
    }

    // MARK: - isTeammate

    @Test("isTeammate_등록된팀원_true")
    func isTeammate_registered_returnsTrue() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"
        ))

        #expect(tracker.isTeammate(surfaceId: "mate-1"))
    }

    @Test("isTeammate_리더_false")
    func isTeammate_leader_returnsFalse() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"
        ))

        #expect(!tracker.isTeammate(surfaceId: "leader-1"))
    }

    @Test("isTeammate_미등록_false")
    func isTeammate_unregistered_returnsFalse() {
        let tracker = TeamPaneTracker()
        #expect(!tracker.isTeammate(surfaceId: "nonexistent"))
    }

    // MARK: - isLeader

    @Test("isLeader_팀원이있는리더_true")
    func isLeader_withTeammates_returnsTrue() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"
        ))

        #expect(tracker.isLeader(surfaceId: "leader-1"))
    }

    @Test("isLeader_팀원없는리더_false")
    func isLeader_noTeammates_returnsFalse() {
        let tracker = TeamPaneTracker()
        #expect(!tracker.isLeader(surfaceId: "leader-1"))
    }

    // MARK: - removeAllForLeader

    @Test("removeAllForLeader_전체팀원제거")
    func removeAllForLeader_removesAll() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"
        ))
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-2", name: "writer", color: "green", leaderSurfaceId: "leader-1"
        ))

        tracker.removeAllForLeader(surfaceId: "leader-1")

        #expect(tracker.teammates(for: "leader-1").isEmpty)
        #expect(!tracker.isTeammate(surfaceId: "mate-1"))
        #expect(!tracker.isTeammate(surfaceId: "mate-2"))
    }

    // MARK: - 네거티브 테스트

    @Test("register_빈name_저장됨")
    func register_emptyName_stores() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "", color: "blue", leaderSurfaceId: "leader-1"
        ))

        #expect(tracker.teammates(for: "leader-1").count == 1)
        #expect(tracker.teammates(for: "leader-1")[0].name == "")
    }

    @Test("register_빈color_저장됨")
    func register_emptyColor_stores() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "explorer", color: "", leaderSurfaceId: "leader-1"
        ))

        #expect(tracker.teammates(for: "leader-1")[0].color == "")
    }
}
