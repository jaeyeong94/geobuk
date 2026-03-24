import Foundation

/// 셸 Tab 키 전송 후 출력을 파싱하여 완성 후보를 추출한다.
enum TabCompletionParser {

    // MARK: - ANSI Escape 제거

    /// ANSI escape sequence를 제거한다 (CSI, OSC, 벨 등).
    static func stripAnsi(_ text: String) -> String {
        // CSI sequences: ESC [ ... (letter)
        // OSC sequences: ESC ] ... (BEL or ST)
        // Single-char escapes: ESC (letter)
        // Bell: 0x07
        var result = text
        // CSI: \e[...m, \e[...K, \e[...A 등
        result = result.replacingOccurrences(
            of: "\\e\\[[0-9;]*[A-Za-z]",
            with: "",
            options: .regularExpression
        )
        // ESC [ (alternate form with actual escape char)
        result = result.replacingOccurrences(
            of: "\u{1B}\\[[0-9;]*[A-Za-z]",
            with: "",
            options: .regularExpression
        )
        // OSC: ESC ] ... BEL or ESC ] ... ESC\\
        result = result.replacingOccurrences(
            of: "\u{1B}\\][^\u{07}\u{1B}]*[\u{07}]",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\u{1B}\\][^\u{1B}]*\u{1B}\\\\",
            with: "",
            options: .regularExpression
        )
        // Single-char escape: ESC + letter
        result = result.replacingOccurrences(
            of: "\u{1B}[A-Za-z]",
            with: "",
            options: .regularExpression
        )
        // Bell character
        result = result.replacingOccurrences(of: "\u{07}", with: "")
        return result
    }

    // MARK: - zsh 파싱

    /// zsh Tab 출력을 파싱하여 완성 후보를 반환한다.
    static func parseZsh(input: String, output: String) -> [String] {
        guard !input.isEmpty, !output.isEmpty else { return [] }

        let cleaned = stripAnsi(output).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        // 입력과 동일하면 완성 없음
        if cleaned == input { return [] }

        // 단일 완성: 출력이 입력으로 시작하고 더 긴 경우
        if cleaned.hasPrefix(input) && cleaned.count > input.count {
            let completed = cleaned.trimmingCharacters(in: .whitespaces)
            return [completed]
        }

        // 다중 완성: 여러 줄 또는 공백/탭으로 구분된 후보
        return parseCandidates(cleaned)
    }

    // MARK: - bash 파싱

    /// bash Tab 출력을 파싱하여 완성 후보를 반환한다.
    static func parseBash(input: String, output: String) -> [String] {
        guard !input.isEmpty, !output.isEmpty else { return [] }

        let cleaned = stripAnsi(output).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        if cleaned == input { return [] }

        // 단일 완성
        if cleaned.hasPrefix(input) && cleaned.count > input.count {
            let completed = cleaned.trimmingCharacters(in: .whitespaces)
            return [completed]
        }

        // 다중 완성
        return parseCandidates(cleaned)
    }

    // MARK: - 공통 파싱

    /// 공백/탭/줄바꿈으로 구분된 후보를 추출한다.
    private static func parseCandidates(_ text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var candidates: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // zsh describe 형식: "candidate -- description"
            // 각 토큰을 공백/탭으로 분리
            let tokens = trimmed.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            for token in tokens {
                // "--" 구분자 이후는 설명이므로 스킵
                if token == "--" { break }
                let candidate = token.trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty && candidate != "--" {
                    candidates.append(candidate)
                }
            }
        }

        // 중복 제거 (순서 유지)
        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }
}
