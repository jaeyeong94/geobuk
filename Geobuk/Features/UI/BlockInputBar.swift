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

    /// 디바운스용 완성 태스크 (빠른 타이핑 시 이전 요청 취소)
    @State private var completionTask: Task<Void, Never>?

    /// Git 브랜치 이름 (nil이면 git 저장소 아님)
    @State private var gitBranch: String? = nil

    /// Git 수정/미추적 파일 수
    @State private var gitModified: Int = 0

    /// Git 스테이지된 파일 수
    @State private var gitStaged: Int = 0

    /// 패널이 포커스되어 있는지 (외부에서 전달)
    var paneFocused: Bool = false

    /// 포커스 트리거 (토글할 때마다 포커스 설정)
    var focusTrigger: Bool = false

    /// surfaceView에 저장되는 입력 텍스트 (워크스페이스 전환에도 유지)
    @Binding var persistentText: String

    /// 셸의 현재 작업 디렉토리
    let currentDirectory: String?

    /// 원격 접속 정보 (SSH 세션일 때 user@host 형태, nil이면 로컬)
    var remoteHost: String? = nil

    /// 명령어 제출 콜백 (PTY로 전송)
    let onSubmit: (String) -> Void

    /// Tab 전송 콜백 (자동완성)
    let onTab: () -> Void

    /// Tab 완성 프로바이더 (Headless PTY 기반, nil이면 기존 완성만 사용)
    var tabCompletionProvider: TabCompletionProvider?

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
            // 포커스된 패널에서만 입력창에 포커스 설정
            guard paneFocused else { return }
            // 약간의 지연 후 포커스 (뷰 계층 안정화 대기)
            try? await Task.sleep(nanoseconds: 100_000_000)
            isInputFocused = true
        }
        .onChange(of: paneFocused) { _, focused in
            if !focused {
                isInputFocused = false
            }
        }
        .onChange(of: currentDirectory) { _, _ in
            updateGitInfo()
        }
        .onAppear {
            updateGitInfo()
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
            if let remote = remoteHost {
                // 원격 세션: remote 뱃지 + user@host
                Text("remote")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(3)

                Text(remote)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.yellow)
            } else {
                // 로컬 세션: 유저명
                Text(NSUserName())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.green)
            }

            Text("\u{203A}") // ›
                .foregroundColor(.secondary)

            if let dir = currentDirectory {
                Text(remoteHost != nil ? dir : PathAbbreviator.abbreviate(dir))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }

            // Git 정보: 브랜치명, 수정 파일 수, 스테이지된 파일 수
            if let branch = gitBranch {
                Text(branch)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.purple)

                if gitModified > 0 {
                    Text(verbatim: "±\(gitModified)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.orange)
                }

                if gitStaged > 0 {
                    Text(verbatim: "+\(gitStaged)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                }
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
                        if showSuggestionList {
                            let idx = selectedSuggestionIndex >= 0 ? selectedSuggestionIndex : 0
                            applySuggestion(at: idx)
                            return .handled
                        }
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

    // MARK: - Git Info

    /// 현재 디렉토리의 git 브랜치와 상태를 백그라운드에서 갱신한다
    private func updateGitInfo() {
        let cwd = currentDirectory
        Task.detached(priority: .utility) {
            let (branch, modified, staged) = Self.fetchGitInfo(in: cwd)
            await MainActor.run {
                gitBranch = branch
                gitModified = modified
                gitStaged = staged
            }
        }
    }

    /// git 정보를 동기적으로 조회한다 (백그라운드 스레드에서 호출)
    /// - Parameter directory: 조회할 디렉토리 경로 (nil이면 nil 반환)
    /// - Returns: (브랜치명, 수정파일수, 스테이지파일수) — git 저장소 아니면 (nil, 0, 0)
    nonisolated private static func fetchGitInfo(in directory: String?) -> (String?, Int, Int) {
        guard let directory else { return (nil, 0, 0) }

        // 브랜치명 조회
        let branchOutput = GitRunner.run(args: ["rev-parse", "--abbrev-ref", "HEAD"], in: directory)
        guard let rawBranch = branchOutput,
              !rawBranch.isEmpty,
              rawBranch != "HEAD" || true  // detached HEAD도 표시
        else {
            return (nil, 0, 0)
        }
        let branch = rawBranch == "HEAD" ? "HEAD" : rawBranch

        // porcelain 상태 조회
        let statusOutput = GitRunner.runWithStatus(args: ["status", "--porcelain"], in: directory).output ?? ""
        var modified = 0
        var staged = 0

        for line in statusOutput.components(separatedBy: "\n") {
            guard line.count >= 2 else { continue }
            let index = line[line.startIndex]   // 스테이징 영역 상태
            let worktree = line[line.index(after: line.startIndex)]  // 워킹트리 상태

            // 스테이징 영역에 변경사항이 있는 경우 (M, A, D, R, C)
            if "MADRC".contains(index) {
                staged += 1
            }
            // 워킹트리에 수정/미추적 파일이 있는 경우
            if worktree == "M" || worktree == "D" || index == "?" {
                modified += 1
            }
        }

        return (branch, modified, staged)
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

    /// 입력 변경 시 완성 후보 목록을 갱신한다 (150ms 디바운스 + Tab 완성 + 기존 완성 병합)
    private func updateCompletions(for text: String) {
        completionTask?.cancel()
        completionTask = Task {
            // 150ms 디바운스 — 빠른 타이핑 시 이전 요청 취소
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }

            let cwd = currentDirectory
            let history = commandHistory

            // Tab 완성 비동기 호출 (Headless PTY)
            let tabResults = await tabCompletionProvider?.complete(text) ?? []
            guard !Task.isCancelled else { return }

            // 기존 완성 + Tab 결과 병합 (백그라운드)
            let candidates = await Task.detached(priority: .userInitiated) {
                CompletionProvider.suggestAll(
                    for: text,
                    currentDirectory: cwd,
                    history: history,
                    tabResults: tabResults
                )
            }.value

            guard !Task.isCancelled else { return }

            // UI 업데이트 (MainActor)
            if let first = candidates.first, first.hasPrefix(text), first != text {
                completionHint = String(first.dropFirst(text.count))
            } else {
                completionHint = nil
            }

            if candidates != suggestions {
                suggestions = candidates
                selectedSuggestionIndex = candidates.isEmpty ? -1 : 0
            }
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
        completionTask?.cancel()
        completionTask = nil
        completionHint = nil
        suggestions = []
        selectedSuggestionIndex = -1
        confirmedSelection = nil
    }
}
