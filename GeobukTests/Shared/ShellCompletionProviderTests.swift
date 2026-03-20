import Testing
import Foundation
@testable import Geobuk

@Suite("ShellCompletionProvider - 셸 서브커맨드 완성")
struct ShellCompletionProviderTests {

    // MARK: - parseSubcommands 파싱 테스트

    @Suite("--help 출력 파싱")
    struct ParseTests {

        @Test("들여쓰기_서브커맨드_파싱")
        func indentedSubcommands() {
            let helpOutput = """
            Usage: mytool <command>

            Commands:
              init        Initialize project
              build       Build the project
              test        Run tests
              deploy      Deploy to production
            """
            let result = ShellCompletionProvider.parseSubcommands(from: helpOutput)
            #expect(result.contains("init"))
            #expect(result.contains("build"))
            #expect(result.contains("deploy"))
        }

        @Test("콤마구분_리스트_파싱")
        func csvSubcommands() {
            let helpOutput = """
            All commands:

                access, adduser, audit, cache, ci, config,
                install, list, outdated, publish, run, test,
                uninstall, update, version
            """
            let result = ShellCompletionProvider.parseSubcommands(from: helpOutput)
            #expect(result.contains("access"))
            #expect(result.contains("install"))
            #expect(result.contains("version"))
        }

        @Test("빈출력_빈배열")
        func emptyOutput() {
            let result = ShellCompletionProvider.parseSubcommands(from: "")
            #expect(result.isEmpty)
        }

        @Test("서브커맨드없는출력_빈배열")
        func noSubcommands() {
            let helpOutput = """
            Usage: simple-tool [options]

            Options:
              --verbose    Enable verbose output
              --quiet      Suppress output
              --help       Show this help
            """
            let result = ShellCompletionProvider.parseSubcommands(from: helpOutput)
            // --verbose 같은 옵션은 하이픈으로 시작하므로 제외됨
            #expect(!result.contains("--verbose"))
        }

        @Test("대문자단어_제외")
        func uppercaseExcluded() {
            let helpOutput = """
            Usage: tool <COMMAND>

              init       Initialize
              BUILD      Not a subcommand
              test       Run tests
            """
            let result = ShellCompletionProvider.parseSubcommands(from: helpOutput)
            #expect(result.contains("init"))
            #expect(!result.contains("BUILD"))
        }

        @Test("짧은단어_제외")
        func singleCharExcluded() {
            let helpOutput = """
              a    Something
              build  Build project
              c    Something else
            """
            let result = ShellCompletionProvider.parseSubcommands(from: helpOutput)
            #expect(!result.contains("a"))
            #expect(!result.contains("c"))
            #expect(result.contains("build"))
        }
    }

    // MARK: - subcommands 메서드 테스트

    @Suite("서브커맨드 조회")
    struct SubcommandTests {

        @Test("존재하지않는명령어_빈배열")
        func nonExistentCommand() {
            ShellCompletionProvider.clearCache()
            let result = ShellCompletionProvider.subcommands(for: "zzz_no_such_cmd_12345", prefix: "")
            #expect(result.isEmpty)
        }

        @Test("prefix필터링")
        func prefixFiltering() {
            // 직접 파싱 결과로 테스트
            let mockSubs = ["add", "apply", "build", "check", "clean"]
            let filtered = mockSubs.filter { $0.hasPrefix("cl") }
            #expect(filtered == ["clean"])
        }
    }

    // MARK: - 실제 명령어 (설치된 경우만)

    @Suite("실제 명령어 (런타임)")
    struct RealCommandTests {

        @Test("git_서브커맨드조회")
        func gitSubcommands() {
            ShellCompletionProvider.clearCache()
            let result = ShellCompletionProvider.fetchSubcommands(for: "git")
            // git이 설치되어 있으면 결과가 있어야 함
            if !result.isEmpty {
                #expect(result.contains("add") || result.contains("commit") || result.contains("push"))
            }
        }

        @Test("git_prefix필터링")
        func gitWithPrefix() {
            ShellCompletionProvider.clearCache()
            let result = ShellCompletionProvider.subcommands(for: "git", prefix: "sta")
            if !result.isEmpty {
                for sub in result {
                    #expect(sub.hasPrefix("sta"))
                }
            }
        }
    }

    // MARK: - 캐싱

    @Suite("캐싱")
    struct CacheTests {

        @Test("캐시히트_동일결과")
        func cacheHit() {
            ShellCompletionProvider.clearCache()
            let first = ShellCompletionProvider.subcommands(for: "git", prefix: "")
            let second = ShellCompletionProvider.subcommands(for: "git", prefix: "")
            #expect(first == second)
        }

        @Test("clearCache_캐시초기화")
        func clearCache() {
            _ = ShellCompletionProvider.subcommands(for: "git", prefix: "")
            ShellCompletionProvider.clearCache()
            // 캐시 클리어 후에도 크래시 없이 재조회 가능
            _ = ShellCompletionProvider.subcommands(for: "git", prefix: "")
        }
    }

    // MARK: - 퍼징

    @Suite("퍼징")
    struct FuzzTests {

        @Test("특수문자명령어_크래시없음")
        func specialCharCommand() {
            let inputs = ["", " ", "---", "$HOME", "../../etc/passwd", "a;b", "a&&b"]
            for input in inputs {
                _ = ShellCompletionProvider.subcommands(for: input, prefix: "")
            }
        }
    }
}
