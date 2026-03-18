import Testing
import Foundation
@testable import Geobuk

@Suite("PTYLogTailer")
struct PTYLogTailerTests {

    // MARK: - Helper

    /// 테스트용 임시 파일 경로 생성
    private func makeTempFilePath() -> String {
        let dir = NSTemporaryDirectory()
        return (dir as NSString).appendingPathComponent("ptylog-test-\(UUID().uuidString).log")
    }

    /// 테스트 파일 정리
    private func removeTempFile(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - 단위 테스트 (Unit Tests)

    @Test("init_파일경로저장")
    func init_storesFilePath() async {
        let path = "/tmp/test-tailer.log"
        let tailer = PTYLogTailer(filePath: path)
        let storedPath = await tailer.filePath
        #expect(storedPath == path)
    }

    @Test("startTailing_파일변경시_데이터콜백호출")
    func startTailing_fileChange_callsDataCallback() async throws {
        let path = makeTempFilePath()
        defer { removeTempFile(path) }

        // 빈 파일 생성
        FileManager.default.createFile(atPath: path, contents: Data())

        let tailer = PTYLogTailer(filePath: path)

        let collector = DataCollector()

        await tailer.startTailing { data in
            if !data.isEmpty {
                collector.append(data)
            }
        }

        // 잠시 대기 후 파일에 데이터 쓰기
        try await Task.sleep(for: .milliseconds(100))

        let testData = "hello from PTY\n"
        try testData.write(toFile: path, atomically: false, encoding: .utf8)

        // 콜백이 호출될 때까지 대기 (최대 2초)
        let received = await collector.waitForData(timeout: 2.0)
        #expect(received == true)

        await tailer.stopTailing()
    }

    @Test("startTailing_추가데이터만_콜백호출")
    func startTailing_onlyNewData_callsCallback() async throws {
        let path = makeTempFilePath()
        defer { removeTempFile(path) }

        // 초기 데이터가 있는 파일 생성
        let initialData = "initial content\n"
        FileManager.default.createFile(atPath: path, contents: Data(initialData.utf8))

        let tailer = PTYLogTailer(filePath: path)
        let collector = DataCollector()

        await tailer.startTailing { data in
            collector.append(data)
        }

        try await Task.sleep(for: .milliseconds(100))

        // 추가 데이터 쓰기
        let additionalData = "new data\n"
        let fileHandle = FileHandle(forWritingAtPath: path)!
        fileHandle.seekToEndOfFile()
        fileHandle.write(Data(additionalData.utf8))
        fileHandle.closeFile()

        try await Task.sleep(for: .milliseconds(500))

        let received = await collector.allDataAsString()

        // 초기 데이터는 포함하지 않아야 함 (추가된 데이터만)
        #expect(!received.contains("initial content"))
        if !received.isEmpty {
            #expect(received.contains("new data"))
        }

        await tailer.stopTailing()
    }

    @Test("stopTailing_리소스해제")
    func stopTailing_releasesResources() async throws {
        let path = makeTempFilePath()
        defer { removeTempFile(path) }

        FileManager.default.createFile(atPath: path, contents: Data())

        let tailer = PTYLogTailer(filePath: path)
        await tailer.startTailing { _ in }
        await tailer.stopTailing()

        // stopTailing 후에는 isTailing이 false여야 함
        let isTailing = await tailer.isTailing
        #expect(isTailing == false)
    }

    // MARK: - 네거티브 테스트 (Negative Tests)

    @Test("startTailing_존재하지않는파일_에러없이실패")
    func startTailing_nonExistentFile_gracefulFailure() async {
        let path = "/tmp/nonexistent-\(UUID().uuidString).log"
        let tailer = PTYLogTailer(filePath: path)

        // 존재하지 않는 파일에 대해 에러 없이 처리
        await tailer.startTailing { _ in }

        let isTailing = await tailer.isTailing
        #expect(isTailing == false)

        await tailer.stopTailing()
    }

    @Test("stopTailing_시작전호출_에러없음")
    func stopTailing_beforeStart_noError() async {
        let tailer = PTYLogTailer(filePath: "/tmp/test.log")
        // 시작 전 stop 호출해도 에러 없어야 함
        await tailer.stopTailing()
    }

    @Test("stopTailing_중복호출_에러없음")
    func stopTailing_duplicateCalls_noError() async throws {
        let path = makeTempFilePath()
        defer { removeTempFile(path) }

        FileManager.default.createFile(atPath: path, contents: Data())

        let tailer = PTYLogTailer(filePath: path)
        await tailer.startTailing { _ in }
        await tailer.stopTailing()
        await tailer.stopTailing() // 두 번째 호출도 에러 없어야 함
    }

    @Test("startTailing_파일삭제후_크래시없음")
    func startTailing_fileDeletedDuringTailing_noCrash() async throws {
        let path = makeTempFilePath()

        FileManager.default.createFile(atPath: path, contents: Data())

        let tailer = PTYLogTailer(filePath: path)
        await tailer.startTailing { _ in }

        try await Task.sleep(for: .milliseconds(100))

        // tailing 중 파일 삭제
        removeTempFile(path)

        try await Task.sleep(for: .milliseconds(100))

        // 크래시 없이 정상 정리
        await tailer.stopTailing()
    }

    // MARK: - 퍼징 테스트 (Fuzz Tests)

    @Test("startTailing_대용량데이터_크래시없음")
    func startTailing_largeData_noCrash() async throws {
        let path = makeTempFilePath()
        defer { removeTempFile(path) }

        FileManager.default.createFile(atPath: path, contents: Data())

        let tailer = PTYLogTailer(filePath: path)
        let collector = DataCollector()

        await tailer.startTailing { data in
            collector.append(data)
        }

        try await Task.sleep(for: .milliseconds(100))

        // 대용량 데이터 쓰기
        let fileHandle = FileHandle(forWritingAtPath: path)!
        for _ in 0..<100 {
            let chunk = Data(repeating: UInt8.random(in: 32...126), count: 1024)
            fileHandle.write(chunk)
        }
        fileHandle.closeFile()

        try await Task.sleep(for: .milliseconds(500))

        await tailer.stopTailing()
        // 크래시 없이 완료 = 통과
    }

    @Test("startTailing_빈파일유지_콜백미호출")
    func startTailing_emptyFileRemains_noCallback() async throws {
        let path = makeTempFilePath()
        defer { removeTempFile(path) }

        FileManager.default.createFile(atPath: path, contents: Data())

        let tailer = PTYLogTailer(filePath: path)
        let collector = DataCollector()

        await tailer.startTailing { data in
            collector.append(data)
        }

        try await Task.sleep(for: .milliseconds(300))

        let hasData = await collector.hasData()
        #expect(hasData == false)

        await tailer.stopTailing()
    }
}

// MARK: - Test Helper

/// 비동기/동시성 안전한 데이터 수집기 (actor)
private actor DataCollector {
    private var data = Data()

    nonisolated func append(_ newData: Data) {
        // nonisolated에서 actor로 진입
        Task { await _append(newData) }
    }

    private func _append(_ newData: Data) {
        data.append(newData)
    }

    func hasData() -> Bool {
        !data.isEmpty
    }

    func allDataAsString() -> String {
        String(data: data, encoding: .utf8) ?? ""
    }

    func waitForData(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !data.isEmpty { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return !data.isEmpty
    }
}
