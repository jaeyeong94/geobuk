import Testing
import Foundation
@testable import Geobuk

@Suite("SplitTree - 핵심 데이터 구조")
struct SplitTreeTests {

    // MARK: - PaneContent

    @Suite("PaneContent")
    struct PaneContentTests {

        @Test("terminalPane_생성_고유ID부여")
        func terminalPane_creation_hasUniqueId() {
            let pane = TerminalPane(id: UUID())
            let content = PaneContent.terminal(pane)
            #expect(content.id == pane.id)
        }

        @Test("browserPane_생성_고유ID부여")
        func browserPane_creation_hasUniqueId() {
            let pane = BrowserPane(id: UUID())
            let content = PaneContent.browser(pane)
            #expect(content.id == pane.id)
        }

        @Test("terminalPane_두개생성_ID다름")
        func terminalPane_twoCreated_differentIds() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            #expect(pane1.id != pane2.id)
        }
    }

    // MARK: - SplitNode Leaf

    @Suite("SplitNode - Leaf")
    struct SplitNodeLeafTests {

        @Test("leaf_생성_paneContent포함")
        func leaf_creation_containsPaneContent() {
            let pane = TerminalPane(id: UUID())
            let node = SplitNode.leaf(.terminal(pane))

            if case .leaf(let content) = node {
                #expect(content.id == pane.id)
            } else {
                Issue.record("Expected leaf node")
            }
        }

        @Test("leaf_id_paneContentId와동일")
        func leaf_id_matchesPaneContentId() {
            let pane = TerminalPane(id: UUID())
            let node = SplitNode.leaf(.terminal(pane))
            #expect(node.id == pane.id)
        }

        @Test("leaf_isLeaf_true반환")
        func leaf_isLeaf_returnsTrue() {
            let pane = TerminalPane(id: UUID())
            let node = SplitNode.leaf(.terminal(pane))
            #expect(node.isLeaf)
        }
    }

    // MARK: - SplitNode Split

    @Suite("SplitNode - Split")
    struct SplitNodeSplitTests {

        @Test("split_수평분할_두자식노드포함")
        func split_horizontal_containsTwoChildren() {
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

            if case .split(let c) = node {
                #expect(c.direction == .horizontal)
                #expect(c.ratio == 0.5)
            } else {
                Issue.record("Expected split node")
            }
        }

        @Test("split_수직분할_방향올바름")
        func split_vertical_correctDirection() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let container = SplitContainer(
                id: UUID(),
                direction: .vertical,
                ratio: 0.5,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )

            #expect(container.direction == .vertical)
        }

        @Test("split_id_컨테이너ID와동일")
        func split_id_matchesContainerId() {
            let containerId = UUID()
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let container = SplitContainer(
                id: containerId,
                direction: .horizontal,
                ratio: 0.5,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let node = SplitNode.split(container)
            #expect(node.id == containerId)
        }

        @Test("split_isLeaf_false반환")
        func split_isLeaf_returnsFalse() {
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
            #expect(!node.isLeaf)
        }
    }

    // MARK: - SplitNode 트리 탐색

    @Suite("SplitNode - 트리 탐색")
    struct SplitNodeTraversalTests {

        @Test("allLeaves_leaf하나_하나반환")
        func allLeaves_singleLeaf_returnsOne() {
            let pane = TerminalPane(id: UUID())
            let node = SplitNode.leaf(.terminal(pane))
            let leaves = node.allLeaves()
            #expect(leaves.count == 1)
            #expect(leaves[0].id == pane.id)
        }

        @Test("allLeaves_이진트리_모든잎반환")
        func allLeaves_binaryTree_returnsAllLeaves() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let pane3 = TerminalPane(id: UUID())
            // (pane1 | pane2) / pane3
            let top = SplitContainer(
                id: UUID(),
                direction: .horizontal,
                ratio: 0.5,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let root = SplitNode.split(SplitContainer(
                id: UUID(),
                direction: .vertical,
                ratio: 0.5,
                first: .split(top),
                second: .leaf(.terminal(pane3))
            ))
            let leaves = root.allLeaves()
            #expect(leaves.count == 3)
        }

        @Test("findNode_존재하는ID_노드반환")
        func findNode_existingId_returnsNode() {
            let pane = TerminalPane(id: UUID())
            let node = SplitNode.leaf(.terminal(pane))
            let found = node.findNode(by: pane.id)
            #expect(found != nil)
            #expect(found?.id == pane.id)
        }

        @Test("findNode_존재하지않는ID_nil반환")
        func findNode_nonExistingId_returnsNil() {
            let pane = TerminalPane(id: UUID())
            let node = SplitNode.leaf(.terminal(pane))
            let found = node.findNode(by: UUID())
            #expect(found == nil)
        }

        @Test("findNode_중첩트리_깊은노드찾기")
        func findNode_nestedTree_findsDeepNode() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let pane3 = TerminalPane(id: UUID())
            let inner = SplitContainer(
                id: UUID(),
                direction: .horizontal,
                ratio: 0.5,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let root = SplitNode.split(SplitContainer(
                id: UUID(),
                direction: .vertical,
                ratio: 0.5,
                first: .split(inner),
                second: .leaf(.terminal(pane3))
            ))
            let found = root.findNode(by: pane2.id)
            #expect(found != nil)
            #expect(found?.id == pane2.id)
        }
    }

    // MARK: - SplitNode 분할 연산

    @Suite("SplitNode - 분할 연산")
    struct SplitNodeSplitOperationTests {

        @Test("splitLeaf_수평분할_새컨테이너생성")
        func splitLeaf_horizontal_createsNewContainer() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let node = SplitNode.leaf(.terminal(pane1))
            let result = node.splitLeaf(
                targetId: pane1.id,
                newContent: .terminal(pane2),
                direction: .horizontal
            )
            #expect(result != nil)
            if case .split(let container) = result {
                #expect(container.direction == .horizontal)
                #expect(container.ratio == 0.5)
            } else {
                Issue.record("Expected split result")
            }
        }

        @Test("splitLeaf_수직분할_새컨테이너생성")
        func splitLeaf_vertical_createsNewContainer() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let node = SplitNode.leaf(.terminal(pane1))
            let result = node.splitLeaf(
                targetId: pane1.id,
                newContent: .terminal(pane2),
                direction: .vertical
            )
            #expect(result != nil)
            if case .split(let container) = result {
                #expect(container.direction == .vertical)
            } else {
                Issue.record("Expected split result")
            }
        }

        @Test("splitLeaf_잘못된ID_nil반환")
        func splitLeaf_wrongId_returnsNil() {
            let pane = TerminalPane(id: UUID())
            let node = SplitNode.leaf(.terminal(pane))
            let result = node.splitLeaf(
                targetId: UUID(),
                newContent: .terminal(TerminalPane(id: UUID())),
                direction: .horizontal
            )
            #expect(result == nil)
        }

        @Test("splitLeaf_중첩트리내부_올바른노드분할")
        func splitLeaf_insideNestedTree_splitsCorrectNode() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let pane3 = TerminalPane(id: UUID())
            let container = SplitContainer(
                id: UUID(),
                direction: .horizontal,
                ratio: 0.5,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let root = SplitNode.split(container)
            let result = root.splitLeaf(
                targetId: pane2.id,
                newContent: .terminal(pane3),
                direction: .vertical
            )
            #expect(result != nil)
            // pane2's position should now be a split containing pane2 and pane3
            let leaves = result!.allLeaves()
            #expect(leaves.count == 3)
        }
    }

    // MARK: - SplitNode 닫기 연산

    @Suite("SplitNode - 닫기 연산")
    struct SplitNodeCloseTests {

        @Test("closeLeaf_루트leaf_nil반환")
        func closeLeaf_rootLeaf_returnsNil() {
            let pane = TerminalPane(id: UUID())
            let node = SplitNode.leaf(.terminal(pane))
            let result = node.closeLeaf(targetId: pane.id)
            // .removed means the entire tree is gone
            if case .removed = result {
                // Expected
            } else {
                Issue.record("Expected .removed for closing root leaf")
            }
        }

        @Test("closeLeaf_분할내하나닫기_형제반환")
        func closeLeaf_inSplit_returnsSibling() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let container = SplitContainer(
                id: UUID(),
                direction: .horizontal,
                ratio: 0.5,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let root = SplitNode.split(container)
            let result = root.closeLeaf(targetId: pane1.id)
            if case .updated(let newNode) = result {
                #expect(newNode.id == pane2.id)
                #expect(newNode.isLeaf)
            } else {
                Issue.record("Expected .updated with sibling node")
            }
        }

        @Test("closeLeaf_존재하지않는ID_unchanged반환")
        func closeLeaf_nonExistingId_returnsUnchanged() {
            let pane = TerminalPane(id: UUID())
            let node = SplitNode.leaf(.terminal(pane))
            let result = node.closeLeaf(targetId: UUID())
            if case .unchanged = result {
                // Expected
            } else {
                Issue.record("Expected .unchanged for non-existing ID")
            }
        }

        @Test("closeLeaf_깊은트리에서닫기_부분트리유지")
        func closeLeaf_deepTree_preservesSubtree() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let pane3 = TerminalPane(id: UUID())
            let inner = SplitContainer(
                id: UUID(),
                direction: .horizontal,
                ratio: 0.5,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let root = SplitNode.split(SplitContainer(
                id: UUID(),
                direction: .vertical,
                ratio: 0.5,
                first: .split(inner),
                second: .leaf(.terminal(pane3))
            ))
            let result = root.closeLeaf(targetId: pane1.id)
            if case .updated(let newRoot) = result {
                let leaves = newRoot.allLeaves()
                #expect(leaves.count == 2)
                #expect(leaves.contains(where: { $0.id == pane2.id }))
                #expect(leaves.contains(where: { $0.id == pane3.id }))
            } else {
                Issue.record("Expected .updated")
            }
        }
    }

    // MARK: - SplitNode 리사이즈

    @Suite("SplitNode - 리사이즈")
    struct SplitNodeResizeTests {

        @Test("resize_유효한비율_비율변경")
        func resize_validRatio_changesRatio() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let containerId = UUID()
            let container = SplitContainer(
                id: containerId,
                direction: .horizontal,
                ratio: 0.5,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let node = SplitNode.split(container)
            let result = node.resizeSplit(containerId: containerId, newRatio: 0.7)
            #expect(result != nil)
            if case .split(let c) = result {
                #expect(c.ratio == 0.7)
            } else {
                Issue.record("Expected split node")
            }
        }

        @Test("resize_비율0미만_클램핑")
        func resize_ratioBelow0_clamped() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let containerId = UUID()
            let container = SplitContainer(
                id: containerId,
                direction: .horizontal,
                ratio: 0.5,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let node = SplitNode.split(container)
            let result = node.resizeSplit(containerId: containerId, newRatio: -0.5)
            if case .split(let c) = result {
                #expect(c.ratio >= 0.1)
            } else {
                Issue.record("Expected split node")
            }
        }

        @Test("resize_비율1초과_클램핑")
        func resize_ratioAbove1_clamped() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let containerId = UUID()
            let container = SplitContainer(
                id: containerId,
                direction: .horizontal,
                ratio: 0.5,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let node = SplitNode.split(container)
            let result = node.resizeSplit(containerId: containerId, newRatio: 1.5)
            if case .split(let c) = result {
                #expect(c.ratio <= 0.9)
            } else {
                Issue.record("Expected split node")
            }
        }

        @Test("resize_존재하지않는ID_nil반환")
        func resize_nonExistingId_returnsNil() {
            let pane = TerminalPane(id: UUID())
            let node = SplitNode.leaf(.terminal(pane))
            let result = node.resizeSplit(containerId: UUID(), newRatio: 0.5)
            #expect(result == nil)
        }
    }

    // MARK: - SplitDirection

    @Suite("SplitDirection")
    struct SplitDirectionTests {

        @Test("horizontal_수평방향")
        func horizontal_isHorizontal() {
            let dir = SplitDirection.horizontal
            #expect(dir == .horizontal)
        }

        @Test("vertical_수직방향")
        func vertical_isVertical() {
            let dir = SplitDirection.vertical
            #expect(dir == .vertical)
        }
    }

    // MARK: - 균등 비율 테스트

    @Suite("SplitNode - 균등 비율")
    struct SplitNodeEqualizeTests {

        @Test("equalized_leaf_변경없음")
        func equalized_leaf_unchanged() {
            let pane = TerminalPane(id: UUID())
            let node = SplitNode.leaf(.terminal(pane))
            let result = node.equalized()
            #expect(result.id == pane.id)
            #expect(result.isLeaf)
        }

        @Test("equalized_두패널_비율0점5")
        func equalized_twoPanes_ratioHalf() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let container = SplitContainer(
                id: UUID(),
                direction: .horizontal,
                ratio: 0.7,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let node = SplitNode.split(container)
            let result = node.equalized()
            if case .split(let c) = result {
                #expect(c.ratio == 0.5)
            } else {
                Issue.record("Expected split node")
            }
        }

        @Test("equalized_세패널_균등비율")
        func equalized_threePanes_equalRatios() {
            // 구조: (pane1 | pane2) / pane3
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let pane3 = TerminalPane(id: UUID())
            let inner = SplitContainer(
                id: UUID(),
                direction: .horizontal,
                ratio: 0.3, // 불균등한 비율
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let root = SplitNode.split(SplitContainer(
                id: UUID(),
                direction: .vertical,
                ratio: 0.7, // 불균등한 비율
                first: .split(inner),
                second: .leaf(.terminal(pane3))
            ))
            let result = root.equalized()
            // 루트: 왼쪽 2개, 오른쪽 1개 -> ratio = 2/3
            if case .split(let c) = result {
                #expect(abs(c.ratio - 2.0 / 3.0) < 0.001)
                // 내부: 1:1 -> ratio = 0.5
                if case .split(let inner) = c.first {
                    #expect(inner.ratio == 0.5)
                } else {
                    Issue.record("Expected inner split")
                }
            } else {
                Issue.record("Expected split node")
            }
        }

        @Test("equalized_네패널_균등비율")
        func equalized_fourPanes_equalRatios() {
            // 구조: (pane1 | pane2) / (pane3 | pane4)
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let pane3 = TerminalPane(id: UUID())
            let pane4 = TerminalPane(id: UUID())
            let left = SplitContainer(
                id: UUID(),
                direction: .horizontal,
                ratio: 0.3,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let right = SplitContainer(
                id: UUID(),
                direction: .horizontal,
                ratio: 0.8,
                first: .leaf(.terminal(pane3)),
                second: .leaf(.terminal(pane4))
            )
            let root = SplitNode.split(SplitContainer(
                id: UUID(),
                direction: .vertical,
                ratio: 0.7,
                first: .split(left),
                second: .split(right)
            ))
            let result = root.equalized()
            if case .split(let c) = result {
                // 루트: 2:2 -> ratio = 0.5
                #expect(c.ratio == 0.5)
                // 양쪽 내부: 1:1 -> ratio = 0.5
                if case .split(let l) = c.first {
                    #expect(l.ratio == 0.5)
                }
                if case .split(let r) = c.second {
                    #expect(r.ratio == 0.5)
                }
            } else {
                Issue.record("Expected split node")
            }
        }

        @Test("leafCount_leaf_1반환")
        func leafCount_leaf_returnsOne() {
            let node = SplitNode.leaf(.terminal(TerminalPane(id: UUID())))
            #expect(node.leafCount == 1)
        }

        @Test("leafCount_이진트리_올바른개수")
        func leafCount_binaryTree_correctCount() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let pane3 = TerminalPane(id: UUID())
            let inner = SplitContainer(
                id: UUID(),
                direction: .horizontal,
                ratio: 0.5,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let root = SplitNode.split(SplitContainer(
                id: UUID(),
                direction: .vertical,
                ratio: 0.5,
                first: .split(inner),
                second: .leaf(.terminal(pane3))
            ))
            #expect(root.leafCount == 3)
        }

        @Test("equalized_방향보존")
        func equalized_preservesDirection() {
            let pane1 = TerminalPane(id: UUID())
            let pane2 = TerminalPane(id: UUID())
            let container = SplitContainer(
                id: UUID(),
                direction: .vertical,
                ratio: 0.3,
                first: .leaf(.terminal(pane1)),
                second: .leaf(.terminal(pane2))
            )
            let result = SplitNode.split(container).equalized()
            if case .split(let c) = result {
                #expect(c.direction == .vertical)
            } else {
                Issue.record("Expected split node")
            }
        }
    }

    // MARK: - 경계값 테스트

    @Suite("SplitNode - 경계값")
    struct SplitNodeEdgeCaseTests {

        @Test("ratio_정확히0점5_중앙분할")
        func ratio_exactly05_centerSplit() {
            let container = SplitContainer(
                id: UUID(),
                direction: .horizontal,
                ratio: 0.5,
                first: .leaf(.terminal(TerminalPane(id: UUID()))),
                second: .leaf(.terminal(TerminalPane(id: UUID())))
            )
            #expect(container.ratio == 0.5)
        }

        @Test("깊은중첩_10레벨_정상동작")
        func deepNesting_10Levels_works() {
            var node = SplitNode.leaf(.terminal(TerminalPane(id: UUID())))
            for _ in 0..<10 {
                let newPane = TerminalPane(id: UUID())
                node = SplitNode.split(SplitContainer(
                    id: UUID(),
                    direction: .horizontal,
                    ratio: 0.5,
                    first: node,
                    second: .leaf(.terminal(newPane))
                ))
            }
            let leaves = node.allLeaves()
            #expect(leaves.count == 11)
        }
    }
}
