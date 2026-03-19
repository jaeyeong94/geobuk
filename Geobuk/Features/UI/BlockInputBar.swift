import SwiftUI

/// 하단 고정 입력창 (Warp 스타일 블록 입력)
/// 각 터미널 패널 하단에 표시되어 명령어 입력을 제공한다
struct BlockInputBar: View {
    @State private var commandHistory = CommandHistory()
    @FocusState private var isInputFocused: Bool

    /// 현재 표시 중인 인라인 완성 힌트 (입력 뒤에 회색으로 표시)
    @State private var completionHint: String? = nil

    /// 완성 후보 목록 (복수 매칭 시 리스트로 표시)
    @State private var suggestions: [String] = []

    /// 리스트에서 선택된 인덱스 (-1: 선택 없음)
    @State private var selectedSuggestionIndex: Int = -1

    /// 방향키로 확정된 선택 값 (Enter 시 사용)
    @State private var confirmedSelection: String? = nil

    /// 패널이 포커스되어 있는지 (외부에서 전달)
    var paneFocused: Bool = false

    /// 포커스 트리거 (토글할 때마다 포커스 설정)
    var focusTrigger: Bool = false

    /// surfaceView에 저장되는 입력 텍스트 (워크스페이스 전환에도 유지)
    @Binding var persistentText: String

    /// 셸의 현재 작업 디렉토리
    let currentDirectory: String?

    /// 명령어 제출 콜백 (PTY로 전송)
    let onSubmit: (String) -> Void

    /// Tab 전송 콜백 (자동완성)
    let onTab: () -> Void

    /// Ctrl+C 전송 콜백 (인터럽트)
    let onInterrupt: () -> Void

    /// suggestion 리스트 최대 표시 수
    private static let maxVisibleSuggestions = 8

    /// suggestion 리스트가 보이는지 여부
    private var showSuggestionList: Bool {
        suggestions.count > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 완성 후보 리스트 (입력 위에 표시)
            if showSuggestionList {
                suggestionListView
            }

            // 컨텍스트 라인: 사용자, 축약 경로
            contextLine

            // 입력 필드
            inputLine
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .task(id: "\(paneFocused)-\(focusTrigger)") {
            // 약간의 지연 후 포커스 (뷰 계층 안정화 대기)
            try? await Task.sleep(nanoseconds: 100_000_000)
            isInputFocused = true
        }
    }

    // MARK: - Subviews

    private var suggestionListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            let maxVisible = min(suggestions.count, Self.maxVisibleSuggestions)
            ForEach(0..<maxVisible, id: \.self) { index in
                HStack(spacing: 6) {
                    // 파일/디렉토리 아이콘
                    Image(systemName: suggestionIcon(for: suggestions[index]))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 14)

                    // 완성 텍스트 (입력 부분 강조)
                    suggestionText(for: suggestions[index])

                    Spacer()

                    // 선택된 항목에 Tab 힌트
                    if index == selectedSuggestionIndex {
                        Text("Tab")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(3)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(
                    index == selectedSuggestionIndex
                        ? Color.accentColor.opacity(0.2)
                        : Color.clear
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    applySuggestion(at: index)
                }
            }

            if suggestions.count > Self.maxVisibleSuggestions {
                Text("  \(suggestions.count - Self.maxVisibleSuggestions) more…")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    /// suggestion 항목의 아이콘을 결정한다
    private func suggestionIcon(for text: String) -> String {
        // 경로가 포함된 경우 (파일/디렉토리)
        if text.contains("/") || text.contains("~") {
            return "folder"
        }
        // 히스토리 (이전에 실행한 명령어)
        if commandHistory.commands.contains(text) {
            return "clock.arrow.circlepath"
        }
        // 공통 명령어
        return "terminal"
    }

    /// suggestion 텍스트에서 입력 부분과 완성 부분을 다르게 표시한다
    @ViewBuilder
    private func suggestionText(for text: String) -> some View {
        let input = persistentText
        let (prefix, remainder) = text.hasPrefix(input)
            ? (input, String(text.dropFirst(input.count)))
            : (text, "")

        HStack(spacing: 0) {
            Text(prefix)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
            if !remainder.isEmpty {
                Text(remainder)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
            }
        }
    }

    private var contextLine: some View {
        HStack(spacing: 6) {
            Text(NSUserName())
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.green)

            Text("\u{203A}") // ›
                .foregroundColor(.secondary)

            if let dir = currentDirectory {
                Text(PathAbbreviator.abbreviate(dir))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var inputLine: some View {
        HStack(spacing: 4) {
            Text("$")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)

            ZStack(alignment: .leading) {
                // 힌트 텍스트 (회색, 입력 뒤에 표시) — 후보가 1개일 때만 인라인 힌트
                if !showSuggestionList, let hint = completionHint, !hint.isEmpty {
                    Text(persistentText + hint)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.4))
                        .allowsHitTesting(false)
                }

                // 실제 입력 필드 (앞에 표시)
                TextField("", text: Binding(
                    get: { persistentText },
                    set: { newValue in
                        persistentText = newValue
                        updateCompletions(for: newValue)
                    }
                ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .focused($isInputFocused)
                    .onSubmit { submitCommand() }
                    .onKeyPress(.tab) {
                        if showSuggestionList {
                            let idx = selectedSuggestionIndex >= 0 ? selectedSuggestionIndex : 0
                            applySuggestion(at: idx)
                            return .handled
                        }
                        if acceptCompletionHint() { return .handled }
                        handleTab()
                        return .handled
                    }
                    .onKeyPress(.rightArrow) {
                        if acceptCompletionHint() { return .handled }
                        return .ignored
                    }
                    .onKeyPress(.upArrow) {
                        if showSuggestionList {
                            navigateSuggestion(direction: -1)
                            return .handled
                        }
                        handleUpArrow()
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        if showSuggestionList {
                            navigateSuggestion(direction: 1)
                            return .handled
                        }
                        handleDownArrow()
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        if showSuggestionList {
                            dismissSuggestions()
                            return .handled
                        }
                        handleEscape()
                        return .handled
                    }
                    .onKeyPress(characters: .init(charactersIn: "c"), phases: .down) { keyPress in
                        if keyPress.modifiers.contains(.control) {
                            handleInterrupt()
                            return .handled
                        }
                        return .ignored
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func submitCommand() {
        // suggestion 리스트에서 방향키로 선택 후 Enter
        if let selected = confirmedSelection {
            confirmedSelection = nil
            persistentText = selected
            dismissSuggestions()
            commandHistory.add(selected)
            onSubmit(selected)
            persistentText = ""
            return
        }

        let command = persistentText
        guard !command.isEmpty else { return }

        dismissSuggestions()
        commandHistory.add(command)
        onSubmit(command)
        persistentText = ""
    }

    private func handleTab() {
        // 현재 입력을 PTY에 보낸 후 Tab 전송
        if !persistentText.isEmpty {
            onSubmit(persistentText)
            persistentText = ""
        }
        dismissSuggestions()
        onTab()
    }

    private func handleUpArrow() {
        dismissSuggestions()
        if let previous = commandHistory.navigateUp() {
            persistentText = previous
        }
    }

    private func handleDownArrow() {
        dismissSuggestions()
        if let next = commandHistory.navigateDown() {
            persistentText = next
        } else {
            persistentText = ""
        }
    }

    private func handleEscape() {
        dismissSuggestions()
        persistentText = ""
        commandHistory.resetNavigation()
    }

    private func handleInterrupt() {
        dismissSuggestions()
        persistentText = ""
        onInterrupt()
    }

    // MARK: - Completion & Suggestions

    /// 입력 변경 시 완성 후보 목록을 갱신한다 (1회 호출로 힌트 + 리스트 모두 처리)
    private func updateCompletions(for text: String) {
        let candidates = CompletionProvider.suggestAll(
            for: text,
            currentDirectory: currentDirectory,
            history: commandHistory
        )

        // 인라인 힌트: 첫 번째 후보에서 입력 부분을 제외한 나머지
        if let first = candidates.first, first.hasPrefix(text), first != text {
            completionHint = String(first.dropFirst(text.count))
        } else {
            completionHint = nil
        }

        // 후보가 바뀌었을 때만 인덱스 리셋 (방향키로 선택 중인 상태 유지)
        if candidates != suggestions {
            suggestions = candidates
            selectedSuggestionIndex = candidates.isEmpty ? -1 : 0
        }
    }

    /// 현재 힌트가 있으면 수락하여 입력에 적용한다
    /// - Returns: 힌트를 수락했으면 true, 힌트가 없었으면 false
    @discardableResult
    private func acceptCompletionHint() -> Bool {
        guard let hint = completionHint, !hint.isEmpty else { return false }
        persistentText = persistentText + hint
        dismissSuggestions()
        return true
    }

    /// suggestion 리스트 내에서 선택을 이동한다
    private func navigateSuggestion(direction: Int) {
        let count = min(suggestions.count, Self.maxVisibleSuggestions)
        guard count > 0 else { return }
        selectedSuggestionIndex = (selectedSuggestionIndex + direction + count) % count
        confirmedSelection = suggestions[selectedSuggestionIndex]
    }

    /// 선택된 suggestion을 입력에 적용한다
    private func applySuggestion(at index: Int) {
        guard index >= 0, index < suggestions.count else { return }
        persistentText = suggestions[index]
        dismissSuggestions()
    }

    /// suggestion 목록과 인라인 힌트를 모두 닫는다
    private func dismissSuggestions() {
        completionHint = nil
        suggestions = []
        selectedSuggestionIndex = -1
        confirmedSelection = nil
    }
}
