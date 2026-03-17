import Foundation

/// 세션 에러
enum SessionError: Error, Sendable {
    case sessionAlreadyExists(String)
    case sessionNotFound(String)
    case invalidSessionName
    case invalidSpecialKey(String)
}

/// 세션 정보 (목록 조회용)
struct SessionInfo: Sendable {
    let name: String
    let isHeadless: Bool
    let pid: pid_t
}

/// PTY 컨트롤러 팩토리 타입
typealias PTYControllerFactory = @Sendable () -> PTYControlling

/// 모든 세션 (visual + headless) 관리
@MainActor
@Observable
final class SessionManager {
    private var headlessSessions: [String: HeadlessSession] = [:]

    /// PTY 컨트롤러 팩토리 (테스트 시 mock 주입 가능)
    private let ptyFactory: PTYControllerFactory?

    init(ptyFactory: PTYControllerFactory? = nil) {
        self.ptyFactory = ptyFactory
    }

    // MARK: - 세션 생성

    /// 새 세션 생성
    /// - Parameters:
    ///   - name: 세션 이름 (고유해야 함)
    ///   - cwd: 작업 디렉토리 (nil이면 홈 디렉토리)
    ///   - headless: UI 없는 세션 여부
    /// - Returns: 생성된 세션 이름
    @discardableResult
    func createSession(name: String, cwd: String?, headless: Bool) throws -> String {
        guard !name.isEmpty else {
            throw SessionError.invalidSessionName
        }
        guard headlessSessions[name] == nil else {
            throw SessionError.sessionAlreadyExists(name)
        }

        let ptyController = ptyFactory?()
        let session = HeadlessSession(
            name: name,
            cwd: cwd ?? NSHomeDirectory(),
            shell: nil,
            ptyController: ptyController
        )
        headlessSessions[name] = session
        return name
    }

    // MARK: - 세션 삭제

    /// 세션 삭제
    func destroySession(name: String) throws {
        guard let session = headlessSessions.removeValue(forKey: name) else {
            throw SessionError.sessionNotFound(name)
        }
        session.destroy()
    }

    /// 모든 세션 삭제
    func destroyAllSessions() {
        for (_, session) in headlessSessions {
            session.destroy()
        }
        headlessSessions.removeAll()
    }

    // MARK: - 세션 조회

    /// 세션 가져오기
    func getSession(name: String) -> HeadlessSession? {
        headlessSessions[name]
    }

    /// 세션 존재 여부 확인
    func sessionExists(name: String) -> Bool {
        headlessSessions[name] != nil
    }

    /// 모든 세션 목록
    func listSessions() -> [SessionInfo] {
        headlessSessions.map { (name, session) in
            SessionInfo(name: name, isHeadless: true, pid: session.pid)
        }
    }

    // MARK: - 세션 조작

    /// 세션에 키 전송
    func sendKeys(sessionName: String, text: String) throws {
        guard let session = headlessSessions[sessionName] else {
            throw SessionError.sessionNotFound(sessionName)
        }
        session.sendKeys(text)
    }

    /// 세션에 특수 키 전송
    func sendSpecialKey(sessionName: String, key: String) throws {
        guard let session = headlessSessions[sessionName] else {
            throw SessionError.sessionNotFound(sessionName)
        }
        let specialKey = try parseSpecialKey(key)
        session.sendSpecialKey(specialKey)
    }

    /// 세션 출력 캡처
    func captureOutput(sessionName: String, lines: Int) throws -> String {
        guard let session = headlessSessions[sessionName] else {
            throw SessionError.sessionNotFound(sessionName)
        }
        return session.captureOutput(lines: lines)
    }

    // MARK: - Private

    private func parseSpecialKey(_ key: String) throws -> PTYController.SpecialKey {
        switch key.lowercased() {
        case "enter": return .enter
        case "ctrl-c": return .ctrlC
        case "ctrl-d": return .ctrlD
        case "ctrl-z": return .ctrlZ
        case "tab": return .tab
        default:
            throw SessionError.invalidSpecialKey(key)
        }
    }
}
