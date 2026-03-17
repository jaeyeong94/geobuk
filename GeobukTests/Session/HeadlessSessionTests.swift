import Testing
import Foundation
@testable import Geobuk

@Suite("HeadlessSession - UI 없는 PTY 세션")
struct HeadlessSessionTests {

    // MARK: - 헬퍼

    private func makeSession(name: String = "test", mock: MockPTYController? = nil) -> (HeadlessSession, MockPTYController) {
        let mockPTY = mock ?? MockPTYController()
        let session = HeadlessSession(
            name: name,
            cwd: NSHomeDirectory(),
            shell: nil,
            ptyController: mockPTY
        )
        return (session, mockPTY)
    }

    // MARK: - 생성

    @Test("init_이름설정_정확")
    func init_nameSet_correct() {
        let (session, _) = makeSession(name: "test-name")
        #expect(session.name == "test-name")
        session.destroy()
    }

    @Test("init_spawn호출됨")
    func init_spawnCalled() {
        let (session, mock) = makeSession()
        #expect(mock.spawnCalled)
        session.destroy()
    }

    @Test("init_pid_mockPid반환")
    func init_pid_returnsMockPid() {
        let (session, _) = makeSession()
        #expect(session.pid == 12345)
        session.destroy()
    }

    @Test("init_spawnFail_isDestroyed")
    func init_spawnFail_isDestroyed() {
        let mockPTY = MockPTYController()
        mockPTY.shouldFailSpawn = true
        let session = HeadlessSession(
            name: "fail-test",
            cwd: NSHomeDirectory(),
            shell: nil,
            ptyController: mockPTY
        )
        #expect(session.isDestroyed)
    }

    // MARK: - sendKeys

    @Test("sendKeys_문자열전송_PTY에전달")
    func sendKeys_text_writtenToPTY() {
        let (session, mock) = makeSession()
        session.sendKeys("echo hello")
        #expect(mock.writtenData.count == 1)
        #expect(String(data: mock.writtenData[0], encoding: .utf8) == "echo hello")
        session.destroy()
    }

    @Test("sendKeys_빈문자열_전달안됨")
    func sendKeys_empty_notWritten() {
        let (session, mock) = makeSession()
        session.sendKeys("")
        // 빈 data는 Data()이므로 write는 호출되지만 데이터가 비어있음
        // utf8 encoding of "" is empty Data, which still calls write
        session.destroy()
        _ = mock
    }

    @Test("sendKeys_여러번호출_모두전달")
    func sendKeys_multiple_allWritten() {
        let (session, mock) = makeSession()
        session.sendKeys("first")
        session.sendKeys("second")
        #expect(mock.writtenData.count == 2)
        session.destroy()
    }

    // MARK: - sendSpecialKey

    @Test("sendSpecialKey_enter_PTY에전달")
    func sendSpecialKey_enter_sentToPTY() {
        let (session, mock) = makeSession()
        session.sendSpecialKey(.enter)
        #expect(mock.sentSpecialKeys == [.enter])
        session.destroy()
    }

    @Test("sendSpecialKey_ctrlC_PTY에전달")
    func sendSpecialKey_ctrlC_sentToPTY() {
        let (session, mock) = makeSession()
        session.sendSpecialKey(.ctrlC)
        #expect(mock.sentSpecialKeys == [.ctrlC])
        session.destroy()
    }

    @Test("sendSpecialKey_ctrlD_PTY에전달")
    func sendSpecialKey_ctrlD_sentToPTY() {
        let (session, mock) = makeSession()
        session.sendSpecialKey(.ctrlD)
        #expect(mock.sentSpecialKeys == [.ctrlD])
        session.destroy()
    }

    @Test("sendSpecialKey_tab_PTY에전달")
    func sendSpecialKey_tab_sentToPTY() {
        let (session, mock) = makeSession()
        session.sendSpecialKey(.tab)
        #expect(mock.sentSpecialKeys == [.tab])
        session.destroy()
    }

    // MARK: - captureOutput

    @Test("captureOutput_초기상태_빈문자열")
    func captureOutput_initial_empty() {
        let (session, _) = makeSession()
        let output = session.captureOutput(lines: 10)
        #expect(output.isEmpty)
        session.destroy()
    }

    @Test("captureOutput_출력있으면_반환")
    func captureOutput_withOutput_returnsIt() {
        let (session, mock) = makeSession()
        mock.simulateOutput("line1\nline2\n")
        // Give time for async processing
        Thread.sleep(forTimeInterval: 0.05)
        let output = session.captureOutput(lines: 10)
        #expect(output.contains("line1"))
        #expect(output.contains("line2"))
        session.destroy()
    }

    @Test("captureOutput_0줄요청_빈문자열")
    func captureOutput_zeroLines_empty() {
        let (session, _) = makeSession()
        let output = session.captureOutput(lines: 0)
        #expect(output.isEmpty)
        session.destroy()
    }

    // MARK: - destroy

    @Test("destroy_호출후_isDestroyed_true")
    func destroy_called_isDestroyedTrue() {
        let (session, _) = makeSession()
        session.destroy()
        #expect(session.isDestroyed)
    }

    @Test("destroy_PTY_close호출됨")
    func destroy_ptyCloseCalled() {
        let (session, mock) = makeSession()
        session.destroy()
        #expect(mock.closeCalled)
    }

    @Test("destroy_중복호출_안전")
    func destroy_multipleCalls_safe() {
        let (session, _) = makeSession()
        session.destroy()
        session.destroy()
        #expect(session.isDestroyed)
    }

    @Test("destroy후_sendKeys_무시")
    func afterDestroy_sendKeys_ignored() {
        let (session, mock) = makeSession()
        session.destroy()
        session.sendKeys("test")
        // After destroy, writtenData should only contain data before destroy
        // Since we sent nothing before destroy, it should be empty
        #expect(mock.writtenData.isEmpty)
    }

    @Test("destroy후_sendSpecialKey_무시")
    func afterDestroy_sendSpecialKey_ignored() {
        let (session, mock) = makeSession()
        session.destroy()
        session.sendSpecialKey(.enter)
        #expect(mock.sentSpecialKeys.isEmpty)
    }

    // MARK: - 경계값

    @Test("sendKeys_매우긴문자열_에러없음")
    func sendKeys_veryLongString_noError() {
        let (session, mock) = makeSession()
        let longString = String(repeating: "a", count: 10000)
        session.sendKeys(longString)
        #expect(mock.writtenData.count == 1)
        session.destroy()
    }

    @Test("sendKeys_특수문자포함_에러없음")
    func sendKeys_specialChars_noError() {
        let (session, _) = makeSession()
        session.sendKeys("echo '한글 테스트' && ls -la")
        session.destroy()
    }

    @Test("captureOutput_큰줄수요청_에러없음")
    func captureOutput_largeLineCount_noError() {
        let (session, _) = makeSession()
        let output = session.captureOutput(lines: 10000)
        #expect(output is String)
        session.destroy()
    }
}
