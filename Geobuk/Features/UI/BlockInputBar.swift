import SwiftUI

/// 하단 고정 입력창 (Warp 스타일 블록 입력)
/// 각 터미널 패널 하단에 표시되어 명령어 입력을 제공한다
struct BlockInputBar: View {
    @State private var commandHistory = CommandHistory()
    @FocusState private var isInputFocused: Bool

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            TextField("", text: $persistentText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .focused($isInputFocused)
                .onSubmit { submitCommand() }
                .onKeyPress(.tab) {
                    handleTab()
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    handleUpArrow()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    handleDownArrow()
                    return .handled
                }
                .onKeyPress(.escape) {
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
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func submitCommand() {
        let command = persistentText
        guard !command.isEmpty else { return }

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
        onTab()
    }

    private func handleUpArrow() {
        if let previous = commandHistory.navigateUp() {
            persistentText = previous
        }
    }

    private func handleDownArrow() {
        if let next = commandHistory.navigateDown() {
            persistentText = next
        } else {
            persistentText = ""
        }
    }

    private func handleEscape() {
        persistentText = ""
        commandHistory.resetNavigation()
    }

    private func handleInterrupt() {
        persistentText = ""
        onInterrupt()
    }
}
