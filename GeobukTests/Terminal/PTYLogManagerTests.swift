import Testing
import Foundation
@testable import Geobuk

@Suite("PTYLogManager")
struct PTYLogManagerTests {

    // MARK: - 단위 테스트 (Unit Tests)

    @Test("logDirectory_ApplicationSupport경로포함")
    func logDirectory_containsApplicationSupportPath() {
        let dir = PTYLogManager.logDirectory
        #expect(dir.contains("Application Support"))
        #expect(dir.contains("Geobuk/pty-logs"))
    }

    @Test("logPath_고유UUID별_고유경로생성")
    func logPath_uniquePathPerUUID() {
        let id1 = UUID()
        let id2 = UUID()
        let path1 = PTYLogManager.logPath(for: id1)
        let path2 = PTYLogManager.logPath(for: id2)
        #expect(path1 != path2)
        #expect(path1.contains(id1.uuidString))
        #expect(path2.contains(id2.uuidString))
    }

    @Test("logPath_logDirectory하위경로")
    func logPath_isUnderLogDirectory() {
        let id = UUID()
        let path = PTYLogManager.logPath(for: id)
        #expect(path.hasPrefix(PTYLogManager.logDirectory))
    }

    @Test("logPath_확장자log")
    func logPath_hasLogExtension() {
        let path = PTYLogManager.logPath(for: UUID())
        #expect(path.hasSuffix(".log"))
    }

    @Test("scriptCommand_macOS플래그포함")
    func scriptCommand_containsMacOSFlags() {
        let id = UUID()
        let cmd = PTYLogManager.scriptCommand(for: id)
        #expect(cmd.contains("script"))
        #expect(cmd.contains("-q"))
        #expect(cmd.contains("-F"))
    }

    @Test("scriptCommand_로그파일경로포함")
    func scriptCommand_containsLogFilePath() {
        let id = UUID()
        let cmd = PTYLogManager.scriptCommand(for: id)
        let logPath = PTYLogManager.logPath(for: id)
        #expect(cmd.contains(logPath))
    }

    @Test("scriptCommand_셸경로포함")
    func scriptCommand_containsShellPath() {
        let cmd = PTYLogManager.scriptCommand(for: UUID())
        // SHELL 환경변수 또는 기본값 /bin/zsh를 포함해야 함
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        #expect(cmd.contains(shell))
    }

    @Test("initialize_로그디렉토리생성")
    func initialize_createsLogDirectory() throws {
        // 테스트용 임시 디렉토리 사용을 위해 실제 initialize 호출
        PTYLogManager.initialize()
        let exists = FileManager.default.fileExists(atPath: PTYLogManager.logDirectory)
        #expect(exists == true)
    }

    @Test("cleanup_특정파일삭제")
    func cleanup_removesSpecificLogFile() throws {
        let id = UUID()
        let path = PTYLogManager.logPath(for: id)

        // 로그 디렉토리 확보
        PTYLogManager.initialize()

        // 테스트 파일 생성
        FileManager.default.createFile(atPath: path, contents: Data("test".utf8))
        #expect(FileManager.default.fileExists(atPath: path) == true)

        // cleanup 후 파일 없어야 함
        PTYLogManager.cleanup(paneId: id)
        #expect(FileManager.default.fileExists(atPath: path) == false)
    }

    @Test("cleanupAll_모든로그파일삭제")
    func cleanupAll_removesAllLogFiles() throws {
        PTYLogManager.initialize()

        // 여러 로그 파일 생성
        let ids = [UUID(), UUID(), UUID()]
        for id in ids {
            let path = PTYLogManager.logPath(for: id)
            FileManager.default.createFile(atPath: path, contents: Data("test".utf8))
        }

        PTYLogManager.cleanupAll()

        // 모든 파일이 삭제되어야 함
        for id in ids {
            let path = PTYLogManager.logPath(for: id)
            #expect(FileManager.default.fileExists(atPath: path) == false)
        }
    }

    // MARK: - 네거티브 테스트 (Negative Tests)

    @Test("cleanup_존재하지않는파일_에러없음")
    func cleanup_nonExistentFile_noError() {
        let id = UUID()
        // 파일이 없어도 에러가 발생하지 않아야 함
        PTYLogManager.cleanup(paneId: id)
    }

    @Test("cleanupAll_빈디렉토리_에러없음")
    func cleanupAll_emptyDirectory_noError() {
        PTYLogManager.initialize()
        PTYLogManager.cleanupAll()
        // 빈 디렉토리에서도 에러 없이 완료
    }

    @Test("initialize_중복호출_에러없음")
    func initialize_duplicateCalls_noError() {
        PTYLogManager.initialize()
        PTYLogManager.initialize()
        let exists = FileManager.default.fileExists(atPath: PTYLogManager.logDirectory)
        #expect(exists == true)
    }

    // MARK: - 퍼징 테스트 (Fuzz Tests)

    @Test("logPath_다수UUID_모두고유")
    func logPath_manyUUIDs_allUnique() {
        var paths = Set<String>()
        for _ in 0..<100 {
            let path = PTYLogManager.logPath(for: UUID())
            paths.insert(path)
        }
        #expect(paths.count == 100)
    }

    @Test("scriptCommand_다수UUID_모두유효명령어")
    func scriptCommand_manyUUIDs_allValidCommands() {
        for _ in 0..<50 {
            let cmd = PTYLogManager.scriptCommand(for: UUID())
            #expect(cmd.contains("script"))
            #expect(cmd.contains("-q"))
            #expect(cmd.contains("-F"))
            #expect(!cmd.isEmpty)
        }
    }
}
