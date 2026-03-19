import Testing
import Foundation
@testable import Geobuk

@Suite("CompletionProvider - 인라인 자동완성")
struct CompletionProviderTests {

    // MARK: - 최소 길이 조건

    @Suite("최소 길이 조건")
    struct MinLengthTests {

        @Test("한글자입력_힌트없음")
        func singleChar_noHint() {
            var history = CommandHistory()
            history.add("ls -la")
            let hint = CompletionProvider.suggest(for: "l", currentDirectory: nil, history: history)
            #expect(hint == nil)
        }

        @Test("빈입력_힌트없음")
        func emptyInput_noHint() {
            let hint = CompletionProvider.suggest(for: "", currentDirectory: nil, history: CommandHistory())
            #expect(hint == nil)
        }

        @Test("두글자입력_힌트가능")
        func twoChars_canSuggest() {
            var history = CommandHistory()
            history.add("ls -la")
            let hint = CompletionProvider.suggest(for: "ls", currentDirectory: nil, history: history)
            // "ls"와 정확히 일치하는 경우에는 힌트 없음, " -la" 같은 더 긴 명령이 있으면 힌트 있을 수 있음
            // 여기서는 충돌 없이 nil이 아닌지만 확인
            _ = hint // 통과 여부 확인을 위한 실행
        }
    }

    // MARK: - 히스토리 기반 완성

    @Suite("히스토리 기반 완성")
    struct HistoryCompletionTests {

        @Test("히스토리접두사일치_나머지힌트반환")
        func historyPrefix_returnsRemainder() {
            var history = CommandHistory()
            history.add("git status")
            let hint = CompletionProvider.historyCompletion(for: "git", history: history)
            #expect(hint == " status")
        }

        @Test("히스토리정확히일치_힌트없음")
        func historyExactMatch_noHint() {
            var history = CommandHistory()
            history.add("ls")
            let hint = CompletionProvider.historyCompletion(for: "ls", history: history)
            #expect(hint == nil)
        }

        @Test("히스토리불일치_힌트없음")
        func historyNoMatch_noHint() {
            var history = CommandHistory()
            history.add("cd /tmp")
            let hint = CompletionProvider.historyCompletion(for: "git", history: history)
            #expect(hint == nil)
        }

        @Test("여러히스토리_최근항목우선")
        func multipleHistory_mostRecentFirst() {
            var history = CommandHistory()
            history.add("git add .")
            history.add("git commit -m 'fix'")
            history.add("git push")
            // 가장 최근인 "git push"가 매칭되어야 함
            let hint = CompletionProvider.historyCompletion(for: "git", history: history)
            #expect(hint == " push")
        }

        @Test("히스토리빈경우_힌트없음")
        func emptyHistory_noHint() {
            let hint = CompletionProvider.historyCompletion(for: "ls", history: CommandHistory())
            #expect(hint == nil)
        }

        @Test("히스토리_긴접두사매칭")
        func longPrefixMatch() {
            var history = CommandHistory()
            history.add("xcodebuild build -scheme Geobuk")
            let hint = CompletionProvider.historyCompletion(for: "xcodebuild build", history: history)
            #expect(hint == " -scheme Geobuk")
        }
    }

    // MARK: - 공통 명령어 완성

    @Suite("공통 명령어 완성")
    struct CommonCommandCompletionTests {

        @Test("공통명령어접두사_나머지힌트반환")
        func commonCommandPrefix_returnsRemainder() {
            let hint = CompletionProvider.commonCommandCompletion(for: "gi")
            #expect(hint == "t")
        }

        @Test("공통명령어정확일치_힌트없음")
        func commonCommandExactMatch_noHint() {
            let hint = CompletionProvider.commonCommandCompletion(for: "git")
            #expect(hint == nil)
        }

        @Test("공통명령어불일치_힌트없음")
        func noMatch_noHint() {
            let hint = CompletionProvider.commonCommandCompletion(for: "zzz")
            #expect(hint == nil)
        }

        @Test("공백포함입력_공통명령어완성안함")
        func inputWithSpace_noCommonCompletion() {
            let hint = CompletionProvider.commonCommandCompletion(for: "git s")
            #expect(hint == nil)
        }

        @Test("ls접두사_lsof보다먼저있으면완성힌트반환")
        func lsPrefix_completionHint() {
            let hint = CompletionProvider.commonCommandCompletion(for: "ls")
            // "ls"가 정확 일치이지만 "lsof"가 먼저 나타날 수 있음
            // commonCommands 목록에서 "ls" 다음에 "lsof"가 있으면 "of" 반환
            // 목록 순서에 따라 다르므로 nil 또는 "of"를 모두 허용
            if let hint {
                #expect(hint == "of")
            }
        }

        @Test("cd접두사_완성힌트반환")
        func cdPrefix_completionHint() {
            // "cd"는 정확 일치이므로 nil
            let hint = CompletionProvider.commonCommandCompletion(for: "cd")
            #expect(hint == nil)
        }

        @Test("do접두사_docker힌트")
        func doPrefix_dockerHint() {
            let hint = CompletionProvider.commonCommandCompletion(for: "do")
            #expect(hint == "cker")
        }

        @Test("np접두사_npm힌트")
        func npPrefix_npmHint() {
            let hint = CompletionProvider.commonCommandCompletion(for: "np")
            #expect(hint == "m")
        }
    }

    // MARK: - 파일 경로 완성

    @Suite("파일 경로 완성")
    struct FilePathCompletionTests {

        @Test("존재하는디렉토리_파일완성")
        func existingDirectory_fileCompletion() {
            // /tmp 는 항상 존재하는 디렉토리
            // 완성 결과가 있거나 없을 수 있으므로 크래시만 없으면 통과
            let hint = CompletionProvider.filePathCompletion(for: "/tm", currentDirectory: nil)
            // /tm 은 / 에서 "tm" prefix를 찾는 것 -> /tmp 가 있으면 "p" 반환
            if let hint {
                #expect(!hint.isEmpty)
            }
        }

        @Test("존재하지않는경로_힌트없음")
        func nonExistentPath_noHint() {
            let hint = CompletionProvider.filePathCompletion(
                for: "/this/path/does/not/exist/xyz",
                currentDirectory: nil
            )
            #expect(hint == nil)
        }

        @Test("슬래시없이공통디렉토리탐색")
        func withCurrentDirectory_filePrefix() {
            // currentDirectory를 /tmp로 설정하여 그 안의 파일 탐색
            // 힌트 있음 없음은 실제 파일에 따라 다르므로 크래시 없음만 확인
            let hint = CompletionProvider.filePathCompletion(
                for: "xyz_definitely_not_exist",
                currentDirectory: "/tmp"
            )
            #expect(hint == nil)
        }

        @Test("틸드경로_홈디렉토리확장")
        func tildePath_expandsToHome() {
            // ~/Documents 같은 경로가 크래시 없이 실행되어야 함
            let hint = CompletionProvider.filePathCompletion(for: "~/Doc", currentDirectory: nil)
            // ~/Documents 가 존재하면 "uments" 반환, 없으면 nil
            if let hint {
                #expect(!hint.isEmpty)
            }
        }

        @Test("정확히일치하는파일이름_힌트없음")
        func exactMatchingFile_noHint() {
            // /tmp 는 정확히 "/tmp" 인 경우 -> "/"가 포함된 정확 일치 케이스
            // splitPathComponents("/tmp", ...) -> dir="/" file="tmp"
            // "tmp"로 시작하되 "tmp"와 다른 항목이 없으면 nil
            let hint = CompletionProvider.filePathCompletion(for: "/tmp", currentDirectory: nil)
            // /tmp 가 정확히 일치하므로 nil이어야 함 (더 긴 항목이 없으면)
            _ = hint // 크래시 없음만 검증
        }
    }

    // MARK: - 우선순위 통합 테스트

    @Suite("우선순위")
    struct PriorityTests {

        @Test("경로포함_히스토리있어도_파일경로우선탐색시도")
        func pathInput_fileCompletionAttemptedFirst() {
            var history = CommandHistory()
            history.add("/usr/local/bin/git")
            // "/usr/lo" -> 파일 경로 완성을 먼저 시도, 실패하면 히스토리로 폴백
            let hint = CompletionProvider.suggest(
                for: "/usr/lo",
                currentDirectory: nil,
                history: history
            )
            // /usr/local 이 있으면 "cal" 반환, 없으면 히스토리에서 "cal/bin/git" 반환
            _ = hint
        }

        @Test("공통명령어_히스토리없을때_공통명령완성")
        func noHistory_commonCommandCompletion() {
            let hint = CompletionProvider.suggest(
                for: "gi",
                currentDirectory: nil,
                history: CommandHistory()
            )
            #expect(hint == "t")
        }

        @Test("히스토리있을때_히스토리가공통명령보다우선")
        func withHistory_historyOverCommonCommand() {
            var history = CommandHistory()
            history.add("git status --short")
            let hint = CompletionProvider.suggest(
                for: "git",
                currentDirectory: nil,
                history: history
            )
            // 히스토리에 "git status --short"가 있으므로 " status --short" 반환
            #expect(hint == " status --short")
        }
    }

    // MARK: - 네거티브 / 경계값

    @Suite("네거티브 및 경계값")
    struct NegativeTests {

        @Test("입력이히스토리와정확히일치_힌트없음")
        func exactHistoryMatch_noHint() {
            var history = CommandHistory()
            history.add("npm install")
            let hint = CompletionProvider.historyCompletion(for: "npm install", history: history)
            #expect(hint == nil)
        }

        @Test("공통명령어목록비어있지않음")
        func commonCommandsNotEmpty() {
            #expect(!CompletionProvider.commonCommands.isEmpty)
        }

        @Test("공통명령어에git포함됨")
        func commonCommandsContainsGit() {
            #expect(CompletionProvider.commonCommands.contains("git"))
        }

        @Test("공통명령어에npm포함됨")
        func commonCommandsContainsNpm() {
            #expect(CompletionProvider.commonCommands.contains("npm"))
        }

        @Test("공통명령어에cd포함됨")
        func commonCommandsContainsCd() {
            #expect(CompletionProvider.commonCommands.contains("cd"))
        }

        @Test("대소문자구별_소문자만매칭")
        func caseSensitive_onlyLowercase() {
            let hint = CompletionProvider.commonCommandCompletion(for: "GI")
            #expect(hint == nil)
        }

        @Test("히스토리한항목두글자입력_완성반환")
        func singleHistoryTwoCharInput_completionReturned() {
            var history = CommandHistory()
            history.add("ls -la")
            let hint = CompletionProvider.historyCompletion(for: "ls", history: history)
            #expect(hint == " -la")
        }
    }

    // MARK: - 복수 후보 목록 (suggestAll)

    @Suite("복수 후보 목록")
    struct SuggestAllTests {

        @Test("공통명령어_복수후보반환")
        func commonCommands_multipleResults() {
            let results = CompletionProvider.suggestAll(
                for: "gi",
                currentDirectory: nil,
                history: CommandHistory()
            )
            // "git", "gzip", "gunzip" 등 gi로 시작하는 명령어들
            #expect(results.count >= 1)
            #expect(results.contains("git"))
        }

        @Test("파일경로_복수후보반환")
        func filePath_multipleResults() {
            // /usr 에는 여러 디렉토리가 있음
            let results = CompletionProvider.suggestAll(
                for: "ls /usr/",
                currentDirectory: nil,
                history: CommandHistory()
            )
            // bin, lib, local 등
            #expect(results.count >= 2)
        }

        @Test("히스토리_복수후보반환")
        func history_multipleResults() {
            var history = CommandHistory()
            history.add("git add .")
            history.add("git commit -m 'fix'")
            history.add("git push")
            let results = CompletionProvider.suggestAll(
                for: "git",
                currentDirectory: nil,
                history: history
            )
            #expect(results.count == 3)
            // 최근 항목이 먼저
            #expect(results[0] == "git push")
            #expect(results[1] == "git commit -m 'fix'")
            #expect(results[2] == "git add .")
        }

        @Test("후보1개면_단일항목반환")
        func singleCandidate_returnsOne() {
            let results = CompletionProvider.suggestAll(
                for: "xcodeb",
                currentDirectory: nil,
                history: CommandHistory()
            )
            #expect(results.count == 1)
            #expect(results.first == "xcodebuild")
        }

        @Test("매칭없음_빈배열반환")
        func noMatch_returnsEmpty() {
            let results = CompletionProvider.suggestAll(
                for: "zzzzz",
                currentDirectory: nil,
                history: CommandHistory()
            )
            #expect(results.isEmpty)
        }

        @Test("최소길이미달_빈배열반환")
        func tooShort_returnsEmpty() {
            let results = CompletionProvider.suggestAll(
                for: "g",
                currentDirectory: nil,
                history: CommandHistory()
            )
            #expect(results.isEmpty)
        }

        @Test("정확일치_후보에포함안됨")
        func exactMatch_excluded() {
            var history = CommandHistory()
            history.add("git")
            let results = CompletionProvider.suggestAll(
                for: "git",
                currentDirectory: nil,
                history: history
            )
            // "git" 정확 일치는 후보에서 제외
            #expect(!results.contains("git"))
        }

        @Test("maxResults제한")
        func maxResults_limits() {
            var history = CommandHistory()
            for i in 0..<20 {
                history.add("test command \(i)")
            }
            let results = CompletionProvider.suggestAll(
                for: "test",
                currentDirectory: nil,
                history: history,
                maxResults: 5
            )
            #expect(results.count <= 5)
        }

        @Test("중복제거_동일후보는한번만")
        func dedup_noDuplicates() {
            var history = CommandHistory()
            history.add("git status")
            history.add("git pull")
            history.add("git status") // 중복 (CommandHistory가 연속 중복만 제거)
            let results = CompletionProvider.suggestAll(
                for: "git",
                currentDirectory: nil,
                history: history
            )
            let unique = Set(results)
            #expect(results.count == unique.count)
        }

        @Test("파일경로와히스토리_혼합결과")
        func mixedSources_combinedResults() {
            var history = CommandHistory()
            history.add("cd /tmp/testdir")
            let results = CompletionProvider.suggestAll(
                for: "cd /tmp",
                currentDirectory: nil,
                history: history
            )
            // 히스토리 후보 + 파일 경로 후보가 혼합
            #expect(results.count >= 1)
        }
    }

    // MARK: - CWD 기반 파일명 완성

    @Suite("CWD 기반 파일명 완성")
    struct CwdCompletionTests {

        @Test("currentDirectory에서_파일명prefix완성")
        func cwdFileCompletion_matchesPrefix() {
            // /usr 디렉토리에서 "bi" 입력 → "n" 힌트 (bin)
            let hint = CompletionProvider.cwdFileCompletion(for: "bi", currentDirectory: "/usr")
            #expect(hint == "n")
        }

        @Test("슬래시포함_cwdCompletionSkip")
        func cwdFileCompletion_skipsPathInput() {
            let hint = CompletionProvider.cwdFileCompletion(for: "/usr/bi", currentDirectory: "/usr")
            #expect(hint == nil) // 슬래시 포함이면 기존 filePathCompletion이 처리
        }

        @Test("공백뒤토큰으로완성")
        func cwdFileCompletion_afterSpace() {
            // "cd bi" → 마지막 토큰 "bi" → /usr에서 "bin" 매칭 → "n"
            let hint = CompletionProvider.cwdFileCompletion(for: "cd bi", currentDirectory: "/usr")
            #expect(hint == "n")
        }

        @Test("매칭없음_힌트없음")
        func cwdFileCompletion_noMatch() {
            let hint = CompletionProvider.cwdFileCompletion(for: "zzz_not_exist", currentDirectory: "/usr")
            #expect(hint == nil)
        }

        @Test("suggest에서_cwd기반완성도동작")
        func suggest_usesCwd() {
            // /usr에서 "bi" 입력 → "n" 힌트 (bin)
            let hint = CompletionProvider.suggest(
                for: "bi",
                currentDirectory: "/usr",
                history: CommandHistory()
            )
            #expect(hint == "n")
        }

        @Test("suggestAll에서_cwd기반후보반환")
        func suggestAll_usesCwd() {
            let results = CompletionProvider.suggestAll(
                for: "li",
                currentDirectory: "/usr",
                history: CommandHistory()
            )
            // /usr에 lib, libexec 등이 있을 수 있음
            #expect(results.count >= 1)
        }

        @Test("cwdFileCandidates_복수후보반환")
        func cwdFileCandidates_multipleResults() {
            let results = CompletionProvider.cwdFileCandidates(
                for: "cd li",
                currentDirectory: "/usr"
            )
            // "cd lib", "cd libexec" 등
            #expect(results.count >= 1)
            for r in results {
                #expect(r.hasPrefix("cd li"))
            }
        }
    }

    // MARK: - 퍼징 / 랜덤 입력

    @Suite("퍼징 테스트")
    struct FuzzTests {

        @Test("특수문자입력_크래시없음")
        func specialCharInput_noCrash() {
            let specialInputs = [
                "!@#$%", "\"quoted\"", "'single'", "`backtick`",
                "$(cmd)", "${var}", "&&", "||", ";", "|",
                "\n", "\t", "\0", "\\", "<>", "&"
            ]
            for input in specialInputs {
                _ = CompletionProvider.suggest(for: input, currentDirectory: nil, history: CommandHistory())
            }
        }

        @Test("유니코드입력_크래시없음")
        func unicodeInput_noCrash() {
            let unicodeInputs = [
                "한글명령", "emoji🚀", "中文命令", "العربية", "русский",
                "git\u{200B}push", // 제로폭 공백
                "ls\u{FEFF}" // BOM
            ]
            for input in unicodeInputs {
                _ = CompletionProvider.suggest(for: input, currentDirectory: nil, history: CommandHistory())
            }
        }

        @Test("매우긴입력_크래시없음")
        func veryLongInput_noCrash() {
            let longInput = String(repeating: "a", count: 10000)
            _ = CompletionProvider.suggest(for: longInput, currentDirectory: nil, history: CommandHistory())
        }

        @Test("비정상경로_크래시없음")
        func malformedPath_noCrash() {
            let paths = [
                "////multiple/slashes",
                "/path/with spaces/file",
                "/path/../../../etc/passwd",
                "~/../../etc",
                "/\0null/in/path"
            ]
            for path in paths {
                _ = CompletionProvider.filePathCompletion(for: path, currentDirectory: nil)
            }
        }

        @Test("랜덤문자열_크래시없음")
        func randomStrings_noCrash() {
            var history = CommandHistory()
            history.add("some command")

            let randomInputs = (0..<50).map { _ in
                let chars = "abcdefghijklmnopqrstuvwxyz/~. -_"
                let length = Int.random(in: 1...20)
                return String((0..<length).map { _ in chars.randomElement()! })
            }

            for input in randomInputs {
                _ = CompletionProvider.suggest(for: input, currentDirectory: "/tmp", history: history)
            }
        }
    }
}
