import Testing
import Foundation
@testable import Geobuk

@Suite("TeamPaneTracker - 팀원 패널 추적")
@MainActor
struct TeamPaneTrackerTests {

    // MARK: - 단위 테스트 (Unit Tests)

    // MARK: register

    @Test("register_팀원등록_리더에서조회가능")
    func register_teammate_retrievableByLeader() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: TeamPaneTracker.Teammate(
            surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"
        ))

        let mates = tracker.teammates(for: "leader-1")
        #expect(mates.count == 1)
        #expect(mates[0].name == "explorer")
        #expect(mates[0].color == "blue")
        #expect(mates[0].surfaceId == "mate-1")
        #expect(mates[0].leaderSurfaceId == "leader-1")
    }

    @Test("register_여러팀원_같은리더에등록")
    func register_multipleTeammates_sameLeader() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))
        tracker.register(teammate: .init(surfaceId: "mate-2", name: "writer", color: "green", leaderSurfaceId: "leader-1"))

        let mates = tracker.teammates(for: "leader-1")
        #expect(mates.count == 2)
        #expect(mates[0].name == "explorer")
        #expect(mates[1].name == "writer")
    }

    @Test("register_다른리더_분리추적")
    func register_differentLeaders_separateTracking() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))
        tracker.register(teammate: .init(surfaceId: "mate-2", name: "writer", color: "green", leaderSurfaceId: "leader-2"))

        #expect(tracker.teammates(for: "leader-1").count == 1)
        #expect(tracker.teammates(for: "leader-2").count == 1)
        #expect(tracker.teammates(for: "leader-1")[0].name == "explorer")
        #expect(tracker.teammates(for: "leader-2")[0].name == "writer")
    }

    @Test("register_중복surfaceId_업데이트")
    func register_duplicateSurfaceId_updates() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer-v2", color: "red", leaderSurfaceId: "leader-1"))

        let mates = tracker.teammates(for: "leader-1")
        #expect(mates.count == 1)
        #expect(mates[0].name == "explorer-v2")
        #expect(mates[0].color == "red")
    }

    @Test("register_등록순서유지")
    func register_preservesOrder() {
        let tracker = TeamPaneTracker()
        let names = ["alpha", "beta", "gamma", "delta"]
        for (i, name) in names.enumerated() {
            tracker.register(teammate: .init(surfaceId: "m-\(i)", name: name, color: "blue", leaderSurfaceId: "leader-1"))
        }

        let mates = tracker.teammates(for: "leader-1")
        #expect(mates.map(\.name) == names)
    }

    // MARK: remove

    @Test("remove_등록된팀원_제거성공")
    func remove_registeredTeammate_removes() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))
        tracker.register(teammate: .init(surfaceId: "mate-2", name: "writer", color: "green", leaderSurfaceId: "leader-1"))

        tracker.remove(surfaceId: "mate-1")

        let mates = tracker.teammates(for: "leader-1")
        #expect(mates.count == 1)
        #expect(mates[0].name == "writer")
    }

    @Test("remove_마지막팀원_빈배열_isLeader_false")
    func remove_lastTeammate_emptyAndNotLeader() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))

        tracker.remove(surfaceId: "mate-1")

        #expect(tracker.teammates(for: "leader-1").isEmpty)
        #expect(!tracker.isLeader(surfaceId: "leader-1"))
        #expect(!tracker.isTeammate(surfaceId: "mate-1"))
    }

    @Test("remove_역방향조회정리확인")
    func remove_cleansUpReverseMapping() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))

        tracker.remove(surfaceId: "mate-1")

        #expect(tracker.leaderSurfaceId(for: "mate-1") == nil)
    }

    // MARK: removeAllForLeader

    @Test("removeAllForLeader_전체팀원제거")
    func removeAllForLeader_removesAll() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))
        tracker.register(teammate: .init(surfaceId: "mate-2", name: "writer", color: "green", leaderSurfaceId: "leader-1"))

        tracker.removeAllForLeader(surfaceId: "leader-1")

        #expect(tracker.teammates(for: "leader-1").isEmpty)
        #expect(!tracker.isTeammate(surfaceId: "mate-1"))
        #expect(!tracker.isTeammate(surfaceId: "mate-2"))
        #expect(!tracker.isLeader(surfaceId: "leader-1"))
    }

    @Test("removeAllForLeader_다른리더팀원유지")
    func removeAllForLeader_preservesOtherLeader() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "a", color: "blue", leaderSurfaceId: "leader-1"))
        tracker.register(teammate: .init(surfaceId: "mate-2", name: "b", color: "green", leaderSurfaceId: "leader-2"))

        tracker.removeAllForLeader(surfaceId: "leader-1")

        #expect(tracker.teammates(for: "leader-1").isEmpty)
        #expect(tracker.teammates(for: "leader-2").count == 1)
        #expect(tracker.isTeammate(surfaceId: "mate-2"))
    }

    // MARK: teammates / leaderSurfaceId / isTeammate / isLeader

    @Test("teammates_미등록리더_빈배열")
    func teammates_unregisteredLeader_emptyArray() {
        let tracker = TeamPaneTracker()
        #expect(tracker.teammates(for: "nonexistent").isEmpty)
    }

    @Test("leaderSurfaceId_팀원으로조회_리더반환")
    func leaderSurfaceId_fromTeammate_returnsLeader() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))
        #expect(tracker.leaderSurfaceId(for: "mate-1") == "leader-1")
    }

    @Test("leaderSurfaceId_미등록_nil")
    func leaderSurfaceId_unregistered_returnsNil() {
        let tracker = TeamPaneTracker()
        #expect(tracker.leaderSurfaceId(for: "nonexistent") == nil)
    }

    @Test("isTeammate_등록된팀원_true")
    func isTeammate_registered_true() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))
        #expect(tracker.isTeammate(surfaceId: "mate-1"))
    }

    @Test("isTeammate_리더surfaceId_false")
    func isTeammate_leaderSurfaceId_false() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))
        #expect(!tracker.isTeammate(surfaceId: "leader-1"))
    }

    @Test("isLeader_팀원이있는리더_true")
    func isLeader_withTeammates_true() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))
        #expect(tracker.isLeader(surfaceId: "leader-1"))
    }

    @Test("isLeader_팀원없는리더_false")
    func isLeader_noTeammates_false() {
        let tracker = TeamPaneTracker()
        #expect(!tracker.isLeader(surfaceId: "leader-1"))
    }

    // MARK: - 네거티브 테스트 (Negative Tests)

    @Test("register_빈name_저장됨")
    func register_emptyName_stores() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "", color: "blue", leaderSurfaceId: "leader-1"))
        #expect(tracker.teammates(for: "leader-1")[0].name == "")
    }

    @Test("register_빈color_저장됨")
    func register_emptyColor_stores() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "", leaderSurfaceId: "leader-1"))
        #expect(tracker.teammates(for: "leader-1")[0].color == "")
    }

    @Test("register_빈surfaceId_저장됨")
    func register_emptySurfaceId_stores() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))
        #expect(tracker.teammates(for: "leader-1").count == 1)
        #expect(tracker.isTeammate(surfaceId: ""))
    }

    @Test("register_빈leaderSurfaceId_저장됨")
    func register_emptyLeaderSurfaceId_stores() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: ""))
        #expect(tracker.teammates(for: "").count == 1)
        #expect(tracker.isLeader(surfaceId: ""))
    }

    @Test("remove_미등록surfaceId_에러없음")
    func remove_unregisteredSurfaceId_noError() {
        let tracker = TeamPaneTracker()
        tracker.remove(surfaceId: "nonexistent")
    }

    @Test("removeAllForLeader_미등록리더_에러없음")
    func removeAllForLeader_unregisteredLeader_noError() {
        let tracker = TeamPaneTracker()
        tracker.removeAllForLeader(surfaceId: "nonexistent")
    }

    @Test("remove_이중호출_에러없음")
    func remove_doubleRemove_noError() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))
        tracker.remove(surfaceId: "mate-1")
        tracker.remove(surfaceId: "mate-1") // 두 번째 호출
        #expect(tracker.teammates(for: "leader-1").isEmpty)
    }

    @Test("register_팀원을다른리더로이동")
    func register_moveTeammateToDifferentLeader() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-1"))

        // 같은 surfaceId를 다른 리더에 등록 → 이전 리더에서 제거
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "explorer", color: "blue", leaderSurfaceId: "leader-2"))

        #expect(tracker.teammates(for: "leader-1").isEmpty)
        #expect(tracker.teammates(for: "leader-2").count == 1)
        #expect(tracker.leaderSurfaceId(for: "mate-1") == "leader-2")
    }

    @Test("register_리더와팀원이동일surfaceId")
    func register_leaderAndTeammateSameSurfaceId() {
        let tracker = TeamPaneTracker()
        // 자기 자신을 리더로 등록하는 비정상 케이스
        tracker.register(teammate: .init(surfaceId: "same-id", name: "self", color: "blue", leaderSurfaceId: "same-id"))

        #expect(tracker.isTeammate(surfaceId: "same-id"))
        #expect(tracker.isLeader(surfaceId: "same-id"))
        #expect(tracker.teammates(for: "same-id").count == 1)
    }

    @Test("remove_후_isLeader_isTeammate_일관성")
    func remove_afterRemove_consistencyCheck() {
        let tracker = TeamPaneTracker()
        tracker.register(teammate: .init(surfaceId: "mate-1", name: "a", color: "blue", leaderSurfaceId: "leader-1"))
        tracker.register(teammate: .init(surfaceId: "mate-2", name: "b", color: "green", leaderSurfaceId: "leader-1"))

        tracker.remove(surfaceId: "mate-1")

        #expect(tracker.isLeader(surfaceId: "leader-1")) // 아직 mate-2가 있으므로 true
        #expect(!tracker.isTeammate(surfaceId: "mate-1"))
        #expect(tracker.isTeammate(surfaceId: "mate-2"))
        #expect(tracker.leaderSurfaceId(for: "mate-1") == nil)
        #expect(tracker.leaderSurfaceId(for: "mate-2") == "leader-1")
    }

    // MARK: - 퍼징 테스트 (Fuzz Tests)

    @Test("fuzz_랜덤등록제거시퀀스_크래시없음")
    func fuzz_randomRegisterRemoveSequence_noCrash() {
        let tracker = TeamPaneTracker()
        let leaders = (0..<5).map { "leader-\($0)" }
        let mates = (0..<20).map { "mate-\($0)" }
        let names = ["explorer", "writer", "tester", "reviewer", "analyst"]
        let colors = ["blue", "green", "red", "yellow", "purple"]

        for _ in 0..<500 {
            let action = Int.random(in: 0..<4)
            switch action {
            case 0:
                // register
                let mateId = mates.randomElement()!
                let leaderId = leaders.randomElement()!
                tracker.register(teammate: .init(
                    surfaceId: mateId,
                    name: names.randomElement()!,
                    color: colors.randomElement()!,
                    leaderSurfaceId: leaderId
                ))
            case 1:
                // remove
                let mateId = mates.randomElement()!
                tracker.remove(surfaceId: mateId)
            case 2:
                // removeAllForLeader
                let leaderId = leaders.randomElement()!
                tracker.removeAllForLeader(surfaceId: leaderId)
            case 3:
                // query
                let leaderId = leaders.randomElement()!
                let mateId = mates.randomElement()!
                _ = tracker.teammates(for: leaderId)
                _ = tracker.isLeader(surfaceId: leaderId)
                _ = tracker.isTeammate(surfaceId: mateId)
                _ = tracker.leaderSurfaceId(for: mateId)
            default:
                break
            }
        }
        // 크래시 없으면 성공
    }

    @Test("fuzz_대량등록후전체제거_일관성유지")
    func fuzz_massRegisterThenRemoveAll_consistent() {
        let tracker = TeamPaneTracker()

        // 50명 팀원을 5개 리더에 등록
        for i in 0..<50 {
            let leaderId = "leader-\(i % 5)"
            tracker.register(teammate: .init(
                surfaceId: "mate-\(i)", name: "agent-\(i)", color: "blue", leaderSurfaceId: leaderId
            ))
        }

        // 각 리더에 10명씩 있어야 함
        for l in 0..<5 {
            #expect(tracker.teammates(for: "leader-\(l)").count == 10)
        }

        // 전체 제거
        for l in 0..<5 {
            tracker.removeAllForLeader(surfaceId: "leader-\(l)")
        }

        // 모든 팀원/리더 조회가 비어있어야 함
        for l in 0..<5 {
            #expect(tracker.teammates(for: "leader-\(l)").isEmpty)
            #expect(!tracker.isLeader(surfaceId: "leader-\(l)"))
        }
        for i in 0..<50 {
            #expect(!tracker.isTeammate(surfaceId: "mate-\(i)"))
            #expect(tracker.leaderSurfaceId(for: "mate-\(i)") == nil)
        }
    }

    @Test("fuzz_등록제거교차_역방향조회일관성")
    func fuzz_interleavedRegisterRemove_reverseMapConsistency() {
        let tracker = TeamPaneTracker()

        // 등록
        for i in 0..<20 {
            tracker.register(teammate: .init(surfaceId: "m-\(i)", name: "a-\(i)", color: "blue", leaderSurfaceId: "leader-\(i % 3)"))
        }

        // 짝수만 제거
        for i in stride(from: 0, to: 20, by: 2) {
            tracker.remove(surfaceId: "m-\(i)")
        }

        // 홀수만 남아있어야 함
        for i in 0..<20 {
            if i % 2 == 0 {
                #expect(!tracker.isTeammate(surfaceId: "m-\(i)"))
                #expect(tracker.leaderSurfaceId(for: "m-\(i)") == nil)
            } else {
                #expect(tracker.isTeammate(surfaceId: "m-\(i)"))
                #expect(tracker.leaderSurfaceId(for: "m-\(i)") == "leader-\(i % 3)")
            }
        }
    }
}
