import Foundation
import Observation

/// 분할 트리 상태를 관리하는 매니저
/// Undo/Redo를 위해 값 타입 스냅샷을 사용
@MainActor
@Observable
final class SplitTreeManager {

    // MARK: - State

    /// 현재 분할 트리 루트
    private(set) var root: SplitNode

    /// 현재 포커스된 패널 ID
    private(set) var focusedPaneId: UUID?

    /// 현재 포커스된 패널이 최대화 상태인지 여부
    private(set) var isMaximized = false

    // MARK: - Undo/Redo

    /// 스냅샷: (트리 루트, 포커스 ID)
    private struct Snapshot {
        let root: SplitNode
        let focusedPaneId: UUID?
    }

    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []

    /// Undo 가능 여부
    var canUndo: Bool { !undoStack.isEmpty }

    /// Redo 가능 여부
    var canRedo: Bool { !redoStack.isEmpty }

    /// 패널 수
    var paneCount: Int { root.allLeaves().count }

    // MARK: - Initialization

    init() {
        let initialPane = TerminalPane(id: UUID())
        self.root = .leaf(.terminal(initialPane))
        self.focusedPaneId = initialPane.id
    }

    /// 테스트용: 특정 루트와 포커스로 초기화
    init(root: SplitNode, focusedPaneId: UUID?) {
        self.root = root
        self.focusedPaneId = focusedPaneId
    }

    // MARK: - Snapshot Management

    /// 현재 상태를 undo 스택에 저장
    private func saveSnapshot() {
        undoStack.append(Snapshot(root: root, focusedPaneId: focusedPaneId))
        redoStack.removeAll()
    }

    // MARK: - Split Operations

    /// 현재 포커스된 패널을 분할
    func splitFocusedPane(direction: SplitDirection) {
        guard let focusedId = focusedPaneId else { return }

        let newPane = TerminalPane(id: UUID())
        guard let newRoot = root.splitLeaf(
            targetId: focusedId,
            newContent: .terminal(newPane),
            direction: direction
        ) else { return }

        saveSnapshot()
        root = newRoot.equalized()
        focusedPaneId = newPane.id
    }

    // MARK: - Close Operations

    /// 현재 포커스된 패널 닫기
    func closeFocusedPane() {
        guard let focusedId = focusedPaneId else { return }

        let result = root.closeLeaf(targetId: focusedId)
        switch result {
        case .removed:
            // 마지막 패널이면 닫지 않음
            break
        case .updated(let newRoot):
            saveSnapshot()
            root = newRoot
            // 포커스를 남은 패널 중 첫 번째로 이동
            let leaves = newRoot.allLeaves()
            focusedPaneId = leaves.first?.id
            // 패널이 하나만 남으면 최대화 해제
            if leaves.count <= 1 {
                isMaximized = false
            }
        case .unchanged:
            break
        }
    }

    // MARK: - Focus Navigation

    /// 다음 패널로 포커스 이동
    func focusNextPane() {
        let leaves = root.allLeaves()
        guard leaves.count > 1, let currentId = focusedPaneId else { return }
        guard let currentIndex = leaves.firstIndex(where: { $0.id == currentId }) else { return }
        let nextIndex = (currentIndex + 1) % leaves.count
        focusedPaneId = leaves[nextIndex].id
    }

    /// 이전 패널로 포커스 이동
    func focusPreviousPane() {
        let leaves = root.allLeaves()
        guard leaves.count > 1, let currentId = focusedPaneId else { return }
        guard let currentIndex = leaves.firstIndex(where: { $0.id == currentId }) else { return }
        let prevIndex = (currentIndex - 1 + leaves.count) % leaves.count
        focusedPaneId = leaves[prevIndex].id
    }

    /// 방향 기반 패널 이동 (공간 탐색)
    func focusPane(direction: NavigationDirection) {
        guard let currentId = focusedPaneId else { return }
        if let neighborId = root.neighborInDirection(from: currentId, direction: direction) {
            focusedPaneId = neighborId
        }
    }

    /// 특정 패널에 포커스 설정
    func setFocusedPane(id: UUID) {
        // 해당 ID의 leaf가 존재하는지 확인
        let leaves = root.allLeaves()
        guard leaves.contains(where: { $0.id == id }) else { return }
        focusedPaneId = id
    }

    // MARK: - Maximize

    /// 포커스된 패널 최대화/복원 토글
    func toggleMaximize() {
        // 패널이 하나뿐이면 최대화할 필요 없음
        guard paneCount > 1 else { return }
        isMaximized.toggle()
    }

    // MARK: - Resize

    /// 분할 비율 변경
    func resizeSplit(containerId: UUID, ratio: CGFloat) {
        guard let newRoot = root.resizeSplit(containerId: containerId, newRatio: ratio) else { return }
        saveSnapshot()
        root = newRoot
    }

    // MARK: - Undo/Redo

    /// 마지막 작업 되돌리기
    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(Snapshot(root: root, focusedPaneId: focusedPaneId))
        root = snapshot.root
        focusedPaneId = snapshot.focusedPaneId
    }

    /// 되돌린 작업 다시 실행
    func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(Snapshot(root: root, focusedPaneId: focusedPaneId))
        root = snapshot.root
        focusedPaneId = snapshot.focusedPaneId
    }
}
