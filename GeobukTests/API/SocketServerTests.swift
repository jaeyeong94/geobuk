import Testing
import Foundation
@testable import Geobuk

@Suite("SocketServer - Unix 도메인 소켓 서버")
struct SocketServerTests {

    // MARK: - 헬퍼

    private func tempSocketPath() -> String {
        let dir = NSTemporaryDirectory()
        return "\(dir)geobuk-test-\(UUID().uuidString).sock"
    }

    @MainActor
    private func makeServer(path: String) -> SocketServer {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        return SocketServer(socketPath: path, sessionManager: manager)
    }

    // MARK: - 시작/중지

    @Test("start_소켓파일생성")
    @MainActor
    func start_createsSocketFile() async throws {
        let path = tempSocketPath()
        let server = makeServer(path: path)
        try await server.start()

        let exists = FileManager.default.fileExists(atPath: path)
        #expect(exists)

        await server.stop()
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("stop_소켓파일제거")
    @MainActor
    func stop_removesSocketFile() async throws {
        let path = tempSocketPath()
        let server = makeServer(path: path)
        try await server.start()
        await server.stop()

        let exists = FileManager.default.fileExists(atPath: path)
        #expect(!exists)
    }

    @Test("start_이미실행중_에러")
    @MainActor
    func start_alreadyRunning_throwsError() async throws {
        let path = tempSocketPath()
        let server = makeServer(path: path)
        try await server.start()

        do {
            try await server.start()
            Issue.record("Expected error for double start")
        } catch {
            // Expected
        }

        await server.stop()
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("stop_미실행_안전")
    @MainActor
    func stop_notRunning_safe() async {
        let path = tempSocketPath()
        let server = makeServer(path: path)
        await server.stop()
        // Should not crash
    }

    // MARK: - 연결 테스트

    @Test("클라이언트연결_수락됨")
    @MainActor
    func clientConnect_accepted() async throws {
        let path = tempSocketPath()
        let server = makeServer(path: path)
        try await server.start()

        // Create a client socket and connect
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

        Darwin.close(clientFd)
        await server.stop()
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - JSON-RPC 통합 테스트

    @Test("JSON-RPC요청_응답수신")
    @MainActor
    func jsonRpcRequest_receivesResponse() async throws {
        let path = tempSocketPath()
        let sessionManager = SessionManager(ptyFactory: { MockPTYController() })
        let server = SocketServer(socketPath: path, sessionManager: sessionManager)
        try await server.start()

        // Connect client
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

        // Send session.list request
        let request = "{\"jsonrpc\":\"2.0\",\"method\":\"session.list\",\"id\":1}\n"
        request.withCString { ptr in
            _ = Darwin.write(clientFd, ptr, request.utf8.count)
        }

        // Read response (with timeout)
        try await Task.sleep(for: .milliseconds(200))
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = Darwin.read(clientFd, &buffer, buffer.count)

        #expect(bytesRead > 0)
        if bytesRead > 0 {
            let responseStr = String(bytes: buffer[0..<bytesRead], encoding: .utf8)!
            #expect(responseStr.contains("jsonrpc"))
            #expect(responseStr.contains("2.0"))
        }

        Darwin.close(clientFd)
        await server.stop()
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - 소켓 경로

    @Test("기본소켓경로_ApplicationSupport")
    func defaultSocketPath_inAppSupport() {
        let path = SocketServer.defaultSocketPath
        #expect(path.contains("Application Support/Geobuk/geobuk.sock"))
    }

    // MARK: - 네거티브 테스트

    @Test("잘못된소켓경로_start실패")
    @MainActor
    func invalidSocketPath_startFails() async {
        let manager = SessionManager(ptyFactory: { MockPTYController() })
        let server = SocketServer(socketPath: "/nonexistent/dir/test.sock", sessionManager: manager)
        do {
            try await server.start()
            Issue.record("Expected error for invalid path")
            await server.stop()
        } catch {
            // Expected
        }
    }
}
