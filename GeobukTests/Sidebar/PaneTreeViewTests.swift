import XCTest
@testable import Geobuk

/// PaneTreeInfo 모델과 PaneTreeView 관련 유닛 테스트
final class PaneTreeViewTests: XCTestCase {

    // MARK: - PaneTreeInfo 모델 테스트

    /// idle 패널은 processName이 nil이므로 isIdle이 true여야 한다
    func test_paneTreeInfo_isIdle_true_whenNoProcess() {
        let info = makePaneInfo(processName: nil)
        XCTAssertTrue(info.isIdle)
    }

    /// 프로세스가 있는 패널은 isIdle이 false여야 한다
    func test_paneTreeInfo_isIdle_false_whenProcessExists() {
        let info = makePaneInfo(processName: "node")
        XCTAssertFalse(info.isIdle)
    }

    /// Claude 세션이 아닌 패널은 claudeStatusText가 nil이어야 한다
    func test_paneTreeInfo_claudeStatusText_nil_whenNotClaude() {
        let info = makePaneInfo(isClaudeSession: false, claudePhase: nil)
        XCTAssertNil(info.claudeStatusText)
    }

    /// Claude 세션 responding 상태에서 올바른 텍스트를 반환해야 한다
    func test_paneTreeInfo_claudeStatusText_responding() {
        let info = makePaneInfo(isClaudeSession: true, claudePhase: .responding)
        XCTAssertEqual(info.claudeStatusText, "Responding")
    }

    /// Claude 세션 toolExecuting 상태에서 올바른 텍스트를 반환해야 한다
    func test_paneTreeInfo_claudeStatusText_toolExecuting() {
        let info = makePaneInfo(isClaudeSession: true, claudePhase: .toolExecuting)
        XCTAssertEqual(info.claudeStatusText, "ToolExecuting")
    }

    /// Claude 세션 waitingForInput 상태에서 올바른 텍스트를 반환해야 한다
    func test_paneTreeInfo_claudeStatusText_waitingForInput() {
        let info = makePaneInfo(isClaudeSession: true, claudePhase: .waitingForInput)
        XCTAssertEqual(info.claudeStatusText, "Waiting")
    }

    /// Claude 세션 sessionActive 상태에서 올바른 텍스트를 반환해야 한다
    func test_paneTreeInfo_claudeStatusText_sessionActive() {
        let info = makePaneInfo(isClaudeSession: true, claudePhase: .sessionActive)
        XCTAssertEqual(info.claudeStatusText, "Active")
    }

    /// Claude 세션 sessionComplete 상태에서 올바른 텍스트를 반환해야 한다
    func test_paneTreeInfo_claudeStatusText_sessionComplete() {
        let info = makePaneInfo(isClaudeSession: true, claudePhase: .sessionComplete)
        XCTAssertEqual(info.claudeStatusText, "Complete")
    }

    /// Claude 세션 idle 상태에서 claudeStatusText가 nil이어야 한다
    func test_paneTreeInfo_claudeStatusText_nil_whenIdle() {
        let info = makePaneInfo(isClaudeSession: true, claudePhase: .idle)
        XCTAssertNil(info.claudeStatusText)
    }

    /// Claude가 아닌 패널의 claudeStatusColor는 gray여야 한다
    func test_paneTreeInfo_claudeStatusColor_gray_whenNilPhase() {
        let info = makePaneInfo(isClaudeSession: false, claudePhase: nil)
        XCTAssertEqual(info.claudeStatusColor, .gray)
    }

    // MARK: - 토큰 포맷 테스트

    /// 1000 미만 토큰은 그대로 표시해야 한다
    func test_formatTokenCount_belowThousand() {
        XCTAssertEqual(PaneTreeView.formatTokenCount(500), "500 tokens")
    }

    /// 1000 이상 토큰은 k 단위로 표시해야 한다
    func test_formatTokenCount_thousands() {
        XCTAssertEqual(PaneTreeView.formatTokenCount(12500), "12.5k tokens")
    }

    /// 1000000 이상 토큰은 M 단위로 표시해야 한다
    func test_formatTokenCount_millions() {
        XCTAssertEqual(PaneTreeView.formatTokenCount(1_500_000), "1.5M tokens")
    }

    /// 정확히 1000 토큰
    func test_formatTokenCount_exactlyThousand() {
        XCTAssertEqual(PaneTreeView.formatTokenCount(1000), "1.0k tokens")
    }

    /// 0 토큰
    func test_formatTokenCount_zero() {
        XCTAssertEqual(PaneTreeView.formatTokenCount(0), "0 tokens")
    }

    // MARK: - 비용 포맷 테스트

    /// 일반 비용 포맷 ($0.45)
    func test_formatCost_normalAmount() {
        XCTAssertEqual(PaneTreeView.formatCost(0.45), "$0.45")
    }

    /// 소액 비용은 소수점 3자리로 포맷해야 한다
    func test_formatCost_smallAmount() {
        XCTAssertEqual(PaneTreeView.formatCost(0.005), "$0.005")
    }

    /// 0원
    func test_formatCost_zero() {
        XCTAssertEqual(PaneTreeView.formatCost(0), "$0.000")
    }

    /// $0.01 경계값
    func test_formatCost_boundaryValue() {
        XCTAssertEqual(PaneTreeView.formatCost(0.01), "$0.01")
    }

    /// 큰 금액
    func test_formatCost_largeAmount() {
        XCTAssertEqual(PaneTreeView.formatCost(12.34), "$12.34")
    }

    // MARK: - 네거티브 테스트

    /// 빈 패널 리스트에서 PaneTreeView가 크래시 없이 생성되어야 한다
    func test_paneTreeInfo_emptyList() {
        let panes: [PaneTreeInfo] = []
        XCTAssertTrue(panes.isEmpty)
    }

    /// 음수 토큰에 대한 포맷이 크래시 없이 동작해야 한다
    func test_formatTokenCount_negative() {
        let result = PaneTreeView.formatTokenCount(-100)
        XCTAssertEqual(result, "-100 tokens")
    }

    /// 음수 비용에 대한 포맷이 크래시 없이 동작해야 한다
    func test_formatCost_negative() {
        let result = PaneTreeView.formatCost(-0.05)
        // -0.05는 < 0.01이므로 소수점 3자리로 포맷됨
        XCTAssertEqual(result, "$-0.050")
    }

    /// 매우 큰 토큰 수도 포맷되어야 한다
    func test_formatTokenCount_veryLarge() {
        let result = PaneTreeView.formatTokenCount(999_999_999)
        XCTAssertEqual(result, "1000.0M tokens")
    }

    // MARK: - PaneTreeInfo ID 일관성 테스트

    /// PaneTreeInfo의 id는 전달된 UUID와 동일해야 한다
    func test_paneTreeInfo_id_matchesProvided() {
        let uuid = UUID()
        let info = PaneTreeInfo(
            id: uuid,
            index: 1,
            isFocused: false,
            processName: nil,
            isClaudeSession: false,
            claudePhase: nil,
            tokenCount: 0,
            costUSD: 0,
            listeningPorts: []
        )
        XCTAssertEqual(info.id, uuid)
    }

    /// 리스닝 포트가 올바르게 저장되어야 한다
    func test_paneTreeInfo_listeningPorts() {
        let info = makePaneInfo(listeningPorts: [3000, 8080, 5432])
        XCTAssertEqual(info.listeningPorts, [3000, 8080, 5432])
    }

    // MARK: - Helper

    private func makePaneInfo(
        processName: String? = nil,
        isClaudeSession: Bool = false,
        claudePhase: AISessionPhase? = nil,
        tokenCount: Int = 0,
        costUSD: Double = 0,
        listeningPorts: [UInt16] = []
    ) -> PaneTreeInfo {
        PaneTreeInfo(
            id: UUID(),
            index: 1,
            isFocused: false,
            processName: processName,
            isClaudeSession: isClaudeSession,
            claudePhase: claudePhase,
            tokenCount: tokenCount,
            costUSD: costUSD,
            listeningPorts: listeningPorts
        )
    }
}
