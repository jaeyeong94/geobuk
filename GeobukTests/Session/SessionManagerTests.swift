import Testing
import Foundation
@testable import Geobuk

@Suite("SessionManager - 세션 관리")
struct SessionManagerTests {

    /// Mock PTY를 사용하는 SessionManager 생성
    @MainActor
    private func makeManager() -> SessionManager {
        SessionManager(ptyFactory: { MockPTYController() })
    }

    // MARK: - 세션 생성

    @Suite("세션 생성")
    struct CreateTests {

        @MainActor
        private func makeManager() -> SessionManager {
            SessionManager(ptyFactory: { MockPTYController() })
        }

        @Test("headless세션생성_성공")
        @MainActor
        func createHeadlessSession_succeeds() throws {
            let manager = makeManager()
            let name = try manager.createSession(name: "test-session", cwd: nil, headless: true)
            #expect(name == "test-session")
            #expect(manager.sessionExists(name: "test-session"))
            manager.destroyAllSessions()
        }

        @Test("cwd지정_세션생성_성공")
        @MainActor
        func createWithCwd_succeeds() throws {
            let manager = makeManager()
            let name = try manager.createSession(name: "cwd-test", cwd: "/tmp", headless: true)
            #expect(name == "cwd-test")
            manager.destroyAllSessions()
        }

        @Test("중복이름_세션생성_에러")
        @MainActor
        func createDuplicateName_throwsError() throws {
            let manager = makeManager()
            _ = try manager.createSession(name: "dup", cwd: nil, headless: true)
            #expect(throws: SessionError.self) {
                try manager.createSession(name: "dup", cwd: nil, headless: true)
            }
            manager.destroyAllSessions()
        }

        @Test("빈이름_세션생성_에러")
        @MainActor
        func createEmptyName_throwsError() {
            let manager = makeManager()
            #expect(throws: SessionError.self) {
                try manager.createSession(name: "", cwd: nil, headless: true)
            }
        }
    }

    // MARK: - 세션 조회

    @Suite("세션 조회")
    struct QueryTests {

        @MainActor
        private func makeManager() -> SessionManager {
            SessionManager(ptyFactory: { MockPTYController() })
        }

        @Test("존재하는세션_exists_true")
        @MainActor
        func existingSession_exists_true() throws {
            let manager = makeManager()
            _ = try manager.createSession(name: "exists-test", cwd: nil, headless: true)
            #expect(manager.sessionExists(name: "exists-test"))
            manager.destroyAllSessions()
        }

        @Test("존재하지않는세션_exists_false")
        @MainActor
        func nonExistingSession_exists_false() {
            let manager = makeManager()
            #expect(!manager.sessionExists(name: "nonexistent"))
        }

        @Test("getSession_존재하는세션_반환")
        @MainActor
        func getSession_existing_returnsSession() throws {
            let manager = makeManager()
            _ = try manager.createSession(name: "get-test", cwd: nil, headless: true)
            let session = manager.getSession(name: "get-test")
            #expect(session != nil)
            #expect(session?.name == "get-test")
            manager.destroyAllSessions()
        }

        @Test("getSession_존재하지않는세션_nil")
        @MainActor
        func getSession_nonExisting_returnsNil() {
            let manager = makeManager()
            let session = manager.getSession(name: "nope")
            #expect(session == nil)
        }

        @Test("listSessions_빈목록_빈배열")
        @MainActor
        func listSessions_empty_returnsEmptyArray() {
            let manager = makeManager()
            let sessions = manager.listSessions()
            #expect(sessions.isEmpty)
        }

        @Test("listSessions_여러세션_모두반환")
        @MainActor
        func listSessions_multiple_returnsAll() throws {
            let manager = makeManager()
            _ = try manager.createSession(name: "s1", cwd: nil, headless: true)
            _ = try manager.createSession(name: "s2", cwd: nil, headless: true)
            let sessions = manager.listSessions()
            #expect(sessions.count == 2)
            let names = sessions.map(\.name).sorted()
            #expect(names == ["s1", "s2"])
            manager.destroyAllSessions()
        }
    }

    // MARK: - 세션 삭제

    @Suite("세션 삭제")
    struct DestroyTests {

        @MainActor
        private func makeManager() -> SessionManager {
            SessionManager(ptyFactory: { MockPTYController() })
        }

        @Test("존재하는세션_삭제_성공")
        @MainActor
        func destroyExisting_succeeds() throws {
            let manager = makeManager()
            _ = try manager.createSession(name: "destroy-test", cwd: nil, headless: true)
            try manager.destroySession(name: "destroy-test")
            #expect(!manager.sessionExists(name: "destroy-test"))
        }

        @Test("존재하지않는세션_삭제_에러")
        @MainActor
        func destroyNonExisting_throwsError() {
            let manager = makeManager()
            #expect(throws: SessionError.self) {
                try manager.destroySession(name: "ghost")
            }
        }

        @Test("삭제후_같은이름재생성_성공")
        @MainActor
        func destroyThenRecreate_succeeds() throws {
            let manager = makeManager()
            _ = try manager.createSession(name: "reuse", cwd: nil, headless: true)
            try manager.destroySession(name: "reuse")
            _ = try manager.createSession(name: "reuse", cwd: nil, headless: true)
            #expect(manager.sessionExists(name: "reuse"))
            manager.destroyAllSessions()
        }
    }

    // MARK: - sendKeys

    @Suite("sendKeys")
    struct SendKeysTests {

        @MainActor
        private func makeManager() -> SessionManager {
            SessionManager(ptyFactory: { MockPTYController() })
        }

        @Test("존재하는세션_sendKeys_에러없음")
        @MainActor
        func sendKeysExisting_noError() throws {
            let manager = makeManager()
            _ = try manager.createSession(name: "keys-test", cwd: nil, headless: true)
            try manager.sendKeys(sessionName: "keys-test", text: "echo hello\n")
            manager.destroyAllSessions()
        }

        @Test("존재하지않는세션_sendKeys_에러")
        @MainActor
        func sendKeysNonExisting_throwsError() {
            let manager = makeManager()
            #expect(throws: SessionError.self) {
                try manager.sendKeys(sessionName: "no-session", text: "test")
            }
        }
    }

    // MARK: - sendSpecialKey

    @Suite("sendSpecialKey")
    struct SendSpecialKeyTests {

        @MainActor
        private func makeManager() -> SessionManager {
            SessionManager(ptyFactory: { MockPTYController() })
        }

        @Test("유효한키_전송_에러없음")
        @MainActor
        func validKey_noError() throws {
            let manager = makeManager()
            _ = try manager.createSession(name: "special-test", cwd: nil, headless: true)
            try manager.sendSpecialKey(sessionName: "special-test", key: "enter")
            try manager.sendSpecialKey(sessionName: "special-test", key: "ctrl-c")
            try manager.sendSpecialKey(sessionName: "special-test", key: "ctrl-d")
            try manager.sendSpecialKey(sessionName: "special-test", key: "tab")
            manager.destroyAllSessions()
        }

        @Test("잘못된키_전송_에러")
        @MainActor
        func invalidKey_throwsError() throws {
            let manager = makeManager()
            _ = try manager.createSession(name: "bad-key-test", cwd: nil, headless: true)
            #expect(throws: SessionError.self) {
                try manager.sendSpecialKey(sessionName: "bad-key-test", key: "invalid-key")
            }
            manager.destroyAllSessions()
        }

        @Test("존재하지않는세션_specialKey_에러")
        @MainActor
        func nonExistingSession_throwsError() {
            let manager = makeManager()
            #expect(throws: SessionError.self) {
                try manager.sendSpecialKey(sessionName: "none", key: "enter")
            }
        }
    }

    // MARK: - captureOutput

    @Suite("captureOutput")
    struct CaptureOutputTests {

        @MainActor
        private func makeManager() -> SessionManager {
            SessionManager(ptyFactory: { MockPTYController() })
        }

        @Test("존재하는세션_captureOutput_문자열반환")
        @MainActor
        func captureExisting_returnsString() throws {
            let manager = makeManager()
            _ = try manager.createSession(name: "capture-test", cwd: nil, headless: true)
            let output = try manager.captureOutput(sessionName: "capture-test", lines: 10)
            #expect(output is String)
            manager.destroyAllSessions()
        }

        @Test("존재하지않는세션_captureOutput_에러")
        @MainActor
        func captureNonExisting_throwsError() {
            let manager = makeManager()
            #expect(throws: SessionError.self) {
                try manager.captureOutput(sessionName: "no-session", lines: 10)
            }
        }
    }

    // MARK: - destroyAllSessions

    @Suite("destroyAllSessions")
    struct DestroyAllTests {

        @MainActor
        private func makeManager() -> SessionManager {
            SessionManager(ptyFactory: { MockPTYController() })
        }

        @Test("모든세션삭제_목록비어짐")
        @MainActor
        func destroyAll_listsEmpty() throws {
            let manager = makeManager()
            _ = try manager.createSession(name: "a", cwd: nil, headless: true)
            _ = try manager.createSession(name: "b", cwd: nil, headless: true)
            manager.destroyAllSessions()
            #expect(manager.listSessions().isEmpty)
        }
    }
}
