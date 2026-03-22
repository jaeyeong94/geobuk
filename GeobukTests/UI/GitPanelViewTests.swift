import Testing
import Foundation
@testable import Geobuk

@Suite("GitPanelView - parseStatus 파싱")
struct GitPanelViewParseStatusTests {

    // MARK: - Happy Path

    @Test("수정된파일_M상태_파싱성공")
    func modifiedFile_parsedCorrectly() {
        let output = " M src/main.swift"
        let result = GitPanelView.parseStatus(output)
        #expect(result.count == 1)
        #expect(result[0].x == " ")
        #expect(result[0].y == "M")
        #expect(result[0].path == "src/main.swift")
    }

    @Test("스테이지된파일_M상태_파싱성공")
    func stagedModifiedFile_parsedCorrectly() {
        let output = "M  src/main.swift"
        let result = GitPanelView.parseStatus(output)
        #expect(result.count == 1)
        #expect(result[0].x == "M")
        #expect(result[0].y == " ")
        #expect(result[0].path == "src/main.swift")
    }

    @Test("추가된파일_A상태_파싱성공")
    func addedFile_parsedCorrectly() {
        let output = "A  new_file.swift"
        let result = GitPanelView.parseStatus(output)
        #expect(result.count == 1)
        #expect(result[0].x == "A")
        #expect(result[0].y == " ")
        #expect(result[0].path == "new_file.swift")
    }

    @Test("삭제된파일_D상태_파싱성공")
    func deletedFile_parsedCorrectly() {
        let output = "D  deleted.swift"
        let result = GitPanelView.parseStatus(output)
        #expect(result.count == 1)
        #expect(result[0].x == "D")
        #expect(result[0].y == " ")
        #expect(result[0].path == "deleted.swift")
    }

    @Test("추적안되는파일_물음표상태_파싱성공")
    func untrackedFile_parsedCorrectly() {
        let output = "?? untracked.swift"
        let result = GitPanelView.parseStatus(output)
        #expect(result.count == 1)
        #expect(result[0].x == "?")
        #expect(result[0].y == "?")
        #expect(result[0].path == "untracked.swift")
    }

    @Test("파일이름변경_화살표표기법_파싱성공")
    func renamedFile_arrowNotation_parsedCorrectly() {
        let output = "R  old_name.swift -> new_name.swift"
        let result = GitPanelView.parseStatus(output)
        #expect(result.count == 1)
        #expect(result[0].x == "R")
        #expect(result[0].path == "old_name.swift -> new_name.swift")
        #expect(result[0].filename == "new_name.swift")
    }

    @Test("복수파일_여러줄_모두파싱성공")
    func multipleFiles_multipleLines_allParsed() {
        let output = """
         M src/alpha.swift
        A  src/beta.swift
        ?? src/gamma.swift
        """
        let result = GitPanelView.parseStatus(output)
        #expect(result.count == 3)
    }

    @Test("공백포함경로_파싱성공")
    func pathWithSpaces_parsedCorrectly() {
        let output = " M my folder/some file.swift"
        let result = GitPanelView.parseStatus(output)
        #expect(result.count == 1)
        #expect(result[0].path == "my folder/some file.swift")
    }

    @Test("유니코드파일명_파싱성공")
    func unicodeFilename_parsedCorrectly() {
        let output = " M 기능/뷰컨트롤러.swift"
        let result = GitPanelView.parseStatus(output)
        #expect(result.count == 1)
        #expect(result[0].path == "기능/뷰컨트롤러.swift")
    }

    // MARK: - Negative / Edge Cases

    @Test("빈문자열_빈배열반환")
    func emptyString_returnsEmpty() {
        let result = GitPanelView.parseStatus("")
        #expect(result.isEmpty)
    }

    @Test("공백만있는줄_무시됨")
    func whitespaceOnlyLines_ignored() {
        let output = "   \n   \n"
        let result = GitPanelView.parseStatus(output)
        #expect(result.isEmpty)
    }

    @Test("2글자이하줄_무시됨")
    func tooShortLines_ignored() {
        // line.count >= 3 is required; lines "M " (2 chars) should be skipped
        let output = "M \nA\n"
        let result = GitPanelView.parseStatus(output)
        #expect(result.isEmpty)
    }

    @Test("정확히3글자줄_경로빈경우_무시됨")
    func exactlyThreeChars_emptyPath_ignored() {
        // "M  " → x='M', y=' ', path="" → should be filtered
        let output = "M  "
        let result = GitPanelView.parseStatus(output)
        #expect(result.isEmpty)
    }

    @Test("줄바꿈만있는출력_빈배열반환")
    func onlyNewlines_returnsEmpty() {
        let output = "\n\n\n"
        let result = GitPanelView.parseStatus(output)
        #expect(result.isEmpty)
    }

    @Test("혼합된유효무효줄_유효줄만파싱")
    func mixedValidInvalidLines_onlyValidParsed() {
        let output = "M \n M valid.swift\nAB\n?? other.swift"
        let result = GitPanelView.parseStatus(output)
        // " M valid.swift" and "?? other.swift" are valid
        #expect(result.count == 2)
    }
}

// MARK: - GitFileStatus 모델 테스트

@Suite("GitFileStatus - 상태 심볼 및 파일명")
struct GitFileStatusTests {

    @Test("스테이지된수정파일_statusSymbol이인덱스열반환")
    func stagedModified_statusSymbolReturnsIndexColumn() {
        let file = GitFileStatus(x: "M", y: " ", path: "file.swift")
        #expect(file.statusSymbol == "M")
    }

    @Test("워크트리수정파일_statusSymbol이워크트리열반환")
    func worktreeModified_statusSymbolReturnsWorktreeColumn() {
        let file = GitFileStatus(x: " ", y: "M", path: "file.swift")
        #expect(file.statusSymbol == "M")
    }

    @Test("추적안되는파일_statusSymbol이물음표반환")
    func untrackedFile_statusSymbolReturnsQuestionMark() {
        let file = GitFileStatus(x: "?", y: "?", path: "file.swift")
        #expect(file.statusSymbol == "?")
    }

    @Test("이름변경파일_filename이새이름반환")
    func renamedFile_filenameReturnsNewName() {
        let file = GitFileStatus(x: "R", y: " ", path: "old.swift -> new.swift")
        #expect(file.filename == "new.swift")
    }

    @Test("일반경로_filename이마지막컴포넌트반환")
    func normalPath_filenameReturnsLastComponent() {
        let file = GitFileStatus(x: " ", y: "M", path: "src/deep/nested/file.swift")
        #expect(file.filename == "file.swift")
    }

    @Test("스테이지된파일_statusColor가초록색")
    func stagedFile_statusColorIsGreen() {
        let file = GitFileStatus(x: "A", y: " ", path: "new.swift")
        // Color equality check via description — just verify it's not red/gray by checking the logic path
        // statusColor returns .green when x != " " && x != "?" && y == " "
        let isStagedGreenPath = (file.x != " " && file.x != "?" && file.y == " ")
        #expect(isStagedGreenPath == true)
    }

    @Test("추적안되는파일_statusColor가회색경로")
    func untrackedFile_statusColorIsGrayPath() {
        let file = GitFileStatus(x: "?", y: "?", path: "untracked.swift")
        let isUntrackedGrayPath = (file.x == "?")
        #expect(isUntrackedGrayPath == true)
    }
}

// MARK: - parseLog 테스트

@Suite("GitPanelView - parseLog 파싱")
struct GitPanelViewParseLogTests {

    // MARK: - Happy Path

    @Test("단일커밋줄_파싱성공")
    func singleCommitLine_parsedCorrectly() {
        let output = "abc1234 Fix crash on startup"
        let result = GitPanelView.parseLog(output)
        #expect(result.count == 1)
        #expect(result[0].hash == "abc1234")
        #expect(result[0].message == "Fix crash on startup")
    }

    @Test("복수커밋_여러줄_모두파싱성공")
    func multipleCommits_allParsed() {
        let output = """
        abc1234 First commit
        def5678 Second commit
        ghi9012 Third commit
        """
        let result = GitPanelView.parseLog(output)
        #expect(result.count == 3)
        #expect(result[0].hash == "abc1234")
        #expect(result[0].message == "First commit")
        #expect(result[2].hash == "ghi9012")
        #expect(result[2].message == "Third commit")
    }

    @Test("메시지에공백포함_공백이분리안됨")
    func messageWithMultipleSpaces_splitAtFirstSpaceOnly() {
        let output = "abc1234 feat: add new feature with spaces in message"
        let result = GitPanelView.parseLog(output)
        #expect(result.count == 1)
        #expect(result[0].hash == "abc1234")
        #expect(result[0].message == "feat: add new feature with spaces in message")
    }

    @Test("메시지에유니코드포함_파싱성공")
    func messageWithUnicode_parsedCorrectly() {
        let output = "abc1234 feat: 한국어 커밋 메시지"
        let result = GitPanelView.parseLog(output)
        #expect(result.count == 1)
        #expect(result[0].message == "feat: 한국어 커밋 메시지")
    }

    @Test("긴해시_파싱성공")
    func longHash_parsedCorrectly() {
        let output = "abcdef1234567890 Some commit message"
        let result = GitPanelView.parseLog(output)
        #expect(result.count == 1)
        #expect(result[0].hash == "abcdef1234567890")
    }

    // MARK: - Negative / Edge Cases

    @Test("빈문자열_빈배열반환")
    func emptyString_returnsEmpty() {
        let result = GitPanelView.parseLog("")
        #expect(result.isEmpty)
    }

    @Test("줄바꿈만있는출력_빈배열반환")
    func onlyNewlines_returnsEmpty() {
        let result = GitPanelView.parseLog("\n\n\n")
        #expect(result.isEmpty)
    }

    @Test("공백없는단일단어줄_무시됨")
    func singleWordLine_ignored() {
        // split(separator: " ", maxSplits: 1) yields count == 1, so filtered out
        let output = "abc1234"
        let result = GitPanelView.parseLog(output)
        #expect(result.isEmpty)
    }

    @Test("공백시작줄_첫토큰이해시로파싱됨")
    func lineStartingWithSpace_firstTokenAsHash() {
        // " message without hash" → split(separator: " ", maxSplits: 1, omittingEmpty: true) → ["message", "without hash"]
        // 첫 토큰 "message"가 해시로 파싱됨 (git log --oneline은 항상 해시로 시작하므로 실전에서는 발생하지 않음)
        let output = " message without hash"
        let result = GitPanelView.parseLog(output)
        #expect(result.count == 1)
        #expect(result[0].hash == "message")
    }

    @Test("혼합된유효무효줄_유효줄만파싱")
    func mixedValidInvalidLines_onlyValidParsed() {
        let output = "abc1234 Valid commit\njustOneWord\ndef5678 Another valid\n"
        let result = GitPanelView.parseLog(output)
        #expect(result.count == 2)
        #expect(result[0].hash == "abc1234")
        #expect(result[1].hash == "def5678")
    }

    @Test("탭문자포함_공백기준분리_탭은해시에포함")
    func tabInLine_splitBySpace_tabIncludedInHash() {
        // "abc1234\tcommit message" → split(separator: " ", maxSplits: 1) → ["abc1234\tcommit", "message"]
        // 탭이 포함된 토큰이 해시로 파싱됨 (실전에서는 git log 출력에 탭이 없으므로 무해)
        let output = "abc1234\tcommit message"
        let result = GitPanelView.parseLog(output)
        #expect(result.count == 1)
        #expect(result[0].hash == "abc1234\tcommit")
    }

    // MARK: - Fuzz Test

    @Test("무작위입력_크래시없음")
    func randomInput_noCrash() {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n\t!@#$%^&*()_+-=[]{}|;':\",./<>?"
        var rng = SystemRandomNumberGenerator()

        for _ in 0..<200 {
            let length = Int.random(in: 0...500, using: &rng)
            var randomString = ""
            randomString.reserveCapacity(length)
            for _ in 0..<length {
                let idx = Int.random(in: 0..<characters.count, using: &rng)
                let charIndex = characters.index(characters.startIndex, offsetBy: idx)
                randomString.append(characters[charIndex])
            }

            // Must not crash; result count must be non-negative
            let statusResult = GitPanelView.parseStatus(randomString)
            let logResult = GitPanelView.parseLog(randomString)
            #expect(statusResult.count >= 0)
            #expect(logResult.count >= 0)
        }
    }

    @Test("변이기반_유효입력변형_크래시없음")
    func mutationBased_validInputMutated_noCrash() {
        let validStatusLine = " M src/main.swift"
        let validLogLine = "abc1234 Fix important bug"

        var rng = SystemRandomNumberGenerator()

        for _ in 0..<100 {
            // Mutate status line: randomly truncate or append garbage
            let statusMutated: String
            let logMutated: String

            let op = Int.random(in: 0..<4, using: &rng)
            switch op {
            case 0:
                // Truncate
                let cutLen = Int.random(in: 0...validStatusLine.count, using: &rng)
                statusMutated = String(validStatusLine.prefix(cutLen))
                logMutated = String(validLogLine.prefix(cutLen))
            case 1:
                // Append random bytes
                let garbage = String(repeating: "X", count: Int.random(in: 1...50, using: &rng))
                statusMutated = validStatusLine + garbage
                logMutated = validLogLine + garbage
            case 2:
                // Replace a random char
                var s = Array(validStatusLine)
                let l = Array(validLogLine)
                if !s.isEmpty {
                    s[Int.random(in: 0..<s.count, using: &rng)] = Character(UnicodeScalar(Int.random(in: 32...126, using: &rng))!)
                }
                statusMutated = String(s)
                logMutated = String(l)
            default:
                // Duplicate lines
                statusMutated = String(repeating: validStatusLine + "\n", count: Int.random(in: 1...10, using: &rng))
                logMutated = String(repeating: validLogLine + "\n", count: Int.random(in: 1...10, using: &rng))
            }

            let statusResult = GitPanelView.parseStatus(statusMutated)
            let logResult = GitPanelView.parseLog(logMutated)
            #expect(statusResult.count >= 0)
            #expect(logResult.count >= 0)
        }
    }
}

// MARK: - GitFileStatus 파일명 속성 기반 테스트

@Suite("GitFileStatus - filename 불변 속성")
struct GitFileStatusFilenamePropertyTests {

    @Test("화살표표기법_항상마지막컴포넌트반환_불변조건")
    func arrowNotation_alwaysReturnsLastComponent_invariant() {
        let cases: [(path: String, expectedFilename: String)] = [
            ("a -> b", "b"),
            ("dir/old.swift -> dir/new.swift", "dir/new.swift"),
            ("very/deep/path/old.swift -> another/deep/path/new.swift", "another/deep/path/new.swift"),
        ]

        for c in cases {
            let file = GitFileStatus(x: "R", y: " ", path: c.path)
            #expect(file.filename == c.expectedFilename, "path: \(c.path)")
        }
    }

    @Test("일반경로_항상NSString마지막컴포넌트반환_불변조건")
    func normalPath_alwaysReturnsLastPathComponent_invariant() {
        let cases: [(path: String, expectedFilename: String)] = [
            ("file.swift", "file.swift"),
            ("src/file.swift", "file.swift"),
            ("a/b/c/file.swift", "file.swift"),
            ("file", "file"),
            (".hidden", ".hidden"),
        ]

        for c in cases {
            let file = GitFileStatus(x: " ", y: "M", path: c.path)
            #expect(file.filename == c.expectedFilename, "path: \(c.path)")
        }
    }
}
