import Testing
import Foundation
@testable import Geobuk

@Suite("SplitTreeManager - 상태 관리")
@MainActor
struct SplitTreeManagerTests {

    // MARK: - 초기화

    @Test("init_초기상태_단일leaf")
    func init_initialState_singleLeaf() {
        let manager = SplitTreeManager()
        #expect(manager.root.isLeaf)
        #expect(manager.focusedPaneId != nil)
    }

    @Test("init_포커스ID_루트pane의ID")
    func init_focusedId_matchesRootPaneId() {
        let manager = SplitTreeManager()
        #expect(manager.focusedPaneId == manager.root.id)
    }

    // MARK: - 분할

    @Test("splitFocused_수평분할_두패널생성")
    func splitFocused_horizontal_createsTwoPanes() {
        let manager = SplitTreeManager()
        let originalId = manager.focusedPaneId
        manager.splitFocusedPane(direction: .horizontal)

        #expect(!manager.root.isLeaf)
        let leaves = manager.root.allLeaves()
        #expect(leaves.count == 2)
        // 원래 패널이 여전히 존재
        #expect(leaves.contains(where: { $0.id == originalId }))
    }

    @Test("splitFocused_수직분할_두패널생성")
    func splitFocused_vertical_createsTwoPanes() {
        let manager = SplitTreeManager()
        manager.splitFocusedPane(direction: .vertical)

        #expect(!manager.root.isLeaf)
        let leaves = manager.root.allLeaves()
        #expect(leaves.count == 2)
    }

    @Test("splitFocused_포커스_새패널로이동")
    func splitFocused_focus_movesToNewPane() {
        let manager = SplitTreeManager()
        let originalId = manager.focusedPaneId
        manager.splitFocusedPane(direction: .horizontal)

        // 포커스가 새 패널로 이동해야 함
        #expect(manager.focusedPaneId != originalId)
    }

    @Test("splitFocused_연속분할_세패널생성")
    func splitFocused_consecutiveSplits_createsThreePanes() {
        let manager = SplitTreeManager()
        manager.splitFocusedPane(direction: .horizontal)
        manager.splitFocusedPane(direction: .vertical)

        let leaves = manager.root.allLeaves()
        #expect(leaves.count == 3)
    }

    // MARK: - 닫기

    @Test("closeFocused_마지막패널_아무일안함")
    func closeFocused_lastPane_doesNothing() {
        let manager = SplitTreeManager()
        let originalId = manager.focusedPaneId
        manager.closeFocusedPane()

        // 마지막 패널은 닫히지 않아야 함
        #expect(manager.root.isLeaf)
        #expect(manager.focusedPaneId == originalId)
    }

    @Test("closeFocused_두패널중하나_하나남음")
    func closeFocused_oneOfTwo_oneRemains() {
        let manager = SplitTreeManager()
        let originalId = manager.focusedPaneId
        manager.splitFocusedPane(direction: .horizontal)
        manager.closeFocusedPane()

        #expect(manager.root.isLeaf)
        // 포커스가 남은 패널로 이동
        #expect(manager.focusedPaneId == originalId)
    }

    @Test("closeFocused_세패널중하나_두개남음")
    func closeFocused_oneOfThree_twoRemain() {
        let manager = SplitTreeManager()
        manager.splitFocusedPane(direction: .horizontal)
        manager.splitFocusedPane(direction: .vertical)
        manager.closeFocusedPane()

        let leaves = manager.root.allLeaves()
        #expect(leaves.count == 2)
    }

    // MARK: - 포커스 네비게이션

    @Test("focusNext_두패널_다음패널포커스")
    func focusNext_twoPanes_focusesNext() {
        let manager = SplitTreeManager()
        let firstId = manager.focusedPaneId
        manager.splitFocusedPane(direction: .horizontal)
        let secondId = manager.focusedPaneId

        // 현재 secondId에 포커스, next하면 firstId로
        manager.focusNextPane()
        #expect(manager.focusedPaneId == firstId)

        // 다시 next하면 secondId로 순환
        manager.focusNextPane()
        #expect(manager.focusedPaneId == secondId)
    }

    @Test("focusPrevious_두패널_이전패널포커스")
    func focusPrevious_twoPanes_focusesPrevious() {
        let manager = SplitTreeManager()
        let firstId = manager.focusedPaneId
        manager.splitFocusedPane(direction: .horizontal)
        let secondId = manager.focusedPaneId

        manager.focusPreviousPane()
        #expect(manager.focusedPaneId == firstId)

        manager.focusPreviousPane()
        #expect(manager.focusedPaneId == secondId)
    }

    @Test("focusNext_단일패널_포커스유지")
    func focusNext_singlePane_keepsFocus() {
        let manager = SplitTreeManager()
        let originalId = manager.focusedPaneId
        manager.focusNextPane()
        #expect(manager.focusedPaneId == originalId)
    }

    @Test("setFocus_유효ID_포커스변경")
    func setFocus_validId_changesFocus() {
        let manager = SplitTreeManager()
        let firstId = manager.focusedPaneId
        manager.splitFocusedPane(direction: .horizontal)

        manager.setFocusedPane(id: firstId!)
        #expect(manager.focusedPaneId == firstId)
    }

    @Test("setFocus_유효하지않은ID_포커스유지")
    func setFocus_invalidId_keepsFocus() {
        let manager = SplitTreeManager()
        let originalId = manager.focusedPaneId
        manager.setFocusedPane(id: UUID())
        #expect(manager.focusedPaneId == originalId)
    }

    // MARK: - Undo/Redo

    @Test("undo_분할후_원래상태복원")
    func undo_afterSplit_restoresOriginal() {
        let manager = SplitTreeManager()
        let originalId = manager.focusedPaneId

        manager.splitFocusedPane(direction: .horizontal)
        #expect(manager.root.allLeaves().count == 2)

        manager.undo()
        #expect(manager.root.isLeaf)
        #expect(manager.focusedPaneId == originalId)
    }

    @Test("redo_undo후_분할상태복원")
    func redo_afterUndo_restoresSplit() {
        let manager = SplitTreeManager()

        manager.splitFocusedPane(direction: .horizontal)
        let splitLeafCount = manager.root.allLeaves().count

        manager.undo()
        #expect(manager.root.isLeaf)

        manager.redo()
        #expect(manager.root.allLeaves().count == splitLeafCount)
    }

    @Test("undo_초기상태에서_아무일안함")
    func undo_atInitialState_doesNothing() {
        let manager = SplitTreeManager()
        let originalId = manager.focusedPaneId
        manager.undo()
        #expect(manager.root.isLeaf)
        #expect(manager.focusedPaneId == originalId)
    }

    @Test("redo_redo없을때_아무일안함")
    func redo_nothingToRedo_doesNothing() {
        let manager = SplitTreeManager()
        manager.redo()
        #expect(manager.root.isLeaf)
    }

    @Test("undo_새작업후_redo스택초기화")
    func undo_newActionAfterUndo_clearsRedoStack() {
        let manager = SplitTreeManager()

        manager.splitFocusedPane(direction: .horizontal)
        manager.undo()
        // 이제 redo 가능한 상태

        manager.splitFocusedPane(direction: .vertical)
        // 새 작업 후에는 redo가 안되어야 함
        manager.redo()
        // redo가 없으므로 현재 상태 유지
        #expect(manager.root.allLeaves().count == 2)
    }

    @Test("undo_연속작업_순서대로복원")
    func undo_multipleActions_restoresInOrder() {
        let manager = SplitTreeManager()

        manager.splitFocusedPane(direction: .horizontal)
        #expect(manager.root.allLeaves().count == 2)

        manager.splitFocusedPane(direction: .vertical)
        #expect(manager.root.allLeaves().count == 3)

        manager.undo()
        #expect(manager.root.allLeaves().count == 2)

        manager.undo()
        #expect(manager.root.allLeaves().count == 1)
    }

    // MARK: - 리사이즈

    @Test("resize_유효한컨테이너_비율변경")
    func resize_validContainer_changesRatio() {
        let manager = SplitTreeManager()
        manager.splitFocusedPane(direction: .horizontal)

        if case .split(let container) = manager.root {
            manager.resizeSplit(containerId: container.id, ratio: 0.7)
            if case .split(let updated) = manager.root {
                #expect(updated.ratio == 0.7)
            } else {
                Issue.record("Expected split after resize")
            }
        } else {
            Issue.record("Expected split node")
        }
    }

    @Test("resize_존재하지않는컨테이너_변경없음")
    func resize_nonExistingContainer_noChange() {
        let manager = SplitTreeManager()
        manager.splitFocusedPane(direction: .horizontal)
        let before = manager.root
        manager.resizeSplit(containerId: UUID(), ratio: 0.7)
        // root should be unchanged
        #expect(manager.root.id == before.id)
    }

    // MARK: - canUndo / canRedo

    @Test("canUndo_초기상태_false")
    func canUndo_initialState_false() {
        let manager = SplitTreeManager()
        #expect(!manager.canUndo)
    }

    @Test("canRedo_초기상태_false")
    func canRedo_initialState_false() {
        let manager = SplitTreeManager()
        #expect(!manager.canRedo)
    }

    @Test("canUndo_분할후_true")
    func canUndo_afterSplit_true() {
        let manager = SplitTreeManager()
        manager.splitFocusedPane(direction: .horizontal)
        #expect(manager.canUndo)
    }

    @Test("canRedo_undo후_true")
    func canRedo_afterUndo_true() {
        let manager = SplitTreeManager()
        manager.splitFocusedPane(direction: .horizontal)
        manager.undo()
        #expect(manager.canRedo)
    }

    // MARK: - 최대화

    @Test("toggleMaximize_복수패널_최대화토글")
    func toggleMaximize_multiplePanes_toggles() {
        let manager = SplitTreeManager()
        manager.splitFocusedPane(direction: .horizontal)

        #expect(!manager.isMaximized)
        manager.toggleMaximize()
        #expect(manager.isMaximized)
        manager.toggleMaximize()
        #expect(!manager.isMaximized)
    }

    @Test("toggleMaximize_단일패널_토글안됨")
    func toggleMaximize_singlePane_doesNotToggle() {
        let manager = SplitTreeManager()
        manager.toggleMaximize()
        #expect(!manager.isMaximized)
    }

    @Test("toggleMaximize_패널닫아하나남으면_최대화해제")
    func toggleMaximize_closePaneToOne_resetsMaximize() {
        let manager = SplitTreeManager()
        manager.splitFocusedPane(direction: .horizontal)
        manager.toggleMaximize()
        #expect(manager.isMaximized)

        manager.closeFocusedPane()
        #expect(!manager.isMaximized)
    }

    // MARK: - 균등 분할

    @Test("splitFocused_연속분할_균등비율적용")
    func splitFocused_consecutiveSplits_equalizedRatios() {
        let manager = SplitTreeManager()
        manager.splitFocusedPane(direction: .horizontal)

        // 첫 번째 분할 후: 2패널 -> ratio = 0.5
        if case .split(let c) = manager.root {
            #expect(c.ratio == 0.5)
        }

        // 두 번째 패널 포커스 상태에서 다시 분할
        manager.splitFocusedPane(direction: .horizontal)
        // 3패널: 루트는 첫번째(1) : 두번째컨테이너(2) -> ratio = 1/3
        // 내부 컨테이너: 1:1 -> ratio = 0.5
        let leaves = manager.root.allLeaves()
        #expect(leaves.count == 3)
    }

    // MARK: - paneCount

    @Test("paneCount_초기_1")
    func paneCount_initial_one() {
        let manager = SplitTreeManager()
        #expect(manager.paneCount == 1)
    }

    @Test("paneCount_분할후_2")
    func paneCount_afterSplit_two() {
        let manager = SplitTreeManager()
        manager.splitFocusedPane(direction: .horizontal)
        #expect(manager.paneCount == 2)
    }
}
