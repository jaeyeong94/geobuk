import Foundation

/// Claude Code 세션 파일 감시 (Readout 방식)
/// ~/.claude/sessions/<pid>.json → 세션 감지
/// ~/.claude/projects/.../<uuid>.jsonl → 트랜스크립트 tail
@MainActor
@Observable
final class ClaudeSessionFileWatcher {
    /// 감지된 활성 세션 목록
    private(set) var activeSessions: [ClaudeFileSession] = []

    /// 세션 디렉토리 경로
    private let sessionsDir: String

    /// 폴링 타이머
    private var scanTimer: Timer?

    /// JSONL tailer (세션별)
    private var tailers: [String: PTYLogTailer] = [:]  // sessionId → tailer

    /// 이벤트 콜백
    var onTranscriptEvent: ((_ sessionId: String, _ event: [String: Any]) -> Void)?

    init(sessionsDir: String? = nil) {
        self.sessionsDir = sessionsDir ?? (NSHomeDirectory() + "/.claude/sessions")
    }

    // MARK: - Lifecycle

    /// 감시 시작 (2초 간격 폴링)
    func startWatching() {
        stopWatching()
        scanSessions()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scanSessions()
            }
        }
    }

    /// 감시 중지
    func stopWatching() {
        scanTimer?.invalidate()
        scanTimer = nil
        for (_, tailer) in tailers {
            Task { await tailer.stopTailing() }
        }
        tailers.removeAll()
    }

    // MARK: - Session Scanning

    /// ~/.claude/sessions/ 디렉토리에서 활성 세션 검색
    private func scanSessions() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: sessionsDir) else {
            if !activeSessions.isEmpty { activeSessions = [] }
            return
        }

        guard let files = try? fm.contentsOfDirectory(atPath: sessionsDir) else { return }

        var foundSessions: [ClaudeFileSession] = []

        for file in files where file.hasSuffix(".json") {
            let fullPath = (sessionsDir as NSString).appendingPathComponent(file)
            guard let data = fm.contents(atPath: fullPath),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pid = json["pid"] as? Int,
                  let sessionId = json["sessionId"] as? String else {
                continue
            }

            // 프로세스가 아직 실행 중인지 확인
            guard ProcessTreeScanner.processExists(pid: pid_t(pid)) else {
                // 종료된 세션 파일 정리
                try? fm.removeItem(atPath: fullPath)
                continue
            }

            let cwd = json["cwd"] as? String ?? ""
            let startedAt = (json["startedAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }

            let session = ClaudeFileSession(
                pid: pid_t(pid),
                sessionId: sessionId,
                cwd: cwd,
                startedAt: startedAt,
                transcriptPath: findTranscriptPath(sessionId: sessionId, cwd: cwd)
            )
            foundSessions.append(session)

            // 새 세션이면 트랜스크립트 tailing 시작
            if tailers[sessionId] == nil, let transcriptPath = session.transcriptPath {
                startTailing(sessionId: sessionId, path: transcriptPath)
            }
        }

        // 종료된 세션의 tailer 정리
        let activeIds = Set(foundSessions.map(\.sessionId))
        for (sessionId, tailer) in tailers {
            if !activeIds.contains(sessionId) {
                Task { await tailer.stopTailing() }
                tailers.removeValue(forKey: sessionId)
            }
        }

        activeSessions = foundSessions
    }

    // MARK: - Transcript Path Resolution

    /// 세션 ID로 트랜스크립트 JSONL 파일 경로 찾기
    private func findTranscriptPath(sessionId: String, cwd: String) -> String? {
        // 경로 1: ~/.claude/projects/<encoded-cwd>/<sessionId>.jsonl
        let projectsDir = NSHomeDirectory() + "/.claude/projects"
        let encodedCwd = cwd.replacingOccurrences(of: "/", with: "-")
        let projectPath = "\(projectsDir)/\(encodedCwd)/\(sessionId).jsonl"

        if FileManager.default.fileExists(atPath: projectPath) {
            return projectPath
        }

        // 경로 2: 전체 projects 디렉토리에서 검색
        if let dirs = try? FileManager.default.contentsOfDirectory(atPath: projectsDir) {
            for dir in dirs {
                let candidate = "\(projectsDir)/\(dir)/\(sessionId).jsonl"
                if FileManager.default.fileExists(atPath: candidate) {
                    return candidate
                }
            }
        }

        return nil
    }

    // MARK: - Transcript Tailing

    /// 트랜스크립트 JSONL 파일을 tail하여 새 이벤트 감지
    private func startTailing(sessionId: String, path: String) {
        let tailer = PTYLogTailer(filePath: path)
        tailers[sessionId] = tailer

        let sid = sessionId
        Task {
            await tailer.startTailing { [weak self] data in
                Task { @MainActor [weak self] in
                    self?.processTranscriptData(sessionId: sid, data: data)
                }
            }
        }
    }

    /// JSONL 데이터 파싱 (줄 단위)
    private func processTranscriptData(sessionId: String, data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }

        for line in text.components(separatedBy: "\n") where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }
            onTranscriptEvent?(sessionId, json)
        }
    }
}

// MARK: - Models

/// 파일 기반으로 감지된 Claude 세션
struct ClaudeFileSession: Identifiable, Sendable {
    let pid: pid_t
    let sessionId: String
    let cwd: String
    let startedAt: Date?
    let transcriptPath: String?

    var id: String { sessionId }
}
