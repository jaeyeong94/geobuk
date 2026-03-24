import Testing
import Foundation
@testable import Geobuk

@Suite("TabCompletionParser - Tab 출력 파싱")
struct TabCompletionParserTests {

    // MARK: - ANSI 제거

    @Test("stripAnsi_컬러코드_제거")
    func stripAnsi_colorCodes_removed() {
        let input = "\u{1B}[32mhello\u{1B}[0m world"
        #expect(TabCompletionParser.stripAnsi(input) == "hello world")
    }

    @Test("stripAnsi_커서이동_제거")
    func stripAnsi_cursorMove_removed() {
        let input = "\u{1B}[2Kfoo\u{1B}[1A"
        #expect(TabCompletionParser.stripAnsi(input) == "foo")
    }

    @Test("stripAnsi_일반텍스트_변경없음")
    func stripAnsi_plainText_unchanged() {
        let input = "just plain text"
        #expect(TabCompletionParser.stripAnsi(input) == "just plain text")
    }

    @Test("stripAnsi_빈문자열_빈문자열")
    func stripAnsi_empty_empty() {
        #expect(TabCompletionParser.stripAnsi("") == "")
    }

    // MARK: - zsh 단일 완성

    @Test("parseZsh_단일완성_자동완성됨")
    func parseZsh_singleCompletion_autoCompleted() {
        // "git check" + Tab → 셸이 "git checkout " 출력
        let result = TabCompletionParser.parseZsh(
            input: "git check",
            output: "git checkout "
        )
        #expect(result == ["git checkout"])
    }

    @Test("parseZsh_단일완성_슬래시포함")
    func parseZsh_singleCompletion_withSlash() {
        // "cd ~/Doc" + Tab → "cd ~/Documents/"
        let result = TabCompletionParser.parseZsh(
            input: "cd ~/Doc",
            output: "cd ~/Documents/"
        )
        #expect(result == ["cd ~/Documents/"])
    }

    // MARK: - zsh 다중 완성

    @Test("parseZsh_다중완성_공백구분")
    func parseZsh_multipleCompletions_spaceSeparated() {
        // "git ch" + Tab → 후보 나열
        let result = TabCompletionParser.parseZsh(
            input: "git ch",
            output: "checkout  cherry  cherry-pick"
        )
        #expect(result.contains("checkout"))
        #expect(result.contains("cherry"))
        #expect(result.contains("cherry-pick"))
    }

    @Test("parseZsh_다중완성_여러줄")
    func parseZsh_multipleCompletions_multiLine() {
        let result = TabCompletionParser.parseZsh(
            input: "git c",
            output: "checkout  cherry  cherry-pick\nclean  clone  commit"
        )
        #expect(result.count >= 6)
        #expect(result.contains("checkout"))
        #expect(result.contains("commit"))
    }

    @Test("parseZsh_다중완성_describe형식")
    func parseZsh_multipleCompletions_describeFormat() {
        // zsh describe: "candidate -- description"
        let result = TabCompletionParser.parseZsh(
            input: "git ch",
            output: "checkout -- Switch branches\ncherry -- Apply changes\ncherry-pick -- Apply commit"
        )
        #expect(result.contains("checkout"))
        #expect(result.contains("cherry"))
        #expect(result.contains("cherry-pick"))
    }

    // MARK: - zsh 완성 없음

    @Test("parseZsh_완성없음_빈배열")
    func parseZsh_noCompletion_emptyArray() {
        let result = TabCompletionParser.parseZsh(
            input: "xyzabc123",
            output: ""
        )
        #expect(result.isEmpty)
    }

    @Test("parseZsh_벨문자만_빈배열")
    func parseZsh_bellOnly_emptyArray() {
        let result = TabCompletionParser.parseZsh(
            input: "xyzabc",
            output: "\u{07}"
        )
        #expect(result.isEmpty)
    }

    @Test("parseZsh_입력과동일_빈배열")
    func parseZsh_sameAsInput_emptyArray() {
        let result = TabCompletionParser.parseZsh(
            input: "git status",
            output: "git status"
        )
        #expect(result.isEmpty)
    }

    // MARK: - bash 파싱

    @Test("parseBash_다중완성_공백구분")
    func parseBash_multipleCompletions_spaceSeparated() {
        let result = TabCompletionParser.parseBash(
            input: "git ch",
            output: "checkout  cherry  cherry-pick"
        )
        #expect(result.contains("checkout"))
        #expect(result.contains("cherry"))
        #expect(result.contains("cherry-pick"))
    }

    @Test("parseBash_단일완성")
    func parseBash_singleCompletion() {
        let result = TabCompletionParser.parseBash(
            input: "git check",
            output: "git checkout "
        )
        #expect(result == ["git checkout"])
    }

    @Test("parseBash_완성없음_빈배열")
    func parseBash_noCompletion_emptyArray() {
        let result = TabCompletionParser.parseBash(
            input: "xyzabc",
            output: ""
        )
        #expect(result.isEmpty)
    }

    // MARK: - 파일 경로 완성

    @Test("parseZsh_파일경로_디렉토리목록")
    func parseZsh_filePath_directoryList() {
        let result = TabCompletionParser.parseZsh(
            input: "ls ",
            output: "Desktop/    Documents/  Downloads/"
        )
        #expect(result.contains("Desktop/"))
        #expect(result.contains("Documents/"))
        #expect(result.contains("Downloads/"))
    }

    // MARK: - 엣지 케이스

    @Test("parseZsh_ANSI포함출력_정상파싱")
    func parseZsh_ansiInOutput_parsedCorrectly() {
        let result = TabCompletionParser.parseZsh(
            input: "git ch",
            output: "\u{1B}[32mcheckout\u{1B}[0m  \u{1B}[32mcherry\u{1B}[0m"
        )
        #expect(result.contains("checkout"))
        #expect(result.contains("cherry"))
    }

    @Test("parseZsh_탭문자구분_정상파싱")
    func parseZsh_tabSeparated_parsedCorrectly() {
        let result = TabCompletionParser.parseZsh(
            input: "ls ",
            output: "file1.txt\tfile2.txt\tfile3.txt"
        )
        #expect(result.count == 3)
    }

    @Test("parseZsh_빈입력_빈배열")
    func parseZsh_emptyInput_emptyArray() {
        let result = TabCompletionParser.parseZsh(input: "", output: "")
        #expect(result.isEmpty)
    }
}
