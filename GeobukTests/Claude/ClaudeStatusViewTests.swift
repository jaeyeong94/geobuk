import Testing
import Foundation
@testable import Geobuk

@Suite("ClaudeStatusView - PhaseInfo")
struct ClaudeStatusViewTests {

    // MARK: - 단위 테스트: 페이즈 정보

    @Test("phaseInfo_idle_회색표시")
    func phaseInfo_idle_grayDisplay() {
        let info = PhaseDisplayInfo.from(phase: .idle)
        #expect(info.label == "Idle")
        #expect(info.systemImage == "circle")
        #expect(info.colorName == "gray")
    }

    @Test("phaseInfo_sessionActive_녹색표시")
    func phaseInfo_sessionActive_greenDisplay() {
        let info = PhaseDisplayInfo.from(phase: .sessionActive)
        #expect(info.label == "Session Active")
        #expect(info.colorName == "green")
    }

    @Test("phaseInfo_responding_녹색표시")
    func phaseInfo_responding_greenDisplay() {
        let info = PhaseDisplayInfo.from(phase: .responding)
        #expect(info.label == "Responding")
        #expect(info.colorName == "green")
    }

    @Test("phaseInfo_toolExecuting_파란색표시")
    func phaseInfo_toolExecuting_blueDisplay() {
        let info = PhaseDisplayInfo.from(phase: .toolExecuting)
        #expect(info.label == "Tool Executing")
        #expect(info.colorName == "blue")
    }

    @Test("phaseInfo_waitingForInput_노란색표시")
    func phaseInfo_waitingForInput_yellowDisplay() {
        let info = PhaseDisplayInfo.from(phase: .waitingForInput)
        #expect(info.label == "Waiting for Input")
        #expect(info.colorName == "yellow")
    }

    @Test("phaseInfo_sessionComplete_회색표시")
    func phaseInfo_sessionComplete_grayDisplay() {
        let info = PhaseDisplayInfo.from(phase: .sessionComplete)
        #expect(info.label == "Complete")
        #expect(info.colorName == "gray")
    }

    // MARK: - 네거티브 테스트

    @Test("phaseInfo_모든상태_nilSafe")
    func phaseInfo_allPhases_nilSafe() {
        let allPhases: [AISessionPhase] = [
            .idle, .sessionActive, .responding,
            .toolExecuting, .toolComplete, .waitingForInput, .sessionComplete
        ]
        for phase in allPhases {
            let info = PhaseDisplayInfo.from(phase: phase)
            #expect(!info.label.isEmpty)
            #expect(!info.systemImage.isEmpty)
            #expect(!info.colorName.isEmpty)
        }
    }
}
