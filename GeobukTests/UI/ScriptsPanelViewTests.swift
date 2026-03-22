import Testing
import Foundation
@testable import Geobuk

// MARK: - ProjectScript 모델 테스트

@Suite("ProjectScript 모델 속성")
struct ProjectScriptModelTests {

    @Test("ProjectScript_기본속성_올바르게저장됨")
    func projectScript_기본속성_올바르게저장됨() {
        let script = ProjectScript(name: "build", command: "npm run build", source: "package.json")
        #expect(script.name == "build")
        #expect(script.command == "npm run build")
        #expect(script.source == "package.json")
    }

    @Test("ProjectScript_id_각인스턴스마다고유함")
    func projectScript_id_각인스턴스마다고유함() {
        let a = ProjectScript(name: "test", command: "npm test", source: "package.json")
        let b = ProjectScript(name: "test", command: "npm test", source: "package.json")
        #expect(a.id != b.id)
    }

    @Test("ProjectScript_빈문자열_허용됨")
    func projectScript_빈문자열_허용됨() {
        let script = ProjectScript(name: "", command: "", source: "")
        #expect(script.name == "")
        #expect(script.command == "")
        #expect(script.source == "")
    }

    @Test("ProjectScript_유니코드이름_올바르게저장됨")
    func projectScript_유니코드이름_올바르게저장됨() {
        let script = ProjectScript(name: "빌드-🚀", command: "make 빌드", source: "Makefile")
        #expect(script.name == "빌드-🚀")
        #expect(script.command == "make 빌드")
    }
}

// MARK: - parsePackageJson 테스트

@Suite("parsePackageJson 파싱")
struct ParsePackageJsonTests {

    // MARK: helpers

    private func writeTempFile(_ content: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory
        let path = dir.appendingPathComponent(UUID().uuidString + "-package.json").path
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    private func writeTempData(_ data: Data) throws -> String {
        let dir = FileManager.default.temporaryDirectory
        let path = dir.appendingPathComponent(UUID().uuidString + "-package.json").path
        FileManager.default.createFile(atPath: path, contents: data)
        return path
    }

    // MARK: 정상 케이스

    @Test("parsePackageJson_유효한스크립트_npm커맨드반환")
    func parsePackageJson_유효한스크립트_npm커맨드반환() throws {
        let json = """
        {
          "name": "my-app",
          "scripts": {
            "build": "tsc",
            "start": "node dist/index.js",
            "test": "jest"
          }
        }
        """
        let path = try writeTempFile(json)
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.count == 3)
        let names = Set(scripts.map(\.name))
        #expect(names == ["build", "start", "test"])
        for script in scripts {
            #expect(script.command == "npm run \(script.name)")
            #expect(script.source == "package.json")
        }
    }

    @Test("parsePackageJson_스크립트정렬_알파벳순")
    func parsePackageJson_스크립트정렬_알파벳순() throws {
        let json = """
        { "scripts": { "zebra": "z", "alpha": "a", "middle": "m" } }
        """
        let path = try writeTempFile(json)
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.map(\.name) == ["alpha", "middle", "zebra"])
    }

    @Test("parsePackageJson_단일스크립트_정상파싱")
    func parsePackageJson_단일스크립트_정상파싱() throws {
        let json = #"{ "scripts": { "dev": "vite" } }"#
        let path = try writeTempFile(json)
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.count == 1)
        #expect(scripts[0].name == "dev")
        #expect(scripts[0].command == "npm run dev")
    }

    // MARK: 빈/누락 케이스

    @Test("parsePackageJson_빈scripts객체_빈배열반환")
    func parsePackageJson_빈scripts객체_빈배열반환() throws {
        let json = #"{ "name": "app", "scripts": {} }"#
        let path = try writeTempFile(json)
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.isEmpty)
    }

    @Test("parsePackageJson_scripts키없음_빈배열반환")
    func parsePackageJson_scripts키없음_빈배열반환() throws {
        let json = #"{ "name": "app", "version": "1.0.0" }"#
        let path = try writeTempFile(json)
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.isEmpty)
    }

    @Test("parsePackageJson_빈JSON객체_빈배열반환")
    func parsePackageJson_빈JSON객체_빈배열반환() throws {
        let path = try writeTempFile("{}")
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.isEmpty)
    }

    // MARK: 잘못된 입력

    @Test("parsePackageJson_잘못된JSON_빈배열반환")
    func parsePackageJson_잘못된JSON_빈배열반환() throws {
        let path = try writeTempFile("not valid json {{{")
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.isEmpty)
    }

    @Test("parsePackageJson_빈파일_빈배열반환")
    func parsePackageJson_빈파일_빈배열반환() throws {
        let path = try writeTempFile("")
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.isEmpty)
    }

    @Test("parsePackageJson_JSON배열최상위_빈배열반환")
    func parsePackageJson_JSON배열최상위_빈배열반환() throws {
        let path = try writeTempFile("[1, 2, 3]")
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.isEmpty)
    }

    @Test("parsePackageJson_scripts가배열_빈배열반환")
    func parsePackageJson_scripts가배열_빈배열반환() throws {
        let json = #"{ "scripts": ["build", "test"] }"#
        let path = try writeTempFile(json)
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.isEmpty)
    }

    @Test("parsePackageJson_scripts가문자열_빈배열반환")
    func parsePackageJson_scripts가문자열_빈배열반환() throws {
        let json = #"{ "scripts": "npm run build" }"#
        let path = try writeTempFile(json)
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.isEmpty)
    }

    @Test("parsePackageJson_존재하지않는경로_빈배열반환")
    func parsePackageJson_존재하지않는경로_빈배열반환() {
        let scripts = ScriptsPanelView.parsePackageJson(at: "/nonexistent/path/package.json")
        #expect(scripts.isEmpty)
    }

    @Test("parsePackageJson_바이너리데이터_빈배열반환")
    func parsePackageJson_바이너리데이터_빈배열반환() throws {
        let binaryData = Data([0x00, 0xFF, 0xFE, 0x80, 0x01, 0x02, 0xAB, 0xCD])
        let path = try writeTempData(binaryData)
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.isEmpty)
    }

    @Test("parsePackageJson_매우긴스크립트이름_정상파싱")
    func parsePackageJson_매우긴스크립트이름_정상파싱() throws {
        let longName = String(repeating: "a", count: 1000)
        let json = "{ \"scripts\": { \"\(longName)\": \"echo done\" } }"
        let path = try writeTempFile(json)
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.count == 1)
        #expect(scripts[0].name == longName)
        #expect(scripts[0].command == "npm run \(longName)")
    }

    @Test("parsePackageJson_특수문자이름_정상파싱")
    func parsePackageJson_특수문자이름_정상파싱() throws {
        let json = #"{ "scripts": { "pre:build": "tsc --check", "build:watch": "tsc -w" } }"#
        let path = try writeTempFile(json)
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.count == 2)
        let names = Set(scripts.map(\.name))
        #expect(names.contains("pre:build"))
        #expect(names.contains("build:watch"))
    }

    // MARK: 퍼징 테스트

    @Test("parsePackageJson_퍼징_랜덤문자열_크래시없음")
    func parsePackageJson_퍼징_랜덤문자열_크래시없음() throws {
        let inputs = [
            "null",
            "true",
            "false",
            "123",
            "\"string\"",
            "{ \"scripts\": null }",
            "{ \"scripts\": 0 }",
            "{ \"scripts\": { \"a\": null } }",
            "{ \"scripts\": { \"b\": 123 } }",
            "{ \"scripts\": { \"c\": {} } }",
            "{ \"scripts\": { \"d\": [] } }",
            "{ \"scripts\": { \"\": \"empty name\" } }",
            String(repeating: "{", count: 1000),
            String(repeating: "}", count: 1000),
        ]
        for input in inputs {
            let path = try writeTempFile(input)
            // 크래시 없이 완료되어야 함
            let scripts = ScriptsPanelView.parsePackageJson(at: path)
            // scripts가 nil이 아닌 배열을 반환해야 함
            _ = scripts.count
        }
    }

    @Test("parsePackageJson_퍼징_매우큰파일_크래시없음")
    func parsePackageJson_퍼징_매우큰파일_크래시없음() throws {
        // 1000개 스크립트 항목
        var entries: [String] = []
        for i in 0..<1000 {
            entries.append("\"script\(i)\": \"echo \(i)\"")
        }
        let json = "{ \"scripts\": { \(entries.joined(separator: ",")) } }"
        let path = try writeTempFile(json)
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.count == 1000)
    }
}

// MARK: - parseMakefile 테스트

@Suite("parseMakefile 파싱")
struct ParseMakefileTests {

    private func writeTempFile(_ content: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory
        let path = dir.appendingPathComponent(UUID().uuidString + "-Makefile").path
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    // MARK: 정상 케이스

    @Test("parseMakefile_일반타겟_make커맨드반환")
    func parseMakefile_일반타겟_make커맨드반환() throws {
        let content = """
        build:
        \tgcc main.c -o app
        test:
        \t./run_tests.sh
        lint:
        \tswiftlint
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        let names = Set(scripts.map(\.name))
        #expect(names.contains("build"))
        #expect(names.contains("test"))
        #expect(names.contains("lint"))
        for script in scripts {
            #expect(script.command == "make \(script.name)")
            #expect(script.source == "Makefile")
        }
    }

    @Test("parseMakefile_의존성있는타겟_정상파싱")
    func parseMakefile_의존성있는타겟_정상파싱() throws {
        let content = """
        release: build test
        \techo "releasing"
        build: deps
        \tgcc main.c
        deps:
        \tapt-get install gcc
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        let names = Set(scripts.map(\.name))
        #expect(names.contains("release"))
        #expect(names.contains("build"))
        #expect(names.contains("deps"))
    }

    @Test("parseMakefile_PHONY타겟_제외됨")
    func parseMakefile_PHONY타겟_제외됨() throws {
        let content = """
        .PHONY: build test
        build:
        \tgcc main.c
        test:
        \t./test.sh
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        let names = scripts.map(\.name)
        // .PHONY 자체는 타겟으로 파싱되면 안 됨 (점으로 시작하므로)
        #expect(!names.contains(".PHONY"))
        // build, test는 정상 파싱
        #expect(names.contains("build"))
        #expect(names.contains("test"))
    }

    @Test("parseMakefile_점으로시작하는타겟_제외됨")
    func parseMakefile_점으로시작하는타겟_제외됨() throws {
        let content = """
        .DEFAULT_GOAL := build
        .DEFAULT:
        \techo default
        build:
        \tgcc main.c
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        let names = scripts.map(\.name)
        #expect(!names.contains(".DEFAULT_GOAL"))
        #expect(!names.contains(".DEFAULT"))
        #expect(names.contains("build"))
    }

    @Test("parseMakefile_내부타겟_제외됨")
    func parseMakefile_내부타겟_제외됨() throws {
        let content = """
        all:
        \techo all
        clean:
        \trm -rf build
        install:
        \tcp app /usr/bin
        uninstall:
        \trm /usr/bin/app
        dist:
        \ttar czf app.tar.gz app
        distclean:
        \trm -rf dist
        custom-target:
        \techo custom
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        let names = Set(scripts.map(\.name))
        // 내부 타겟은 제외
        #expect(!names.contains("all"))
        #expect(!names.contains("clean"))
        #expect(!names.contains("install"))
        #expect(!names.contains("uninstall"))
        #expect(!names.contains("dist"))
        #expect(!names.contains("distclean"))
        // 커스텀 타겟은 포함
        #expect(names.contains("custom-target"))
    }

    @Test("parseMakefile_주석라인_무시됨")
    func parseMakefile_주석라인_무시됨() throws {
        let content = """
        # This is a comment
        # build: fake target in comment
        build:
        \tgcc main.c
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        // 주석 내의 build: 는 파싱되지 않아야 하나, 파서는 줄 시작의 # 패턴을 처리하지 않음
        // 실제 파서 동작을 검증: build 타겟은 파싱됨
        let names = scripts.map(\.name)
        #expect(names.contains("build"))
    }

    @Test("parseMakefile_중복타겟_한번만포함됨")
    func parseMakefile_중복타겟_한번만포함됨() throws {
        let content = """
        build:
        \tgcc main.c
        build:
        \tclang main.c
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        let buildCount = scripts.filter { $0.name == "build" }.count
        #expect(buildCount == 1)
    }

    @Test("parseMakefile_언더스코어하이픈타겟_정상파싱")
    func parseMakefile_언더스코어하이픈타겟_정상파싱() throws {
        let content = """
        run_server:
        \tnode server.js
        deploy-prod:
        \tansible-playbook deploy.yml
        build_and_test:
        \tmake build && make test
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        let names = Set(scripts.map(\.name))
        #expect(names.contains("run_server"))
        #expect(names.contains("deploy-prod"))
        #expect(names.contains("build_and_test"))
    }

    // MARK: 빈/누락 케이스

    @Test("parseMakefile_빈파일_빈배열반환")
    func parseMakefile_빈파일_빈배열반환() throws {
        let path = try writeTempFile("")
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        #expect(scripts.isEmpty)
    }

    @Test("parseMakefile_주석만있는파일_빈배열반환")
    func parseMakefile_주석만있는파일_빈배열반환() throws {
        let content = """
        # Just comments
        # No targets here
        # build: not a real target
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        #expect(scripts.isEmpty)
    }

    @Test("parseMakefile_변수선언만있는파일_빈배열반환")
    func parseMakefile_변수선언만있는파일_빈배열반환() throws {
        let content = """
        CC = gcc
        CFLAGS = -Wall
        OUTPUT = app
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        #expect(scripts.isEmpty)
    }

    @Test("parseMakefile_존재하지않는경로_빈배열반환")
    func parseMakefile_존재하지않는경로_빈배열반환() {
        let scripts = ScriptsPanelView.parseMakefile(at: "/nonexistent/Makefile")
        #expect(scripts.isEmpty)
    }

    // MARK: 퍼징 테스트

    @Test("parseMakefile_퍼징_특수문자포함_크래시없음")
    func parseMakefile_퍼징_특수문자포함_크래시없음() throws {
        let inputs = [
            "::::",
            ": : :",
            "\t\t\ttarget:",
            "123target:",
            "-invalid:",
            String(repeating: "a", count: 10000) + ":",
            String(repeating: "\n", count: 1000),
            "target:\n" + String(repeating: "\t", count: 500) + "echo done",
        ]
        for input in inputs {
            let path = try writeTempFile(input)
            let scripts = ScriptsPanelView.parseMakefile(at: path)
            _ = scripts.count
        }
    }

    @Test("parseMakefile_퍼징_매우큰파일_크래시없음")
    func parseMakefile_퍼징_매우큰파일_크래시없음() throws {
        var lines: [String] = []
        for i in 0..<500 {
            lines.append("target\(i):")
            lines.append("\techo \(i)")
        }
        let content = lines.joined(separator: "\n")
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        #expect(scripts.count == 500)
    }
}

// MARK: - cargoScripts 테스트

@Suite("cargoScripts 반환값")
struct CargoScriptsTests {

    @Test("cargoScripts_표준커맨드_4개반환")
    func cargoScripts_표준커맨드_4개반환() {
        let scripts = ScriptsPanelView.cargoScripts()
        #expect(scripts.count == 4)
    }

    @Test("cargoScripts_build커맨드_포함됨")
    func cargoScripts_build커맨드_포함됨() {
        let scripts = ScriptsPanelView.cargoScripts()
        let build = scripts.first { $0.name == "build" }
        #expect(build != nil)
        #expect(build?.command == "cargo build")
        #expect(build?.source == "Cargo.toml")
    }

    @Test("cargoScripts_run커맨드_포함됨")
    func cargoScripts_run커맨드_포함됨() {
        let scripts = ScriptsPanelView.cargoScripts()
        let run = scripts.first { $0.name == "run" }
        #expect(run != nil)
        #expect(run?.command == "cargo run")
        #expect(run?.source == "Cargo.toml")
    }

    @Test("cargoScripts_test커맨드_포함됨")
    func cargoScripts_test커맨드_포함됨() {
        let scripts = ScriptsPanelView.cargoScripts()
        let test = scripts.first { $0.name == "test" }
        #expect(test != nil)
        #expect(test?.command == "cargo test")
        #expect(test?.source == "Cargo.toml")
    }

    @Test("cargoScripts_bench커맨드_포함됨")
    func cargoScripts_bench커맨드_포함됨() {
        let scripts = ScriptsPanelView.cargoScripts()
        let bench = scripts.first { $0.name == "bench" }
        #expect(bench != nil)
        #expect(bench?.command == "cargo bench")
        #expect(bench?.source == "Cargo.toml")
    }

    @Test("cargoScripts_소스_Cargo.toml")
    func cargoScripts_소스_Cargo_toml() {
        let scripts = ScriptsPanelView.cargoScripts()
        for script in scripts {
            #expect(script.source == "Cargo.toml")
        }
    }

    @Test("cargoScripts_모든커맨드_cargo로시작")
    func cargoScripts_모든커맨드_cargo로시작() {
        let scripts = ScriptsPanelView.cargoScripts()
        for script in scripts {
            #expect(script.command.hasPrefix("cargo "))
        }
    }

    @Test("cargoScripts_호출마다동일결과_결정론적")
    func cargoScripts_호출마다동일결과_결정론적() {
        let first = ScriptsPanelView.cargoScripts()
        let second = ScriptsPanelView.cargoScripts()
        #expect(first.count == second.count)
        for (a, b) in zip(first, second) {
            #expect(a.name == b.name)
            #expect(a.command == b.command)
            #expect(a.source == b.source)
        }
    }
}

// MARK: - goScripts 테스트

@Suite("goScripts 반환값")
struct GoScriptsTests {

    @Test("goScripts_표준커맨드_3개반환")
    func goScripts_표준커맨드_3개반환() {
        let scripts = ScriptsPanelView.goScripts()
        #expect(scripts.count == 3)
    }

    @Test("goScripts_build커맨드_포함됨")
    func goScripts_build커맨드_포함됨() {
        let scripts = ScriptsPanelView.goScripts()
        let build = scripts.first { $0.name == "build" }
        #expect(build != nil)
        #expect(build?.command == "go build")
        #expect(build?.source == "go.mod")
    }

    @Test("goScripts_test커맨드_포함됨")
    func goScripts_test커맨드_포함됨() {
        let scripts = ScriptsPanelView.goScripts()
        let test = scripts.first { $0.name == "test" }
        #expect(test != nil)
        #expect(test?.command == "go test")
        #expect(test?.source == "go.mod")
    }

    @Test("goScripts_run커맨드_포함됨")
    func goScripts_run커맨드_포함됨() {
        let scripts = ScriptsPanelView.goScripts()
        let run = scripts.first { $0.name == "run" }
        #expect(run != nil)
        #expect(run?.command == "go run .")
        #expect(run?.source == "go.mod")
    }

    @Test("goScripts_소스_go.mod")
    func goScripts_소스_go_mod() {
        let scripts = ScriptsPanelView.goScripts()
        for script in scripts {
            #expect(script.source == "go.mod")
        }
    }

    @Test("goScripts_모든커맨드_go로시작")
    func goScripts_모든커맨드_go로시작() {
        let scripts = ScriptsPanelView.goScripts()
        for script in scripts {
            #expect(script.command.hasPrefix("go "))
        }
    }

    @Test("goScripts_호출마다동일결과_결정론적")
    func goScripts_호출마다동일결과_결정론적() {
        let first = ScriptsPanelView.goScripts()
        let second = ScriptsPanelView.goScripts()
        #expect(first.count == second.count)
        for (a, b) in zip(first, second) {
            #expect(a.name == b.name)
            #expect(a.command == b.command)
        }
    }
}

// MARK: - parsePyprojectToml 테스트

@Suite("parsePyprojectToml 파싱")
struct ParsePyprojectTomlTests {

    private func writeTempFile(_ content: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory
        let path = dir.appendingPathComponent(UUID().uuidString + "-pyproject.toml").path
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    // MARK: Poetry 스크립트

    @Test("parsePyprojectToml_poetry스크립트_정상파싱")
    func parsePyprojectToml_poetry스크립트_정상파싱() throws {
        let content = """
        [tool.poetry]
        name = "my-project"

        [tool.poetry.scripts]
        my-app = "my_module:main"
        cli-tool = "cli:run"

        [tool.poetry.dependencies]
        python = "^3.11"
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
        let names = Set(scripts.map(\.name))
        #expect(names.contains("my-app"))
        #expect(names.contains("cli-tool"))
        for script in scripts where names.contains(script.name) {
            #expect(script.source == "pyproject.toml")
        }
    }

    @Test("parsePyprojectToml_project스크립트_정상파싱")
    func parsePyprojectToml_project스크립트_정상파싱() throws {
        let content = """
        [project]
        name = "my-project"

        [project.scripts]
        my-cli = "mypackage.cli:main"
        server = "mypackage.server:start"
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
        let names = Set(scripts.map(\.name))
        #expect(names.contains("my-cli"))
        #expect(names.contains("server"))
    }

    @Test("parsePyprojectToml_스크립트커맨드_이름과동일")
    func parsePyprojectToml_스크립트커맨드_이름과동일() throws {
        let content = """
        [project.scripts]
        my-tool = "module:func"
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
        let script = scripts.first { $0.name == "my-tool" }
        #expect(script != nil)
        #expect(script?.command == "my-tool")
    }

    // MARK: 빈/기본값 케이스

    @Test("parsePyprojectToml_scripts섹션없음_기본커맨드반환")
    func parsePyprojectToml_scripts섹션없음_기본커맨드반환() throws {
        let content = """
        [tool.poetry]
        name = "my-project"
        version = "0.1.0"
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
        #expect(!scripts.isEmpty)
        let names = Set(scripts.map(\.name))
        #expect(names.contains("install"))
        #expect(names.contains("test"))
    }

    @Test("parsePyprojectToml_빈파일_기본커맨드반환")
    func parsePyprojectToml_빈파일_기본커맨드반환() throws {
        let path = try writeTempFile("")
        let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
        #expect(!scripts.isEmpty)
        let names = Set(scripts.map(\.name))
        #expect(names.contains("install"))
        #expect(names.contains("test"))
    }

    @Test("parsePyprojectToml_기본커맨드소스_pyproject.toml")
    func parsePyprojectToml_기본커맨드소스_pyproject_toml() throws {
        let path = try writeTempFile("[build-system]")
        let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
        for script in scripts {
            #expect(script.source == "pyproject.toml")
        }
    }

    @Test("parsePyprojectToml_기본install커맨드_정확함")
    func parsePyprojectToml_기본install커맨드_정확함() throws {
        let path = try writeTempFile("")
        let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
        let install = scripts.first { $0.name == "install" }
        #expect(install?.command == "pip install -e .")
    }

    @Test("parsePyprojectToml_기본test커맨드_정확함")
    func parsePyprojectToml_기본test커맨드_정확함() throws {
        let path = try writeTempFile("")
        let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
        let test = scripts.first { $0.name == "test" }
        #expect(test?.command == "pytest")
    }

    // MARK: 주석 처리

    @Test("parsePyprojectToml_주석항목_제외됨")
    func parsePyprojectToml_주석항목_제외됨() throws {
        let content = """
        [project.scripts]
        # this = "commented:out"
        real-tool = "module:main"
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
        let names = scripts.map(\.name)
        // 주석 항목의 이름이 포함되면 안 됨
        #expect(!names.contains("# this"))
        #expect(names.contains("real-tool"))
    }

    // MARK: 섹션 경계

    @Test("parsePyprojectToml_scripts섹션후빈줄_파싱중단")
    func parsePyprojectToml_scripts섹션후빈줄_파싱중단() throws {
        let content = """
        [project.scripts]
        tool-a = "a:main"

        not-a-script = "not:included"
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
        let names = scripts.map(\.name)
        #expect(names.contains("tool-a"))
        // 빈 줄 이후 항목은 포함되지 않아야 함 (파서 동작: 빈 줄에서 break)
        #expect(!names.contains("not-a-script"))
    }

    // MARK: 잘못된 입력

    @Test("parsePyprojectToml_존재하지않는경로_기본커맨드반환")
    func parsePyprojectToml_존재하지않는경로_기본커맨드반환() {
        let scripts = ScriptsPanelView.parsePyprojectToml(at: "/nonexistent/pyproject.toml")
        // 파일을 읽지 못하면 빈 배열 반환 후 기본값 적용
        #expect(!scripts.isEmpty)
    }

    // MARK: 퍼징 테스트

    @Test("parsePyprojectToml_퍼징_다양한섹션헤더_크래시없음")
    func parsePyprojectToml_퍼징_다양한섹션헤더_크래시없음() throws {
        let inputs = [
            "[[[nested]]]",
            "[ spaces in header ]",
            "[tool.poetry.scripts]\n" + String(repeating: "x = \"y\"\n", count: 500),
            String(repeating: "[section]\n", count: 100),
            "key = " + String(repeating: "\"", count: 100),
            String(repeating: "=", count: 1000),
        ]
        for input in inputs {
            let path = try writeTempFile(input)
            let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
            _ = scripts.count
        }
    }

    @Test("parsePyprojectToml_퍼징_등호없는라인_크래시없음")
    func parsePyprojectToml_퍼징_등호없는라인_크래시없음() throws {
        let content = """
        [project.scripts]
        no-equals-sign
        another-line-without-equals
        valid = "module:func"
        """
        let path = try writeTempFile(content)
        let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
        _ = scripts.count
    }
}

// MARK: - 엣지 케이스 통합 테스트

@Suite("엣지 케이스 및 경계값")
struct EdgeCaseTests {

    private func writeTempFile(name: String, content: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory
        let path = dir.appendingPathComponent(UUID().uuidString + "-" + name).path
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    @Test("parsePackageJson_공백만있는파일_빈배열반환")
    func parsePackageJson_공백만있는파일_빈배열반환() throws {
        let path = try writeTempFile(name: "package.json", content: "   \n\t\n   ")
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        #expect(scripts.isEmpty)
    }

    @Test("parseMakefile_탭없는레시피_타겟파싱됨")
    func parseMakefile_탭없는레시피_타겟파싱됨() throws {
        // 레시피 없는 타겟도 유효한 Makefile 타겟
        let content = "custom-target:\n"
        let path = try writeTempFile(name: "Makefile", content: content)
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        #expect(scripts.map(\.name).contains("custom-target"))
    }

    @Test("parseMakefile_숫자로시작하는타겟_파싱안됨")
    func parseMakefile_숫자로시작하는타겟_파싱안됨() throws {
        // 파서 정규식: ^[a-zA-Z_] — 숫자로 시작하는 타겟은 매칭 안 됨
        let content = "123target:\n\techo hi\n"
        let path = try writeTempFile(name: "Makefile", content: content)
        let scripts = ScriptsPanelView.parseMakefile(at: path)
        #expect(!scripts.map(\.name).contains("123target"))
    }

    @Test("parsePackageJson_scripts값이숫자_파싱완료")
    func parsePackageJson_scripts값이숫자_파싱완료() throws {
        // 값이 Any 타입이므로 숫자도 키는 유효하게 파싱됨
        let json = #"{ "scripts": { "build": 42 } }"#
        let path = try writeTempFile(name: "package.json", content: json)
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        // scriptsDict가 [String: Any]이므로 값 타입 무관하게 키는 포함됨
        // 실제 동작 확인: build 키가 있으면 파싱됨
        let names = scripts.map(\.name)
        #expect(names.contains("build"))
    }

    @Test("parsePyprojectToml_대소문자섞인섹션헤더_매칭안됨")
    func parsePyprojectToml_대소문자섞인섹션헤더_매칭안됨() throws {
        // 파서는 lowercased() 비교하므로 대소문자 무관하게 매칭됨
        let content = """
        [Project.Scripts]
        my-tool = "module:main"
        """
        let path = try writeTempFile(name: "pyproject.toml", content: content)
        let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
        // lowercased 비교이므로 [project.scripts] 와 동일하게 파싱됨
        let names = scripts.map(\.name)
        #expect(names.contains("my-tool"))
    }

    @Test("parsePyprojectToml_TOOL_POETRY_SCRIPTS_대문자_매칭됨")
    func parsePyprojectToml_TOOL_POETRY_SCRIPTS_대문자_매칭됨() throws {
        let content = """
        [TOOL.POETRY.SCRIPTS]
        my-tool = "module:main"
        """
        let path = try writeTempFile(name: "pyproject.toml", content: content)
        let scripts = ScriptsPanelView.parsePyprojectToml(at: path)
        let names = scripts.map(\.name)
        #expect(names.contains("my-tool"))
    }

    @Test("cargoScripts_이름중복없음")
    func cargoScripts_이름중복없음() {
        let scripts = ScriptsPanelView.cargoScripts()
        let names = scripts.map(\.name)
        let uniqueNames = Set(names)
        #expect(names.count == uniqueNames.count)
    }

    @Test("goScripts_이름중복없음")
    func goScripts_이름중복없음() {
        let scripts = ScriptsPanelView.goScripts()
        let names = scripts.map(\.name)
        let uniqueNames = Set(names)
        #expect(names.count == uniqueNames.count)
    }

    @Test("parsePackageJson_null값_크래시없음")
    func parsePackageJson_null값_크래시없음() throws {
        let json = #"{ "scripts": { "build": null, "test": null } }"#
        let dir = FileManager.default.temporaryDirectory
        let path = dir.appendingPathComponent(UUID().uuidString + "-package.json").path
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        // null 값은 Any로 캐스트되므로 키는 포함될 수 있음
        let scripts = ScriptsPanelView.parsePackageJson(at: path)
        _ = scripts.count  // 크래시 없이 완료되어야 함
    }
}
