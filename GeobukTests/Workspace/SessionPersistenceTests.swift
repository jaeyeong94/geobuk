import Testing
import Foundation
@testable import Geobuk

@Suite("SessionPersistence - 세션 영속성")
@MainActor
struct SessionPersistenceTests {

    // MARK: - PersistedSplitNode 인코딩/디코딩

    @Test("PersistedSplitNode_leaf_roundTrip")
    func persistedSplitNode_leaf_roundTrip() throws {
        let node = PersistedSplitNode(type: .leaf, direction: nil, ratio: nil, children: nil)
        let data = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(PersistedSplitNode.self, from: data)
        #expect(decoded.type == .leaf)
        #expect(decoded.direction == nil)
        #expect(decoded.ratio == nil)
        #expect(decoded.children == nil)
    }

    @Test("PersistedSplitNode_split_roundTrip")
    func persistedSplitNode_split_roundTrip() throws {
        let child1 = PersistedSplitNode(type: .leaf, direction: nil, ratio: nil, children: nil)
        let child2 = PersistedSplitNode(type: .leaf, direction: nil, ratio: nil, children: nil)
        let node = PersistedSplitNode(
            type: .split,
            direction: "horizontal",
            ratio: 0.5,
            children: [child1, child2]
        )
        let data = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(PersistedSplitNode.self, from: data)
        #expect(decoded.type == .split)
        #expect(decoded.direction == "horizontal")
        #expect(decoded.ratio == 0.5)
        #expect(decoded.children?.count == 2)
    }

    @Test("PersistedSplitNode_nestedSplit_roundTrip")
    func persistedSplitNode_nestedSplit_roundTrip() throws {
        let leaf = PersistedSplitNode(type: .leaf, direction: nil, ratio: nil, children: nil)
        let innerSplit = PersistedSplitNode(
            type: .split,
            direction: "vertical",
            ratio: 0.3,
            children: [leaf, leaf]
        )
        let outerSplit = PersistedSplitNode(
            type: .split,
            direction: "horizontal",
            ratio: 0.6,
            children: [leaf, innerSplit]
        )
        let data = try JSONEncoder().encode(outerSplit)
        let decoded = try JSONDecoder().decode(PersistedSplitNode.self, from: data)
        #expect(decoded.children?[1].children?.count == 2)
        #expect(decoded.children?[1].direction == "vertical")
    }

    // MARK: - PersistedWorkspace 인코딩/디코딩

    @Test("PersistedWorkspace_roundTrip")
    func persistedWorkspace_roundTrip() throws {
        let layout = PersistedSplitNode(type: .leaf, direction: nil, ratio: nil, children: nil)
        let ws = PersistedWorkspace(name: "MyWorkspace", cwd: "/tmp/test", splitLayout: layout)
        let data = try JSONEncoder().encode(ws)
        let decoded = try JSONDecoder().decode(PersistedWorkspace.self, from: data)
        #expect(decoded.name == "MyWorkspace")
        #expect(decoded.cwd == "/tmp/test")
        #expect(decoded.splitLayout.type == .leaf)
    }

    // MARK: - PersistedState 인코딩/디코딩

    @Test("PersistedState_전체roundTrip")
    func persistedState_fullRoundTrip() throws {
        let layout = PersistedSplitNode(type: .leaf, direction: nil, ratio: nil, children: nil)
        let ws1 = PersistedWorkspace(name: "Workspace 1", cwd: "/Users/test", splitLayout: layout)
        let ws2 = PersistedWorkspace(name: "Project", cwd: "/tmp/project", splitLayout: layout)
        let state = PersistedState(workspaces: [ws1, ws2], activeIndex: 1)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PersistedState.self, from: data)
        #expect(decoded.workspaces.count == 2)
        #expect(decoded.activeIndex == 1)
        #expect(decoded.workspaces[0].name == "Workspace 1")
        #expect(decoded.workspaces[1].name == "Project")
    }

    @Test("PersistedState_빈워크스페이스_인코딩가능")
    func persistedState_emptyWorkspaces_encodable() throws {
        let state = PersistedState(workspaces: [], activeIndex: 0)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PersistedState.self, from: data)
        #expect(decoded.workspaces.isEmpty)
    }

    // MARK: - SplitNode → PersistedSplitNode 변환

    @Test("splitNodeToPersistedNode_leaf_변환")
    func splitNodeToPersistedNode_leaf_converts() {
        let pane = TerminalPane(id: UUID())
        let node = SplitNode.leaf(.terminal(pane))
        let persisted = SessionPersistence.persistedNode(from: node)
        #expect(persisted.type == .leaf)
        #expect(persisted.direction == nil)
        #expect(persisted.children == nil)
    }

    @Test("splitNodeToPersistedNode_split_변환")
    func splitNodeToPersistedNode_split_converts() {
        let pane1 = TerminalPane(id: UUID())
        let pane2 = TerminalPane(id: UUID())
        let container = SplitContainer(
            id: UUID(),
            direction: .horizontal,
            ratio: 0.5,
            first: .leaf(.terminal(pane1)),
            second: .leaf(.terminal(pane2))
        )
        let node = SplitNode.split(container)
        let persisted = SessionPersistence.persistedNode(from: node)
        #expect(persisted.type == .split)
        #expect(persisted.direction == "horizontal")
        #expect(persisted.ratio == 0.5)
        #expect(persisted.children?.count == 2)
    }

    @Test("splitNodeToPersistedNode_vertical_방향정확")
    func splitNodeToPersistedNode_vertical_directionCorrect() {
        let pane1 = TerminalPane(id: UUID())
        let pane2 = TerminalPane(id: UUID())
        let container = SplitContainer(
            id: UUID(),
            direction: .vertical,
            ratio: 0.7,
            first: .leaf(.terminal(pane1)),
            second: .leaf(.terminal(pane2))
        )
        let persisted = SessionPersistence.persistedNode(from: .split(container))
        #expect(persisted.direction == "vertical")
        #expect(persisted.ratio == 0.7)
    }

    // MARK: - PersistedSplitNode → SplitNode 복원

    @Test("persistedNodeToSplitNode_leaf_복원")
    func persistedNodeToSplitNode_leaf_restores() {
        let persisted = PersistedSplitNode(type: .leaf, direction: nil, ratio: nil, children: nil)
        let node = SessionPersistence.splitNode(from: persisted)
        #expect(node.isLeaf)
        #expect(node.allLeaves().count == 1)
    }

    @Test("persistedNodeToSplitNode_split_복원")
    func persistedNodeToSplitNode_split_restores() {
        let leaf1 = PersistedSplitNode(type: .leaf, direction: nil, ratio: nil, children: nil)
        let leaf2 = PersistedSplitNode(type: .leaf, direction: nil, ratio: nil, children: nil)
        let persisted = PersistedSplitNode(
            type: .split,
            direction: "horizontal",
            ratio: 0.6,
            children: [leaf1, leaf2]
        )
        let node = SessionPersistence.splitNode(from: persisted)
        #expect(!node.isLeaf)
        if case .split(let container) = node {
            #expect(container.direction == .horizontal)
            #expect(container.ratio == 0.6)
            #expect(container.first.isLeaf)
            #expect(container.second.isLeaf)
        } else {
            Issue.record("Expected split node")
        }
    }

    @Test("persistedNodeToSplitNode_불완전split_leafFallback")
    func persistedNodeToSplitNode_incompleteSplit_fallsBackToLeaf() {
        // split인데 children이 nil이면 leaf로 fallback
        let persisted = PersistedSplitNode(type: .split, direction: "horizontal", ratio: 0.5, children: nil)
        let node = SessionPersistence.splitNode(from: persisted)
        #expect(node.isLeaf)
    }

    @Test("persistedNodeToSplitNode_children하나_leafFallback")
    func persistedNodeToSplitNode_oneChild_fallsBackToLeaf() {
        let leaf = PersistedSplitNode(type: .leaf, direction: nil, ratio: nil, children: nil)
        let persisted = PersistedSplitNode(type: .split, direction: "horizontal", ratio: 0.5, children: [leaf])
        let node = SessionPersistence.splitNode(from: persisted)
        #expect(node.isLeaf)
    }

    // MARK: - WorkspaceManager 스냅샷 생성

    @Test("snapshot_단일워크스페이스_정상생성")
    func snapshot_singleWorkspace_creates() {
        let manager = WorkspaceManager()
        let state = SessionPersistence.snapshot(from: manager)
        #expect(state.workspaces.count == 1)
        #expect(state.activeIndex == 0)
        #expect(state.workspaces[0].name == "Workspace 1")
    }

    @Test("snapshot_복수워크스페이스_모두포함")
    func snapshot_multipleWorkspaces_includesAll() {
        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "Project", cwd: "/tmp/project")
        let state = SessionPersistence.snapshot(from: manager)
        #expect(state.workspaces.count == 2)
        #expect(state.activeIndex == 1)
    }

    @Test("snapshot_분할상태_레이아웃포함")
    func snapshot_withSplits_includesLayout() {
        let manager = WorkspaceManager()
        manager.activeWorkspace?.splitManager.splitFocusedPane(direction: .horizontal)
        let state = SessionPersistence.snapshot(from: manager)
        #expect(state.workspaces[0].splitLayout.type == .split)
        #expect(state.workspaces[0].splitLayout.children?.count == 2)
    }

    // MARK: - 파일 저장/복원

    @Test("saveAndRestore_roundTrip_정상동작")
    func saveAndRestore_roundTrip_works() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("geobuk-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let savePath = tempDir.appendingPathComponent("state.json").path

        let manager = WorkspaceManager()
        _ = manager.createWorkspace(name: "TestWS", cwd: "/tmp/test")
        manager.activeWorkspace?.splitManager.splitFocusedPane(direction: .vertical)

        SessionPersistence.save(manager: manager, to: savePath)

        let restored = SessionPersistence.restore(from: savePath)
        #expect(restored != nil)
        #expect(restored?.workspaces.count == 2)
        #expect(restored?.activeIndex == 1)
        #expect(restored?.workspaces[1].name == "TestWS")
        #expect(restored?.workspaces[1].splitLayout.type == .split)
    }

    @Test("restore_파일없음_nil반환")
    func restore_noFile_returnsNil() {
        let result = SessionPersistence.restore(from: "/tmp/nonexistent-geobuk-test/state.json")
        #expect(result == nil)
    }

    @Test("restore_잘못된JSON_nil반환")
    func restore_invalidJSON_returnsNil() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("geobuk-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let savePath = tempDir.appendingPathComponent("state.json").path
        try "{ invalid json".write(toFile: savePath, atomically: true, encoding: .utf8)

        let result = SessionPersistence.restore(from: savePath)
        #expect(result == nil)
    }

    // MARK: - 하위 호환성 (backward compat)

    @Test("PersistedState_추가필드무시_디코딩성공")
    func persistedState_extraFields_decodesSuccessfully() throws {
        let json = """
        {
            "workspaces": [
                {
                    "name": "Workspace 1",
                    "cwd": "/tmp",
                    "splitLayout": { "type": "leaf" },
                    "extraField": "ignored"
                }
            ],
            "activeIndex": 0,
            "futureField": true
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PersistedState.self, from: data)
        #expect(decoded.workspaces.count == 1)
        #expect(decoded.workspaces[0].name == "Workspace 1")
    }
}
