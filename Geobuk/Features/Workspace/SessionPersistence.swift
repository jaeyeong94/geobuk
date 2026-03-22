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
    /// 패널별 작업 디렉토리
    let cwd: String?

    init(type: NodeType, direction: String?, ratio: Double?, children: [PersistedSplitNode]?, cwd: String? = nil) {
        self.type = type
        self.direction = direction
        self.ratio = ratio
        self.children = children
        self.cwd = cwd
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
        return AppPath.appSupport
            .appendingPathComponent("sessions")
            .appendingPathComponent("state.json")
            .path
    }()

    // MARK: - SplitNode <-> PersistedSplitNode 변환

    /// SplitNode를 PersistedSplitNode로 변환
    /// surfaceViews: 패널별 CWD를 읽기 위한 참조
    static func persistedNode(from node: SplitNode, surfaceViews: [UUID: GhosttySurfaceView] = [:]) -> PersistedSplitNode {
        switch node {
        case .leaf(let content):
            let cwd = surfaceViews[content.id]?.currentDirectory
            return PersistedSplitNode(type: .leaf, direction: nil, ratio: nil, children: nil, cwd: cwd)

        case .split(let container):
            let directionStr = container.direction == .horizontal ? "horizontal" : "vertical"
            let first = persistedNode(from: container.first, surfaceViews: surfaceViews)
            let second = persistedNode(from: container.second, surfaceViews: surfaceViews)
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
    /// cwdMap: 패널 UUID → 복원할 CWD 경로 (inout으로 수집)
    static func splitNode(from persisted: PersistedSplitNode, cwdMap: inout [UUID: String]) -> SplitNode {
        switch persisted.type {
        case .leaf:
            let pane = TerminalPane(id: UUID())
            if let cwd = persisted.cwd, !cwd.isEmpty {
                cwdMap[pane.id] = cwd
            }
            return .leaf(.terminal(pane))

        case .split:
            guard let children = persisted.children, children.count >= 2 else {
                let pane = TerminalPane(id: UUID())
                return .leaf(.terminal(pane))
            }

            let direction: SplitDirection = persisted.direction == "vertical" ? .vertical : .horizontal
            let ratio = CGFloat(persisted.ratio ?? 0.5)

            let first = splitNode(from: children[0], cwdMap: &cwdMap)
            let second = splitNode(from: children[1], cwdMap: &cwdMap)

            return .split(SplitContainer(
                id: UUID(),
                direction: direction,
                ratio: ratio,
                first: first,
                second: second
            ))
        }
    }

    /// 하위호환: cwdMap 없이 호출
    static func splitNode(from persisted: PersistedSplitNode) -> SplitNode {
        var cwdMap: [UUID: String] = [:]
        return splitNode(from: persisted, cwdMap: &cwdMap)
    }

    // MARK: - WorkspaceManager -> PersistedState

    /// WorkspaceManager에서 PersistedState 스냅샷 생성
    static func snapshot(from manager: WorkspaceManager, surfaceViews: [UUID: GhosttySurfaceView] = [:]) -> PersistedState {
        let workspaces = manager.workspaces.map { ws in
            // 워크스페이스 CWD: 포커스된 패널의 CWD, 없으면 기존 ws.cwd
            let focusedCwd = ws.splitManager.focusedPaneId.flatMap { surfaceViews[$0]?.currentDirectory } ?? ws.cwd
            return PersistedWorkspace(
                name: ws.name,
                cwd: focusedCwd,
                splitLayout: persistedNode(from: ws.splitManager.root, surfaceViews: surfaceViews)
            )
        }
        return PersistedState(workspaces: workspaces, activeIndex: manager.activeIndex)
    }

    // MARK: - 파일 저장/복원

    /// 상태를 파일로 저장
    static func save(manager: WorkspaceManager, surfaceViews: [UUID: GhosttySurfaceView] = [:], to path: String? = nil) {
        let savePath = path ?? defaultSavePath
        let state = snapshot(from: manager, surfaceViews: surfaceViews)

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
