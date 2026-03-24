import Foundation
import Observation

/// Claude Code Team의 리더-팀원 관계를 추적하는 매니저
/// 팀원 surfaceView를 SplitTree에 넣지 않고 리더 패널 내부에 미니 터미널로 렌더링
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

    /// surfaceId → GhosttySurfaceView (팀원 터미널 뷰)
    var teamSurfaceViews: [String: GhosttySurfaceView] = [:]

    init() {}

    /// 팀원을 등록한다. 동일 surfaceId가 이미 있으면 업데이트.
    func register(teammate: Teammate, surfaceView: GhosttySurfaceView? = nil) {
        if surfaceToLeader[teammate.surfaceId] != nil {
            remove(surfaceId: teammate.surfaceId)
        }

        teams[teammate.leaderSurfaceId, default: []].append(teammate)
        surfaceToLeader[teammate.surfaceId] = teammate.leaderSurfaceId

        if let sv = surfaceView {
            teamSurfaceViews[teammate.surfaceId] = sv
        }
    }

    /// surfaceId로 팀원을 제거한다.
    func remove(surfaceId: String) {
        guard let leaderId = surfaceToLeader.removeValue(forKey: surfaceId) else { return }
        teams[leaderId]?.removeAll { $0.surfaceId == surfaceId }
        if teams[leaderId]?.isEmpty == true {
            teams.removeValue(forKey: leaderId)
        }
        if let sv = teamSurfaceViews.removeValue(forKey: surfaceId) {
            sv.close()
        }
    }

    /// 리더의 모든 팀원을 제거한다.
    func removeAllForLeader(surfaceId: String) {
        guard let mates = teams.removeValue(forKey: surfaceId) else { return }
        for mate in mates {
            surfaceToLeader.removeValue(forKey: mate.surfaceId)
            if let sv = teamSurfaceViews.removeValue(forKey: mate.surfaceId) {
                sv.close()
            }
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
