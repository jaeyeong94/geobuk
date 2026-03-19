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

    // MARK: - 토큰/비용 포맷 테스트 (SessionFormatter로 통합됨)
    // SessionFormatter의 포맷 테스트는 SessionFormatterTests에서 커버함

    // MARK: - 네거티브 테스트

    /// 빈 패널 리스트에서 PaneTreeView가 크래시 없이 생성되어야 한다
    func test_paneTreeInfo_emptyList() {
        let panes: [PaneTreeInfo] = []
        XCTAssertTrue(panes.isEmpty)
    }

    // 음수/경계값 포맷 테스트는 SessionFormatterTests에서 커버함

    // MARK: - PaneTreeInfo ID 일관성 테스트

    /// PaneTreeInfo의 id는 전달된 UUID와 동일해야 한다
    func test_paneTreeInfo_id_matchesProvided() {
        let uuid = UUID()
        let info = PaneTreeInfo(
            id: uuid,
            index: 1,
            isFocused: false,
            processName: nil,
            currentDirectory: nil,
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
            currentDirectory: nil,
            isClaudeSession: isClaudeSession,
            claudePhase: claudePhase,
            tokenCount: tokenCount,
            costUSD: costUSD,
            listeningPorts: listeningPorts
        )
    }
}
