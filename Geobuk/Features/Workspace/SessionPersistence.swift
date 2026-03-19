import Foundation

// MARK: - Persisted Models

/// 영속화된 분할 노드
struct PersistedSplitNode: Codable {
    enum NodeType: String, Codable {
        case leaf
        case split
    }

    let type: NodeType
    let direction: String?   // "horizontal" or "vertical"
    let ratio: Double?
    let children: [PersistedSplitNode]?
    /// 스크롤백 텍스트 (향후 복원용, 현재 미사용)
    let scrollbackText: String?

    init(type: NodeType, direction: String?, ratio: Double?, children: [PersistedSplitNode]?, scrollbackText: String? = nil) {
        self.type = type
        self.direction = direction
        self.ratio = ratio
        self.children = children
        self.scrollbackText = scrollbackText
    }
}

/// 영속화된 워크스페이스
struct PersistedWorkspace: Codable {
    let name: String
    let cwd: String
    let splitLayout: PersistedSplitNode
}

/// 영속화된 앱 전체 상태
struct PersistedState: Codable {
    let workspaces: [PersistedWorkspace]
    let activeIndex: Int
}

// MARK: - SessionPersistence

/// 세션 상태를 파일로 저장/복원하는 유틸리티
@MainActor
final class SessionPersistence {

    static let defaultSavePath: String = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("Geobuk")
            .appendingPathComponent("sessions")
            .appendingPathComponent("state.json")
            .path
    }()

    // MARK: - SplitNode <-> PersistedSplitNode 변환

    /// SplitNode를 PersistedSplitNode로 변환
    static func persistedNode(from node: SplitNode) -> PersistedSplitNode {
        switch node {
        case .leaf:
            return PersistedSplitNode(type: .leaf, direction: nil, ratio: nil, children: nil)

        case .split(let container):
            let directionStr = container.direction == .horizontal ? "horizontal" : "vertical"
            let first = persistedNode(from: container.first)
            let second = persistedNode(from: container.second)
            return PersistedSplitNode(
                type: .split,
                direction: directionStr,
                ratio: Double(container.ratio),
                children: [first, second]
            )
        }
    }

    /// PersistedSplitNode를 SplitNode로 복원
    /// PTY 세션은 새로 생성됨 (복원 불가)
    static func splitNode(from persisted: PersistedSplitNode) -> SplitNode {
        switch persisted.type {
        case .leaf:
            let pane = TerminalPane(id: UUID())
            return .leaf(.terminal(pane))

        case .split:
            guard let children = persisted.children, children.count >= 2 else {
                // 불완전한 split 데이터는 leaf로 fallback
                let pane = TerminalPane(id: UUID())
                return .leaf(.terminal(pane))
            }

            let direction: SplitDirection = persisted.direction == "vertical" ? .vertical : .horizontal
            let ratio = CGFloat(persisted.ratio ?? 0.5)

            let first = splitNode(from: children[0])
            let second = splitNode(from: children[1])

            return .split(SplitContainer(
                id: UUID(),
                direction: direction,
                ratio: ratio,
                first: first,
                second: second
            ))
        }
    }

    // MARK: - WorkspaceManager -> PersistedState

    /// WorkspaceManager에서 PersistedState 스냅샷 생성
    static func snapshot(from manager: WorkspaceManager) -> PersistedState {
        let workspaces = manager.workspaces.map { ws in
            PersistedWorkspace(
                name: ws.name,
                cwd: ws.cwd,
                splitLayout: persistedNode(from: ws.splitManager.root)
            )
        }
        return PersistedState(workspaces: workspaces, activeIndex: manager.activeIndex)
    }

    // MARK: - 파일 저장/복원

    /// 상태를 파일로 저장
    static func save(manager: WorkspaceManager, to path: String? = nil) {
        let savePath = path ?? defaultSavePath
        let state = snapshot(from: manager)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)

            let url = URL(fileURLWithPath: savePath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url)
        } catch {
            fputs("[Geobuk] Session save failed: \(error)\n", stderr)
        }
    }

    /// 파일에서 상태 복원
    static func restore(from path: String? = nil) -> PersistedState? {
        let loadPath = path ?? defaultSavePath
        let url = URL(fileURLWithPath: loadPath)

        guard let data = try? Data(contentsOf: url) else { return nil }

        do {
            return try JSONDecoder().decode(PersistedState.self, from: data)
        } catch {
            fputs("[Geobuk] Session restore failed: \(error)\n", stderr)
            return nil
        }
    }
}
