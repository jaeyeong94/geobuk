import Foundation

/// Git 명령 실행 유틸리티 — --no-optional-locks + GIT_TERMINAL_PROMPT=0 자동 적용
enum GitRunner {
    /// git 명령을 실행하고 stdout을 반환한다 (성공 시에만)
    static func run(args: [String], in directory: String) -> String? {
        ProcessRunner.output(
            "/usr/bin/git",
            arguments: ["--no-optional-locks"] + args,
            currentDirectory: directory,
            environment: ["GIT_TERMINAL_PROMPT": "0"]
        )
    }

    /// git 명령을 실행하고 (stdout, exitCode) 튜플을 반환한다
    static func runWithStatus(args: [String], in directory: String) -> (output: String?, exitCode: Int32) {
        ProcessRunner.run(
            "/usr/bin/git",
            arguments: ["--no-optional-locks"] + args,
            currentDirectory: directory,
            environment: ["GIT_TERMINAL_PROMPT": "0"]
        )
    }
}
