import Testing
import Foundation
@testable import Geobuk

@Suite("CommandHistory - 명령어 히스토리 관리")
struct CommandHistoryTests {

    // MARK: - 초기 상태

    @Suite("초기 상태")
    struct InitialStateTests {

        @Test("생성직후_히스토리비어있음")
        func creation_historyIsEmpty() {
            let history = CommandHistory()
            #expect(history.commands.isEmpty)
        }

        @Test("생성직후_이전명령없음")
        func creation_noPreviousCommand() {
            var history = CommandHistory()
            #expect(history.navigateUp() == nil)
        }

        @Test("생성직후_다음명령없음")
        func creation_noNextCommand() {
            var history = CommandHistory()
            #expect(history.navigateDown() == nil)
        }
    }

    // MARK: - 명령어 추가

    @Suite("명령어 추가")
    struct AddCommandTests {

        @Test("명령어추가_히스토리에저장됨")
        func addCommand_storedInHistory() {
            var history = CommandHistory()
            history.add("ls -la")
            #expect(history.commands == ["ls -la"])
        }

        @Test("여러명령어추가_순서유지됨")
        func addMultipleCommands_orderPreserved() {
            var history = CommandHistory()
            history.add("cd /tmp")
            history.add("ls")
            history.add("pwd")
            #expect(history.commands == ["cd /tmp", "ls", "pwd"])
        }

        @Test("빈문자열_추가되지않음")
        func addEmptyString_notAdded() {
            var history = CommandHistory()
            history.add("")
            #expect(history.commands.isEmpty)
        }

        @Test("공백만있는문자열_추가되지않음")
        func addWhitespaceOnly_notAdded() {
            var history = CommandHistory()
            history.add("   ")
            #expect(history.commands.isEmpty)
        }

        @Test("추가후_탐색인덱스초기화됨")
        func addAfterNavigation_indexReset() {
            var history = CommandHistory()
            history.add("first")
            history.add("second")
            _ = history.navigateUp() // "second"
            history.add("third")
            // 탐색 위치가 리셋되어 navigateUp은 가장 최근 명령 반환
            #expect(history.navigateUp() == "third")
        }
    }

    // MARK: - 위로 탐색 (이전 명령)

    @Suite("위로 탐색")
    struct NavigateUpTests {

        @Test("하나의명령_위로탐색_해당명령반환")
        func oneCommand_navigateUp_returnsCommand() {
            var history = CommandHistory()
            history.add("echo hello")
            #expect(history.navigateUp() == "echo hello")
        }

        @Test("여러명령_위로탐색_최근부터역순반환")
        func multipleCommands_navigateUp_returnsReversed() {
            var history = CommandHistory()
            history.add("first")
            history.add("second")
            history.add("third")
            #expect(history.navigateUp() == "third")
            #expect(history.navigateUp() == "second")
            #expect(history.navigateUp() == "first")
        }

        @Test("맨위에서_위로탐색_첫명령유지")
        func atTop_navigateUp_returnsFirstCommand() {
            var history = CommandHistory()
            history.add("only")
            #expect(history.navigateUp() == "only")
            #expect(history.navigateUp() == "only") // 더 이상 위로 못감
        }
    }

    // MARK: - 아래로 탐색 (다음 명령)

    @Suite("아래로 탐색")
    struct NavigateDownTests {

        @Test("위로탐색후_아래로탐색_다음명령반환")
        func afterUp_navigateDown_returnsNextCommand() {
            var history = CommandHistory()
            history.add("first")
            history.add("second")
            history.add("third")
            _ = history.navigateUp() // "third"
            _ = history.navigateUp() // "second"
            #expect(history.navigateDown() == "third")
        }

        @Test("맨아래에서_아래로탐색_nil반환")
        func atBottom_navigateDown_returnsNil() {
            var history = CommandHistory()
            history.add("command")
            _ = history.navigateUp()
            #expect(history.navigateDown() == nil)
        }

        @Test("탐색하지않고_아래로탐색_nil반환")
        func withoutUp_navigateDown_returnsNil() {
            var history = CommandHistory()
            history.add("command")
            #expect(history.navigateDown() == nil)
        }
    }

    // MARK: - 탐색 리셋

    @Suite("탐색 리셋")
    struct ResetNavigationTests {

        @Test("리셋후_위로탐색_최근명령반환")
        func afterReset_navigateUp_returnsLatest() {
            var history = CommandHistory()
            history.add("first")
            history.add("second")
            _ = history.navigateUp() // "second"
            _ = history.navigateUp() // "first"
            history.resetNavigation()
            #expect(history.navigateUp() == "second")
        }
    }

    // MARK: - 최대 크기 제한

    @Suite("최대 크기 제한")
    struct MaxSizeTests {

        @Test("최대크기초과_오래된명령제거됨")
        func exceedMaxSize_oldestRemoved() {
            var history = CommandHistory(maxSize: 3)
            history.add("cmd1")
            history.add("cmd2")
            history.add("cmd3")
            history.add("cmd4")
            #expect(history.commands == ["cmd2", "cmd3", "cmd4"])
        }
    }

    // MARK: - 중복 명령

    @Suite("중복 명령")
    struct DuplicateTests {

        @Test("연속중복명령_하나만저장됨")
        func consecutiveDuplicate_onlyOneStored() {
            var history = CommandHistory()
            history.add("ls")
            history.add("ls")
            #expect(history.commands == ["ls"])
        }

        @Test("비연속중복명령_둘다저장됨")
        func nonConsecutiveDuplicate_bothStored() {
            var history = CommandHistory()
            history.add("ls")
            history.add("pwd")
            history.add("ls")
            #expect(history.commands == ["ls", "pwd", "ls"])
        }
    }
}
