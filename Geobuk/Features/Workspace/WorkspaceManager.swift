import Foundation
import Observation

/// 여러 워크스페이스를 관리하는 매니저
@MainActor
@Observable
final class WorkspaceManager {
    /// 모든 워크스페이스
    private(set) var workspaces: [Workspace] = []

    /// 현재 활성 워크스페이스 인덱스
    private(set) var activeIndex: Int = 0

    /// 활성 워크스페이스
    var activeWorkspace: Workspace? {
        workspaces.indices.contains(activeIndex) ? workspaces[activeIndex] : nil
    }

    init() {
        let workspace = Workspace(name: "Default", cwd: NSHomeDirectory())
        workspaces.append(workspace)
    }

    /// 테스트/복원용: 외부에서 워크스페이스 목록과 인덱스를 지정하여 초기화
    init(workspaces: [Workspace], activeIndex: Int) {
        self.workspaces = workspaces
        self.activeIndex = workspaces.indices.contains(activeIndex) ? activeIndex : 0
    }

    // MARK: - CRUD

    /// 새 워크스페이스를 생성하고 활성화한다
    @discardableResult
    func createWorkspace(name: String, cwd: String?) -> Workspace {
        let workspace = Workspace(name: name, cwd: cwd ?? NSHomeDirectory())
        workspaces.append(workspace)
        activeIndex = workspaces.count - 1
        return workspace
    }

    /// 외부에서 생성한 워크스페이스를 추가하고 활성화
    func addAndActivate(_ workspace: Workspace) {
        workspaces.append(workspace)
        activeIndex = workspaces.count - 1
    }

    /// 지정 인덱스의 워크스페이스를 닫는다
    /// 마지막 하나는 닫을 수 없다
    func closeWorkspace(at index: Int) {
        guard workspaces.indices.contains(index) else { return }
        guard workspaces.count > 1 else { return }

        workspaces.remove(at: index)

        // activeIndex 조정
        if activeIndex >= workspaces.count {
            activeIndex = workspaces.count - 1
        } else if index < activeIndex {
            activeIndex -= 1
        }
        // index == activeIndex인 경우: remove 후 같은 인덱스가 다음 항목을 가리키거나
        // count를 넘으면 위에서 조정됨
    }

    /// 지정 인덱스의 워크스페이스로 전환한다
    func switchToWorkspace(at index: Int) {
        guard workspaces.indices.contains(index) else { return }
        activeIndex = index
    }

    /// 지정 인덱스의 워크스페이스 이름을 변경한다
    func renameWorkspace(at index: Int, name: String) {
        guard workspaces.indices.contains(index) else { return }
        guard !name.isEmpty else { return }
        workspaces[index].name = name
    }

    /// 워크스페이스 순서를 변경한다 (드래그 재정렬)
    func moveWorkspace(from sourceIndex: Int, to destinationIndex: Int) {
        guard workspaces.indices.contains(sourceIndex) else { return }
        guard workspaces.indices.contains(destinationIndex) else { return }
        guard sourceIndex != destinationIndex else { return }

        let activeId = activeWorkspace?.id
        let workspace = workspaces.remove(at: sourceIndex)
        workspaces.insert(workspace, at: destinationIndex)

        // 활성 워크스페이스 인덱스를 추적
        if let activeId {
            if let newIndex = workspaces.firstIndex(where: { $0.id == activeId }) {
                activeIndex = newIndex
            }
        }
    }
}
