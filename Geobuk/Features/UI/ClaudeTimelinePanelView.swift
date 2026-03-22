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

// MARK: - Panel Tab

private enum ClaudePanelTab: String, CaseIterable {
    case timeline = "Timeline"
    case config = "Config"
}

// MARK: - Main View

/// Claude AI 에이전트 활동 타임라인 패널
/// 세션 단계 변화를 시간순으로 기록하여 우측 사이드바에 표시한다
struct ClaudeTimelinePanelView: View {
    var claudeMonitor: ClaudeSessionMonitor?
    var claudeFileWatcher: ClaudeSessionFileWatcher?
    var currentDirectory: String?

    @State private var selectedTab: ClaudePanelTab = .timeline

    // Timeline state
    @State private var entries: [TimelineEntry] = []
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var lastPhase: AISessionPhase = .idle
    @State private var lastToolName: String? = nil

    // Config state
    @State private var config: ClaudeConfigReader.ClaudeConfig?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabContent
        }
        .onAppear {
            startTimer()
            syncInitialState()
            loadConfig()
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
        .onChange(of: currentDirectory) { _, _ in
            loadConfig()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Claude")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Spacer()

            // Tab switcher
            Picker("", selection: $selectedTab) {
                ForEach(ClaudePanelTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Spacer()

            // Clear button (timeline only)
            if selectedTab == .timeline, !entries.isEmpty {
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

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .timeline:
            timelineContent
        case .config:
            configContent
        }
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        VStack(spacing: 0) {
            sessionStats
            Divider()
            timelineList
        }
    }

    @ViewBuilder
    private var sessionStats: some View {
        if let state = sessionState, state.phase != .idle {
            let phaseInfo = PhaseDisplayInfo.from(phase: state.phase)

            VStack(alignment: .leading, spacing: 4) {
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

    // MARK: - Config Content

    @ViewBuilder
    private var configContent: some View {
        if let config = config {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ConfigScopeView(title: "Project (\(PathAbbreviator.abbreviate(currentDirectory ?? "~")))", scope: config.project)
                    Divider()
                        .padding(.vertical, 4)
                    ConfigScopeView(title: "Global (~/.claude)", scope: config.global)
                }
                .padding(.vertical, 4)
            }
        } else {
            VStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Loading config…")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Config Loading

    private func loadConfig() {
        let dir = currentDirectory
        Task.detached(priority: .utility) {
            let result = ClaudeConfigReader.readConfig(projectDirectory: dir)
            await MainActor.run {
                self.config = result
            }
        }
    }

    // MARK: - Timeline Helpers

    private var sessionState: ClaudeSessionState? {
        claudeMonitor?.sessionState
    }

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

    private func eventType(for phase: AISessionPhase) -> TimelineEventType {
        switch phase {
        case .idle:            return .text
        case .sessionActive:   return .text
        case .responding:      return .text
        case .toolExecuting:   return .toolUse
        case .toolComplete:    return .toolResult
        case .waitingForInput: return .permission
        case .sessionComplete: return .result
        }
    }

    private func handlePhaseChange(_ newPhase: AISessionPhase) {
        guard newPhase != lastPhase else { return }
        defer { lastPhase = newPhase }

        let phaseInfo = PhaseDisplayInfo.from(phase: newPhase)
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
    }

    private func handleToolNameChange(_ newTool: String?) {
        guard newTool != lastToolName else { return }
        defer { lastToolName = newTool }

        guard let tool = newTool, !tool.isEmpty else { return }
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

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.formattedTime)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.6))

                    if let toolName = entry.toolName, !toolName.isEmpty {
                        Text(toolName)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }

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

// MARK: - Config Scope View

/// 글로벌 또는 프로젝트 설정 스코프를 표시하는 뷰
private struct ConfigScopeView: View {
    let title: String
    let scope: ClaudeConfigReader.ConfigScope

    @State private var claudeMdExpanded = false
    @State private var rulesExpanded = false
    @State private var skillsExpanded = false
    @State private var settingsExpanded = false
    @State private var hooksExpanded = false
    @State private var mcpExpanded = false
    @State private var pluginsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Scope header
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // CLAUDE.md
            CollapsibleSectionView(
                title: "CLAUDE.md",
                systemImage: "doc.text",
                isExpanded: $claudeMdExpanded
            ) {
                if let md = scope.claudeMd {
                    ClaudeMdContentView(content: md)
                } else {
                    emptyItem("No CLAUDE.md found")
                }
            }

            // Rules
            CollapsibleSectionView(
                title: "Rules",
                systemImage: "list.bullet.rectangle",
                isExpanded: $rulesExpanded,
                badge: scope.rules.isEmpty ? nil : "\(scope.rules.count)"
            ) {
                if scope.rules.isEmpty {
                    emptyItem("No rules defined")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(scope.rules) { rule in
                            RuleFileRow(rule: rule)
                        }
                    }
                }
            }

            // Skills
            CollapsibleSectionView(
                title: "Skills",
                systemImage: "bolt",
                isExpanded: $skillsExpanded,
                badge: scope.skills.isEmpty ? nil : "\(scope.skills.count)"
            ) {
                if scope.skills.isEmpty {
                    emptyItem("No skills defined")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(scope.skills) { skill in
                            SkillRow(skill: skill)
                        }
                    }
                }
            }

            // Settings (model, effort, permissions)
            CollapsibleSectionView(
                title: "Settings",
                systemImage: "gear",
                isExpanded: $settingsExpanded
            ) {
                if scope.model != nil || scope.effort != nil || scope.permissions != nil {
                    SettingsSummaryView(scope: scope)
                } else {
                    emptyItem("No settings.json found")
                }
            }

            // Hooks
            CollapsibleSectionView(
                title: "Hooks",
                systemImage: "arrowshape.turn.up.right",
                isExpanded: $hooksExpanded,
                badge: scope.hooks.isEmpty ? nil : "\(scope.hooks.count)"
            ) {
                if scope.hooks.isEmpty {
                    emptyItem("No hooks configured")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(scope.hooks) { hook in
                            HookRow(hook: hook)
                        }
                    }
                }
            }

            // MCP Servers
            CollapsibleSectionView(
                title: "MCP Servers",
                systemImage: "server.rack",
                isExpanded: $mcpExpanded,
                badge: scope.mcpServers.isEmpty ? nil : "\(scope.mcpServers.count)"
            ) {
                if scope.mcpServers.isEmpty {
                    emptyItem("No MCP servers configured")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(scope.mcpServers) { server in
                            MCPServerRow(server: server)
                        }
                    }
                }
            }

            // Plugins
            CollapsibleSectionView(
                title: "Plugins",
                systemImage: "puzzlepiece",
                isExpanded: $pluginsExpanded,
                badge: scope.plugins.isEmpty ? nil : "\(scope.plugins.count)"
            ) {
                if scope.plugins.isEmpty {
                    emptyItem("No plugins enabled")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(scope.plugins, id: \.self) { plugin in
                            Text(plugin)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 3)
                        }
                    }
                }
            }
        }
    }

    private func emptyItem(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.secondary.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }
}

// MARK: - CLAUDE.md Content View

private struct ClaudeMdContentView: View {
    let content: String
    @State private var showAll = false

    private static let previewLineCount = 50

    private var lines: [String] {
        content.components(separatedBy: "\n")
    }

    private var previewLines: [String] {
        Array(lines.prefix(Self.previewLineCount))
    }

    private var needsTruncation: Bool {
        lines.count > Self.previewLineCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let displayedLines = showAll ? lines : previewLines
            Text(displayedLines.joined(separator: "\n"))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary.opacity(0.85))
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            if needsTruncation {
                Button(action: { withAnimation { showAll.toggle() } }) {
                    Text(showAll ? "Show less" : "Show \(lines.count - Self.previewLineCount) more lines…")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
    }
}

// MARK: - Rule File Row

private struct RuleFileRow: View {
    let rule: ClaudeConfigReader.RuleFile
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(rule.name)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.85))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(rule.content)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.8))
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.05))
            }
        }
    }
}

// MARK: - Skill Row

private struct SkillRow: View {
    let skill: ClaudeConfigReader.SkillInfo

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(skill.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary.opacity(0.9))

                    if skill.isUserInvocable {
                        Text("invocable")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }

                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Settings Summary View

private struct SettingsSummaryView: View {
    let scope: ClaudeConfigReader.ConfigScope

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let model = scope.model {
                LabelValueRow(label: "model", value: model)
            }
            if let effort = scope.effort {
                LabelValueRow(label: "effort", value: effort)
            }
            if let perms = scope.permissions {
                if !perms.allow.isEmpty {
                    LabelValueRow(label: "allow", value: perms.allow.joined(separator: ", "))
                }
                if !perms.deny.isEmpty {
                    LabelValueRow(label: "deny", value: perms.deny.joined(separator: ", "))
                }
                if !perms.ask.isEmpty {
                    LabelValueRow(label: "ask", value: perms.ask.joined(separator: ", "))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Hook Row

private struct HookRow: View {
    let hook: ClaudeConfigReader.HookInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(hook.event)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.blue)

                if let matcher = hook.matcher, !matcher.isEmpty {
                    Text(matcher)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(hook.hookType)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            if let command = hook.command, !command.isEmpty {
                Text(command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - MCP Server Row

private struct MCPServerRow: View {
    let server: ClaudeConfigReader.MCPServerInfo

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(server.isDisabled ? Color.secondary.opacity(0.4) : Color.green.opacity(0.8))
                        .frame(width: 6, height: 6)
                        .padding(.top, 3)

                    Text(server.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(server.isDisabled ? .secondary : .primary.opacity(0.9))

                    Text(server.type)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                if let command = server.command, !command.isEmpty {
                    Text(command)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                } else if let url = server.url, !url.isEmpty {
                    Text(url)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Label Value Row

private struct LabelValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(minWidth: 50, alignment: .trailing)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary.opacity(0.85))
                .textSelection(.enabled)
            Spacer()
        }
    }
}
