import Foundation

/// Unix domain socket 서버 (JSON-RPC 2.0)
/// 소켓 경로: ~/Library/Application Support/Geobuk/geobuk.sock
actor SocketServer {
    /// 소켓 파일 경로
    let socketPath: String

    /// 서버 소켓 fd
    private var serverFd: Int32 = -1

    /// 실행 중 여부
    private var isRunning = false

    /// 연결된 클라이언트 fd 목록
    private var clientFds: Set<Int32> = []

    /// 세션 매니저 참조 (MainActor 격리)
    private let sessionManager: SessionManager

    /// 셸 상태 매니저 참조 (MainActor 격리)
    private let shellStateManager: ShellStateManager?

    /// accept 루프 태스크
    private var acceptTask: Task<Void, Never>?

    // MARK: - Init

    /// 소켓 경로와 세션 매니저를 지정하여 생성
    init(socketPath: String, sessionManager: SessionManager, shellStateManager: ShellStateManager? = nil) {
        self.socketPath = socketPath
        self.sessionManager = sessionManager
        self.shellStateManager = shellStateManager
    }

    /// 세션 매니저만 지정하여 생성 (기본 소켓 경로 사용)
    init(sessionManager: SessionManager, shellStateManager: ShellStateManager? = nil) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let geobukDir = appSupport.appendingPathComponent("Geobuk")
        self.socketPath = geobukDir.appendingPathComponent("geobuk.sock").path
        self.sessionManager = sessionManager
        self.shellStateManager = shellStateManager
    }

    /// 기본 소켓 경로를 반환하는 정적 헬퍼
    static var defaultSocketPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let geobukDir = appSupport.appendingPathComponent("Geobuk")
        return geobukDir.appendingPathComponent("geobuk.sock").path
    }

    // MARK: - 시작/중지

    /// 서버 시작
    func start() throws {
        guard !isRunning else {
            throw SocketServerError.alreadyRunning
        }

        // 소켓 디렉토리 생성
        let dir = (socketPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // 기존 소켓 파일 제거
        if FileManager.default.fileExists(atPath: socketPath) {
            try FileManager.default.removeItem(atPath: socketPath)
        }

        // Unix domain socket 생성
        serverFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFd >= 0 else {
            throw SocketServerError.socketCreationFailed
        }

        // bind
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            socketPath.withCString { cstr in
                _ = memcpy(ptr, cstr, min(socketPath.utf8.count, MemoryLayout.size(ofValue: ptr.pointee) - 1))
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(serverFd)
            serverFd = -1
            throw SocketServerError.bindFailed
        }

        // listen
        guard listen(serverFd, 5) == 0 else {
            Darwin.close(serverFd)
            serverFd = -1
            throw SocketServerError.listenFailed
        }

        isRunning = true
        GeobukLogger.info(.socket, "Server started", context: ["path": socketPath])

        // accept 루프 시작
        let fd = serverFd
        let sessionMgr = sessionManager
        acceptTask = Task { [weak self] in
            await self?.acceptLoop(serverFd: fd, sessionManager: sessionMgr)
        }
    }

    /// 서버 중지
    func stop() {
        guard isRunning else { return }
        isRunning = false
        GeobukLogger.info(.socket, "Server stopped")

        // accept 루프 취소
        acceptTask?.cancel()
        acceptTask = nil

        // 클라이언트 소켓 닫기
        for clientFd in clientFds {
            Darwin.close(clientFd)
        }
        clientFds.removeAll()

        // 서버 소켓 닫기
        if serverFd >= 0 {
            Darwin.close(serverFd)
            serverFd = -1
        }

        // 소켓 파일 제거
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    // MARK: - Accept Loop

    private func acceptLoop(serverFd: Int32, sessionManager: SessionManager) async {
        // Set non-blocking for accept with cancellation checks
        let flags = fcntl(serverFd, F_GETFL, 0)
        _ = fcntl(serverFd, F_SETFL, flags | O_NONBLOCK)

        while !Task.isCancelled {
            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    accept(serverFd, sockPtr, &clientAddrLen)
                }
            }

            if clientFd >= 0 {
                clientFds.insert(clientFd)
                GeobukLogger.debug(.socket, "Client connected", context: ["fd": "\(clientFd)"])
                let mgr = sessionManager
                Task {
                    await self.handleClient(clientFd, sessionManager: mgr)
                    self.clientFds.remove(clientFd)
                    GeobukLogger.debug(.socket, "Client disconnected", context: ["fd": "\(clientFd)"])
                }
            } else {
                // EAGAIN/EWOULDBLOCK - no pending connections
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    // MARK: - Client Handler

    private func handleClient(_ clientFd: Int32, sessionManager: SessionManager) async {
        var buffer = [UInt8](repeating: 0, count: 65536)
        var accumulated = Data()

        // Set client socket to non-blocking for read with cancellation checks
        let flags = fcntl(clientFd, F_GETFL, 0)
        _ = fcntl(clientFd, F_SETFL, flags | O_NONBLOCK)

        while !Task.isCancelled {
            let bytesRead = Darwin.read(clientFd, &buffer, buffer.count)
            if bytesRead == 0 { break } // Client disconnected
            if bytesRead < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    try? await Task.sleep(for: .milliseconds(10))
                    continue
                }
                break // Error
            }

            accumulated.append(contentsOf: buffer[0..<bytesRead])

            // 줄 단위로 JSON-RPC 요청 처리 (newline-delimited)
            while let newlineRange = accumulated.range(of: Data([0x0A])) {
                let lineData = accumulated[accumulated.startIndex..<newlineRange.lowerBound]
                accumulated.removeSubrange(accumulated.startIndex...newlineRange.lowerBound)

                guard !lineData.isEmpty else { continue }

                let response = await processRequest(Data(lineData), sessionManager: sessionManager)
                if let responseData = response {
                    var responseWithNewline = responseData
                    responseWithNewline.append(0x0A)

                    // Temporarily set blocking for write
                    _ = fcntl(clientFd, F_SETFL, flags)
                    responseWithNewline.withUnsafeBytes { ptr in
                        guard let baseAddress = ptr.baseAddress else { return }
                        _ = Darwin.write(clientFd, baseAddress, ptr.count)
                    }
                    _ = fcntl(clientFd, F_SETFL, flags | O_NONBLOCK)
                }
            }
        }

        Darwin.close(clientFd)
    }

    private func processRequest(_ data: Data, sessionManager: SessionManager) async -> Data? {
        do {
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
            let router = await APIMethodRouter(sessionManager: sessionManager, shellStateManager: shellStateManager)
            let response = await router.route(request)
            return try JSONEncoder().encode(response)
        } catch {
            GeobukLogger.error(.socket, "Request processing failed", error: error)
            // Parse error
            let errorResponse = JSONRPCResponse.error(
                code: JSONRPCErrorCode.parseError.rawValue,
                message: "Parse error: \(error.localizedDescription)",
                id: nil
            )
            return try? JSONEncoder().encode(errorResponse)
        }
    }
}


// MARK: - 에러

enum SocketServerError: Error, Sendable {
    case alreadyRunning
    case socketCreationFailed
    case bindFailed
    case listenFailed
}
