import Foundation
import Observation

/// 하나의 워크스페이스를 나타내는 모델
/// 각 워크스페이스는 독립적인 SplitTreeManager를 소유한다
@MainActor
@Observable
final class Workspace: Identifiable {
    let id: UUID
    var name: String
    var cwd: String
    let splitManager: SplitTreeManager
    let createdAt: Date

    init(name: String, cwd: String) {
        self.id = UUID()
        self.name = name
        self.cwd = cwd
        self.splitManager = SplitTreeManager()
        self.createdAt = Date()
    }

    /// 복원용: 외부에서 SplitTreeManager를 지정하여 초기화
    init(name: String, cwd: String, splitManager: SplitTreeManager) {
        self.id = UUID()
        self.name = name
        self.cwd = cwd
        self.splitManager = splitManager
        self.createdAt = Date()
    }
}
