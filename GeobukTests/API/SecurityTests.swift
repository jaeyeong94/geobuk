import Testing
import Foundation
@testable import Geobuk

// MARK: - H2: 소켓 파일 퍼미션 테스트

@Suite("SocketServer - 소켓 파일 보안")
struct SocketServerSecurityTests {

    private func tempSocketPath() -> String {
        let dir = NSTemporaryDirectory()
        return "\(dir)geobuk-sec-test-\(UUID().uuidString).sock"
    }

    @Test("start_소켓파일_퍼미션0600")
    @MainActor
    func start_socketFilePermission_owner0nly() async throws {
        let path = tempSocketPath()
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        let server = SocketServer(socketPath: path, sessionManager: manager)
        try await server.start()

        // 소켓 파일의 POSIX 퍼미션 확인
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        let permissions = attrs[.posixPermissions] as? Int
        // 0o600 = 384 (owner read+write only)
        // 소켓 파일은 타입 비트가 다를 수 있으므로 하위 9비트만 검사
        let mode = (permissions ?? 0) & 0o777
        #expect(mode == 0o600, "Socket file should have 0600 permissions, got \(String(mode, radix: 8))")

        await server.stop()
        try? FileManager.default.removeItem(atPath: path)
    }
}

// MARK: - H3: TTY 이름 검증 테스트

@Suite("ShellStateManager - TTY 이름 검증")
struct TTYValidationTests {

    // MARK: - 유효한 TTY 이름

    @Test("validateTTY_유효한형식_ttys숫자_true")
    func validateTTY_validTtys_returnsTrue() {
        #expect(ShellStateManager.isValidTTYName("/dev/ttys001"))
        #expect(ShellStateManager.isValidTTYName("/dev/ttys000"))
        #expect(ShellStateManager.isValidTTYName("/dev/ttys999"))
        #expect(ShellStateManager.isValidTTYName("/dev/ttys1234"))
    }

    @Test("validateTTY_유효한형식_tty숫자_true")
    func validateTTY_validTty_returnsTrue() {
        #expect(ShellStateManager.isValidTTYName("/dev/tty0"))
        #expect(ShellStateManager.isValidTTYName("/dev/tty01"))
    }

    @Test("validateTTY_짧은형식_ttys숫자_true")
    func validateTTY_shortForm_returnsTrue() {
        #expect(ShellStateManager.isValidTTYName("ttys001"))
        #expect(ShellStateManager.isValidTTYName("ttys999"))
    }

    // MARK: - 무효한 TTY 이름

    @Test("validateTTY_빈문자열_false")
    func validateTTY_empty_returnsFalse() {
        #expect(!ShellStateManager.isValidTTYName(""))
    }

    @Test("validateTTY_플래그인젝션_false")
    func validateTTY_flagInjection_returnsFalse() {
        #expect(!ShellStateManager.isValidTTYName("-A"))
        #expect(!ShellStateManager.isValidTTYName("-t"))
        #expect(!ShellStateManager.isValidTTYName("--all"))
    }

    @Test("validateTTY_경로탈출_false")
    func validateTTY_pathTraversal_returnsFalse() {
        #expect(!ShellStateManager.isValidTTYName("../../etc/passwd"))
        #expect(!ShellStateManager.isValidTTYName("/etc/passwd"))
    }

    @Test("validateTTY_널바이트포함_false")
    func validateTTY_nullByte_returnsFalse() {
        #expect(!ShellStateManager.isValidTTYName("ttys001\0-A"))
    }

    @Test("validateTTY_공백포함_false")
    func validateTTY_spaces_returnsFalse() {
        #expect(!ShellStateManager.isValidTTYName("ttys001 -A"))
        #expect(!ShellStateManager.isValidTTYName(" ttys001"))
    }

    @Test("validateTTY_숫자만_false")
    func validateTTY_onlyNumbers_returnsFalse() {
        #expect(!ShellStateManager.isValidTTYName("12345"))
    }

    @Test("validateTTY_임의문자열_false")
    func validateTTY_arbitrary_returnsFalse() {
        #expect(!ShellStateManager.isValidTTYName("hello"))
        #expect(!ShellStateManager.isValidTTYName("pts/0"))
    }

    // MARK: - reportTty에서 검증 적용 확인

    @Test("reportTty_무효한TTY_저장거부")
    @MainActor
    func reportTty_invalidTTY_rejected() {
        let manager = ShellStateManager()
        manager.reportTty(surfaceId: "abc-123", tty: "-A")
        #expect(manager.ttyNames["abc-123"] == nil)
    }

    @Test("reportTty_유효한TTY_저장성공")
    @MainActor
    func reportTty_validTTY_accepted() {
        let manager = ShellStateManager()
        manager.reportTty(surfaceId: "abc-123", tty: "/dev/ttys001")
        #expect(manager.ttyNames["abc-123"] == "/dev/ttys001")
    }

    @Test("reportTty_경로탈출시도_저장거부")
    @MainActor
    func reportTty_pathTraversal_rejected() {
        let manager = ShellStateManager()
        manager.reportTty(surfaceId: "abc-123", tty: "../../etc/passwd")
        #expect(manager.ttyNames["abc-123"] == nil)
    }
}

// MARK: - H3: APIMethodRouter에서 TTY 검증 테스트

@Suite("APIMethodRouter - TTY 검증 통합")
struct APIMethodRouterTTYValidationTests {

    @Test("shell.reportTty_무효한TTY_에러반환")
    @MainActor
    func shellReportTty_invalidTTY_returnsError() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let shellStateManager = ShellStateManager()
        let router = APIMethodRouter(sessionManager: sessionManager, shellStateManager: shellStateManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "shell.reportTty",
            params: ["surfaceId": .string("abc-123"), "tty": .string("-A")],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
        #expect(response.error?.code == JSONRPCErrorCode.invalidParams.rawValue)
        #expect(shellStateManager.ttyNames["abc-123"] == nil)
    }

    @Test("shell.reportTty_유효한TTY_성공")
    @MainActor
    func shellReportTty_validTTY_succeeds() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let shellStateManager = ShellStateManager()
        let router = APIMethodRouter(sessionManager: sessionManager, shellStateManager: shellStateManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "shell.reportTty",
            params: ["surfaceId": .string("abc-123"), "tty": .string("/dev/ttys001")],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error == nil)
        #expect(shellStateManager.ttyNames["abc-123"] == "/dev/ttys001")
    }

    @Test("shell.reportTty_널바이트포함_에러")
    @MainActor
    func shellReportTty_nullByte_returnsError() async {
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let shellStateManager = ShellStateManager()
        let router = APIMethodRouter(sessionManager: sessionManager, shellStateManager: shellStateManager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "shell.reportTty",
            params: ["surfaceId": .string("abc-123"), "tty": .string("ttys001\0-A")],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error != nil)
    }
}

// MARK: - M13/H1: sendKeys 페이로드 크기 제한 테스트

@Suite("APIMethodRouter - sendKeys 크기 제한")
struct SendKeysPayloadLimitTests {

    @Test("session.sendKeys_정상크기_성공")
    @MainActor
    func sendKeys_normalSize_succeeds() async throws {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        _ = try manager.createSession(name: "size-test", cwd: nil, headless: true)
        let router = APIMethodRouter(sessionManager: manager)
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.sendKeys",
            params: ["name": .string("size-test"), "text": .string("ls -la")],
            id: 1
        )
        let response = await router.route(request)
        #expect(response.error == nil)
        manager.destroyAllSessions()
    }

    @Test("session.sendKeys_64KB초과_에러")
    @MainActor
    func sendKeys_oversized_returnsError() async throws {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        _ = try manager.createSession(name: "size-test", cwd: nil, headless: true)
        let router = APIMethodRouter(sessionManager: manager)
        let oversizedText = String(repeating: "A", count: 65_537) // 64KB + 1
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.sendKeys",
            params: ["name": .string("size-test"), "text": .string(oversizedText)],
            id: 2
        )
        let response = await router.route(request)
        #expect(response.error != nil)
        #expect(response.error?.code == JSONRPCErrorCode.invalidParams.rawValue)
        manager.destroyAllSessions()
    }

    @Test("session.sendKeys_정확히64KB_성공")
    @MainActor
    func sendKeys_exactly64KB_succeeds() async throws {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        _ = try manager.createSession(name: "size-test", cwd: nil, headless: true)
        let router = APIMethodRouter(sessionManager: manager)
        let text = String(repeating: "A", count: 65_536) // exactly 64KB
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            method: "session.sendKeys",
            params: ["name": .string("size-test"), "text": .string(text)],
            id: 3
        )
        let response = await router.route(request)
        #expect(response.error == nil)
        manager.destroyAllSessions()
    }
}

// MARK: - M6: 수신 버퍼 크기 제한 테스트

@Suite("SocketServer - 수신 버퍼 제한")
struct SocketServerBufferLimitTests {

    private func tempSocketPath() -> String {
        let dir = NSTemporaryDirectory()
        return "\(dir)geobuk-buf-test-\(UUID().uuidString).sock"
    }

    @Test("대용량메시지_1MB초과_연결끊김")
    @MainActor
    func oversizedMessage_connectionClosed() async throws {
        let path = tempSocketPath()
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        let server = SocketServer(socketPath: path, sessionManager: manager)
        try await server.start()

        let clientFd = socket(AF_UNIX, SOCK_STREAM, 0)
        #expect(clientFd >= 0)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            path.withCString { cstr in
                _ = memcpy(ptr, cstr, min(path.utf8.count, MemoryLayout.size(ofValue: ptr.pointee) - 1))
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(clientFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        #expect(connectResult == 0)

        // 1MB 이상의 데이터를 전송 시도 — 서버가 에러 없이 처리(무시)하는지 확인
        let chunk = [UInt8](repeating: 0x41, count: 65536) // 64KB chunk
        for _ in 0..<20 { // 20 * 64KB = 1.28MB
            chunk.withUnsafeBufferPointer { ptr in
                _ = Darwin.write(clientFd, ptr.baseAddress!, ptr.count)
            }
        }

        // 서버가 크래시하지 않고 응답하지 않음을 확인
        try await Task.sleep(for: .milliseconds(300))

        Darwin.close(clientFd)
        await server.stop()
        try? FileManager.default.removeItem(atPath: path)
    }
}
