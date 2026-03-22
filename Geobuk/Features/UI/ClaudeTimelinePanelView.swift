import SwiftUI

// MARK: - Timeline Model

/// 타임라인 이벤트 타입
enum TimelineEventType {
    case text
    case toolUse
    case toolResult
    case permission
    case result
    case error
}

/// 타임라인 항목
struct TimelineEntry: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    let eventType: TimelineEventType
    let toolName: String?
    let description: String

    /// 이벤트 타입에 대응하는 아이콘
    var icon: String {
        switch eventType {
        case .text:       return "💬"
        case .toolUse:    return "🔧"
        case .toolResult: return "✅"
        case .permission: return "⚠️"
        case .result:     return "🏁"
        case .error:      return "❌"
        }
    }

    /// 타임스탬프를 HH:mm:ss 형식으로 반환한다
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Main View

/// Claude AI 에이전트 활동 타임라인 패널
/// 세션 단계 변화를 시간순으로 기록하여 우측 사이드바에 표시한다
struct ClaudeTimelinePanelView: View {
    var claudeMonitor: ClaudeSessionMonitor?
    var claudeFileWatcher: ClaudeSessionFileWatcher?

    @State private var entries: [TimelineEntry] = []
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    /// 이전 phase (변화 감지용)
    @State private var lastPhase: AISessionPhase = .idle
    /// 이전 toolName (변화 감지용)
    @State private var lastToolName: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            sessionStats
            Divider()
            timelineList
        }
        .onAppear {
            startTimer()
            syncInitialState()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: sessionState?.phase) { _, newPhase in
            guard let phase = newPhase else { return }
            handlePhaseChange(phase)
        }
        .onChange(of: sessionState?.currentToolName) { _, newTool in
            handleToolNameChange(newTool)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("Claude Timeline")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Spacer()
            if !entries.isEmpty {
                Button(action: { entries.removeAll() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear Timeline")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var sessionStats: some View {
        if let state = sessionState, state.phase != .idle {
            let phaseInfo = PhaseDisplayInfo.from(phase: state.phase)

            VStack(alignment: .leading, spacing: 4) {
                // Phase
                HStack(spacing: 5) {
                    Image(systemName: phaseInfo.systemImage)
                        .foregroundColor(phaseInfo.color)
                        .font(.system(size: 10))
                    Text(phaseInfo.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(phaseInfo.color)
                    Spacer()
                    Text(SessionFormatter.formatElapsedTime(elapsedTime))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // Tokens & Cost
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 10))
                        Text(SessionFormatter.formatTokenCount(state.tokenUsage.inputTokens))
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundColor(.secondary)

                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 10))
                        Text(SessionFormatter.formatTokenCount(state.tokenUsage.outputTokens))
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundColor(.secondary)

                    Spacer()

                    Text(SessionFormatter.formatCost(state.costUSD))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // Active sessions from file watcher
                if let watcher = claudeFileWatcher, !watcher.activeSessions.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(watcher.activeSessions.count) active session\(watcher.activeSessions.count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        } else {
            HStack {
                Image(systemName: "circle")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("No active Claude session")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var timelineList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if entries.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            TimelineEntryRow(
                                entry: entry,
                                isLast: index == entries.count - 1
                            )
                            .id(entry.id)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: entries.count) { _, _ in
                if let last = entries.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 20))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No timeline events yet")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
            Text("Events appear when Claude is active")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    // MARK: - Helpers

    private var sessionState: ClaudeSessionState? {
        claudeMonitor?.sessionState
    }

    /// 초기 상태를 동기화한다 (뷰가 나타날 때 현재 단계에 맞는 항목 추가)
    private func syncInitialState() {
        guard let state = sessionState, state.phase != .idle else { return }
        let phaseInfo = PhaseDisplayInfo.from(phase: state.phase)
        addEntry(
            eventType: eventType(for: state.phase),
            toolName: state.currentToolName,
            description: phaseInfo.label
        )
        lastPhase = state.phase
        lastToolName = state.currentToolName
    }

    /// AISessionPhase를 TimelineEventType으로 변환한다
    private func eventType(for phase: AISessionPhase) -> TimelineEventType {
        switch phase {
        case .idle:           return .text
        case .sessionActive:  return .text
        case .responding:     return .text
        case .toolExecuting:  return .toolUse
        case .toolComplete:   return .toolResult
        case .waitingForInput: return .permission
        case .sessionComplete: return .result
        }
    }

    /// Phase 변화를 감지하여 타임라인 항목을 추가한다
    private func handlePhaseChange(_ newPhase: AISessionPhase) {
        guard newPhase != lastPhase else { return }
        defer { lastPhase = newPhase }

        let phaseInfo = PhaseDisplayInfo.from(phase: newPhase)
        let type = eventType(for: newPhase)
        let tool = sessionState?.currentToolName

        switch newPhase {
        case .idle:
            break
        case .sessionActive:
            addEntry(eventType: .text, toolName: nil, description: "Session started")
        case .responding:
            if lastPhase == .toolExecuting {
                addEntry(eventType: .toolResult, toolName: lastToolName, description: "Tool completed")
            } else {
                addEntry(eventType: .text, toolName: nil, description: "Responding")
            }
        case .toolExecuting:
            addEntry(eventType: .toolUse, toolName: tool, description: "Executing \(tool ?? "tool")")
        case .toolComplete:
            addEntry(eventType: .toolResult, toolName: tool, description: phaseInfo.label)
        case .waitingForInput:
            addEntry(eventType: .permission, toolName: tool, description: "Waiting for permission")
        case .sessionComplete:
            addEntry(eventType: .result, toolName: nil, description: "Session complete")
        }

        _ = type // suppress unused warning
    }

    /// toolName 변화를 감지하여 타임라인 항목을 추가한다
    private func handleToolNameChange(_ newTool: String?) {
        guard newTool != lastToolName else { return }
        defer { lastToolName = newTool }

        guard let tool = newTool, !tool.isEmpty else { return }
        // toolExecuting phase가 이미 항목을 추가하므로, 중복 방지
        guard lastPhase != .toolExecuting else { return }

        addEntry(eventType: .toolUse, toolName: tool, description: "Using \(tool)")
    }

    private func addEntry(eventType: TimelineEventType, toolName: String?, description: String) {
        let entry = TimelineEntry(
            timestamp: Date(),
            eventType: eventType,
            toolName: toolName,
            description: description
        )
        entries.append(entry)
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if let startedAt = sessionState?.startedAt {
                    elapsedTime = Date().timeIntervalSince(startedAt)
                } else {
                    elapsedTime = 0
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Timeline Entry Row

/// 타임라인의 단일 항목 행
private struct TimelineEntryRow: View {
    let entry: TimelineEntry
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 타임라인 선 + 아이콘
            VStack(spacing: 0) {
                Text(entry.icon)
                    .font(.system(size: 12))
                    .frame(width: 20, height: 20)

                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 20)
            .padding(.leading, 12)

            // 콘텐츠
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    // 타임스탬프
                    Text(entry.formattedTime)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.6))

                    // 도구 이름
                    if let toolName = entry.toolName, !toolName.isEmpty {
                        Text(toolName)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }

                // 설명
                Text(entry.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.bottom, isLast ? 4 : 8)

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}
