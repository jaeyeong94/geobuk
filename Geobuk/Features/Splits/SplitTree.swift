import Foundation

// MARK: - Pane Types

/// 터미널 패널 (Phase 1 GhosttySurfaceView 참조)
struct TerminalPane: Identifiable, Sendable {
    let id: UUID
}

/// 브라우저 패널 (Phase 7 placeholder)
struct BrowserPane: Identifiable, Sendable {
    let id: UUID
}

/// 패널 콘텐츠 타입
enum PaneContent: Identifiable, Sendable {
    case terminal(TerminalPane)
    case browser(BrowserPane)

    var id: UUID {
        switch self {
        case .terminal(let pane): return pane.id
        case .browser(let pane): return pane.id
        }
    }
}

// MARK: - Split Direction

/// 패널 이동 방향
enum NavigationDirection {
    case left, right, up, down
}

/// 분할 방향
enum SplitDirection: Sendable {
    case horizontal  // 좌우 나란히
    case vertical    // 상하 나란히
}

// MARK: - Split Container

/// 분할 컨테이너 (두 자식 노드를 가짐)
struct SplitContainer: Identifiable, Sendable {
    let id: UUID
    let direction: SplitDirection
    let ratio: CGFloat
    let first: SplitNode
    let second: SplitNode
}

// MARK: - Split Node

/// 분할 트리의 노드 (값 타입, 불변)
indirect enum SplitNode: Identifiable, Sendable {
    case leaf(PaneContent)
    case split(SplitContainer)

    var id: UUID {
        switch self {
        case .leaf(let content): return content.id
        case .split(let container): return container.id
        }
    }

    /// leaf 노드인지 여부
    var isLeaf: Bool {
        if case .leaf = self { return true }
        return false
    }

    // MARK: - 트리 탐색

    /// 모든 leaf 노드의 PaneContent를 반환
    func allLeaves() -> [PaneContent] {
        switch self {
        case .leaf(let content):
            return [content]
        case .split(let container):
            return container.first.allLeaves() + container.second.allLeaves()
        }
    }

    /// ID로 노드 찾기
    func findNode(by targetId: UUID) -> SplitNode? {
        if self.id == targetId { return self }
        if case .split(let container) = self {
            if let found = container.first.findNode(by: targetId) { return found }
            if let found = container.second.findNode(by: targetId) { return found }
        }
        return nil
    }

    // MARK: - 분할 연산

    /// 특정 leaf를 분할하여 새 컨테이너 생성
    /// - Returns: 분할된 새 트리, 대상을 찾지 못하면 nil
    func splitLeaf(
        targetId: UUID,
        newContent: PaneContent,
        direction: SplitDirection,
        ratio: CGFloat = 0.5
    ) -> SplitNode? {
        switch self {
        case .leaf(let content):
            guard content.id == targetId else { return nil }
            return .split(SplitContainer(
                id: UUID(),
                direction: direction,
                ratio: ratio,
                first: .leaf(content),
                second: .leaf(newContent)
            ))

        case .split(let container):
            // 왼쪽에서 먼저 시도
            if let newFirst = container.first.splitLeaf(
                targetId: targetId,
                newContent: newContent,
                direction: direction,
                ratio: ratio
            ) {
                return .split(SplitContainer(
                    id: container.id,
                    direction: container.direction,
                    ratio: container.ratio,
                    first: newFirst,
                    second: container.second
                ))
            }
            // 오른쪽에서 시도
            if let newSecond = container.second.splitLeaf(
                targetId: targetId,
                newContent: newContent,
                direction: direction,
                ratio: ratio
            ) {
                return .split(SplitContainer(
                    id: container.id,
                    direction: container.direction,
                    ratio: container.ratio,
                    first: container.first,
                    second: newSecond
                ))
            }
            return nil
        }
    }

    // MARK: - 닫기 연산

    /// leaf 닫기 결과
    enum CloseResult {
        case removed      // 이 노드 전체가 제거됨
        case updated(SplitNode)  // 이 노드가 업데이트됨
        case unchanged    // 대상을 찾지 못함
    }

    /// 특정 leaf를 닫고 형제 노드를 승격
    func closeLeaf(targetId: UUID) -> CloseResult {
        switch self {
        case .leaf(let content):
            if content.id == targetId {
                return .removed
            }
            return .unchanged

        case .split(let container):
            let firstResult = container.first.closeLeaf(targetId: targetId)
            switch firstResult {
            case .removed:
                // first가 제거됨 -> second를 승격
                return .updated(container.second)
            case .updated(let newFirst):
                return .updated(.split(SplitContainer(
                    id: container.id,
                    direction: container.direction,
                    ratio: container.ratio,
                    first: newFirst,
                    second: container.second
                )))
            case .unchanged:
                break
            }

            let secondResult = container.second.closeLeaf(targetId: targetId)
            switch secondResult {
            case .removed:
                // second가 제거됨 -> first를 승격
                return .updated(container.first)
            case .updated(let newSecond):
                return .updated(.split(SplitContainer(
                    id: container.id,
                    direction: container.direction,
                    ratio: container.ratio,
                    first: container.first,
                    second: newSecond
                )))
            case .unchanged:
                return .unchanged
            }
        }
    }

    // MARK: - 균등 비율

    /// 트리 내 모든 leaf의 크기가 동일해지도록 비율 재계산
    /// 각 split 노드에서 ratio = (왼쪽 leaf 수) / (전체 leaf 수)
    func equalized() -> SplitNode {
        switch self {
        case .leaf:
            return self
        case .split(let container):
            let equalizedFirst = container.first.equalized()
            let equalizedSecond = container.second.equalized()
            let leftCount = CGFloat(equalizedFirst.leafCount)
            let totalCount = leftCount + CGFloat(equalizedSecond.leafCount)
            let newRatio = leftCount / totalCount
            return .split(SplitContainer(
                id: container.id,
                direction: container.direction,
                ratio: newRatio,
                first: equalizedFirst,
                second: equalizedSecond
            ))
        }
    }

    /// leaf 노드 수
    var leafCount: Int {
        switch self {
        case .leaf:
            return 1
        case .split(let container):
            return container.first.leafCount + container.second.leafCount
        }
    }

    // MARK: - 방향 기반 탐색

    /// 주어진 방향으로 이동할 때 도달하는 leaf의 ID 반환
    /// - left/up: 같은 방향 split에서 first(왼쪽/위) 서브트리의 마지막 leaf
    /// - right/down: 같은 방향 split에서 second(오른쪽/아래) 서브트리의 첫 leaf
    func neighborInDirection(from leafId: UUID, direction: NavigationDirection) -> UUID? {
        let path = pathTo(leafId: leafId)
        guard !path.isEmpty else { return nil }

        // 경로를 역순으로 탐색: 해당 방향과 매칭되는 split 찾기
        for i in stride(from: path.count - 1, through: 0, by: -1) {
            let (container, isInFirst) = path[i]

            let splitDirection = container.direction
            let matchesDirection: Bool = switch direction {
            case .left:  splitDirection == .horizontal && !isInFirst
            case .right: splitDirection == .horizontal && isInFirst
            case .up:    splitDirection == .vertical && !isInFirst
            case .down:  splitDirection == .vertical && isInFirst
            }

            if matchesDirection {
                // 반대쪽 서브트리에서 적절한 leaf 선택
                let targetSubtree = isInFirst ? container.second : container.first
                switch direction {
                case .left, .up:
                    return targetSubtree.allLeaves().last?.id
                case .right, .down:
                    return targetSubtree.allLeaves().first?.id
                }
            }
        }

        return nil
    }

    /// 루트에서 leafId까지의 경로: [(컨테이너, leaf가 first에 있는지)]
    private func pathTo(leafId: UUID) -> [(container: SplitContainer, isInFirst: Bool)] {
        switch self {
        case .leaf(let content):
            return content.id == leafId ? [] : []
        case .split(let container):
            if container.first.containsLeaf(id: leafId) {
                return [(container, true)] + container.first.pathTo(leafId: leafId)
            } else if container.second.containsLeaf(id: leafId) {
                return [(container, false)] + container.second.pathTo(leafId: leafId)
            }
            return []
        }
    }

    /// leaf ID가 이 서브트리에 존재하는지
    private func containsLeaf(id: UUID) -> Bool {
        switch self {
        case .leaf(let content): return content.id == id
        case .split(let container):
            return container.first.containsLeaf(id: id) || container.second.containsLeaf(id: id)
        }
    }

    // MARK: - 리사이즈 연산

    /// 특정 컨테이너의 비율 변경
    /// - Returns: 업데이트된 트리, 대상을 찾지 못하면 nil
    func resizeSplit(containerId: UUID, newRatio: CGFloat) -> SplitNode? {
        let clampedRatio = min(max(newRatio, 0.1), 0.9)

        switch self {
        case .leaf:
            return nil

        case .split(let container):
            if container.id == containerId {
                return .split(SplitContainer(
                    id: container.id,
                    direction: container.direction,
                    ratio: clampedRatio,
                    first: container.first,
                    second: container.second
                ))
            }
            // 재귀적으로 탐색
            if let newFirst = container.first.resizeSplit(containerId: containerId, newRatio: newRatio) {
                return .split(SplitContainer(
                    id: container.id,
                    direction: container.direction,
                    ratio: container.ratio,
                    first: newFirst,
                    second: container.second
                ))
            }
            if let newSecond = container.second.resizeSplit(containerId: containerId, newRatio: newRatio) {
                return .split(SplitContainer(
                    id: container.id,
                    direction: container.direction,
                    ratio: container.ratio,
                    first: container.first,
                    second: newSecond
                ))
            }
            return nil
        }
    }
}
