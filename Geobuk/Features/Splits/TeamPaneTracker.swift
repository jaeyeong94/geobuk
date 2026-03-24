import Foundation
import Observation

/// Claude Code Team의 리더-팀원 관계를 추적하는 매니저
/// it2 shim의 pane.registerTeammate API로 등록되며, SplitPaneView에서 TeamMemberBar 표시에 사용
@MainActor
@Observable
final class TeamPaneTracker {
    static let shared = TeamPaneTracker()

    struct Teammate: Sendable {
        let surfaceId: String
        let name: String
        let color: String
        let leaderSurfaceId: String
    }

    /// leaderSurfaceId → [Teammate]
    private(set) var teams: [String: [Teammate]] = [:]

    /// surfaceId → leaderSurfaceId (역방향 조회용)
    private var surfaceToLeader: [String: String] = [:]

    init() {}

    /// 팀원을 등록한다. 동일 surfaceId가 이미 있으면 업데이트.
    func register(teammate: Teammate) {
        // 기존 등록이 있으면 먼저 제거
        if surfaceToLeader[teammate.surfaceId] != nil {
            remove(surfaceId: teammate.surfaceId)
        }

        teams[teammate.leaderSurfaceId, default: []].append(teammate)
        surfaceToLeader[teammate.surfaceId] = teammate.leaderSurfaceId
    }

    /// surfaceId로 팀원을 제거한다.
    func remove(surfaceId: String) {
        guard let leaderId = surfaceToLeader.removeValue(forKey: surfaceId) else { return }
        teams[leaderId]?.removeAll { $0.surfaceId == surfaceId }
        if teams[leaderId]?.isEmpty == true {
            teams.removeValue(forKey: leaderId)
        }
    }

    /// 리더의 모든 팀원을 제거한다.
    func removeAllForLeader(surfaceId: String) {
        guard let mates = teams.removeValue(forKey: surfaceId) else { return }
        for mate in mates {
            surfaceToLeader.removeValue(forKey: mate.surfaceId)
        }
    }

    /// 리더의 팀원 목록을 반환한다.
    func teammates(for leaderSurfaceId: String) -> [Teammate] {
        return teams[leaderSurfaceId] ?? []
    }

    /// 팀원의 리더 surfaceId를 반환한다.
    func leaderSurfaceId(for surfaceId: String) -> String? {
        return surfaceToLeader[surfaceId]
    }

    /// 해당 surfaceId가 팀원인지 확인한다.
    func isTeammate(surfaceId: String) -> Bool {
        return surfaceToLeader[surfaceId] != nil
    }

    /// 해당 surfaceId가 리더(팀원이 있는)인지 확인한다.
    func isLeader(surfaceId: String) -> Bool {
        guard let mates = teams[surfaceId] else { return false }
        return !mates.isEmpty
    }
}
