import SwiftUI

/// 우측 사이드바 패널 종류
enum RightPanelTab: String, CaseIterable, Identifiable {
    case processes = "Processes"
    case system = "System"
    case git = "Git"
    case scripts = "Scripts"
    case docker = "Docker"
    case ssh = "SSH"
    case snippets = "Snippets"
    case claude = "Claude"
    case environment = "Environment"
    case notifications = "Notifications"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .processes: return "terminal"
        case .system: return "gauge.with.dots.needle.33percent"
        case .git: return "arrow.triangle.branch"
        case .scripts: return "scroll"
        case .docker: return "shippingbox"
        case .ssh: return "server.rack"
        case .snippets: return "bookmark"
        case .claude: return "brain"
        case .environment: return "list.bullet.rectangle"
        case .notifications: return "bell"
        }
    }

    var help: String {
        switch self {
        case .processes: return "Terminal Processes (Ctrl+1)"
        case .system: return "System Monitor (Ctrl+2)"
        case .git: return "Git Status (Ctrl+3)"
        case .scripts: return "Project Scripts (Ctrl+4)"
        case .docker: return "Docker (Ctrl+5)"
        case .ssh: return "SSH Hosts (Ctrl+6)"
        case .snippets: return "Snippets (Ctrl+7)"
        case .claude: return "Claude Timeline (Ctrl+8)"
        case .environment: return "Environment (Ctrl+9)"
        case .notifications: return "Notifications (Ctrl+0)"
        }
    }

    /// 탭 번호 (1-based; notifications uses 0)
    var number: Int {
        switch self {
        case .processes: return 1
        case .system: return 2
        case .git: return 3
        case .scripts: return 4
        case .docker: return 5
        case .ssh: return 6
        case .snippets: return 7
        case .claude: return 8
        case .environment: return 9
        case .notifications: return 0
        }
    }

    /// 번호로 탭 찾기
    static func fromNumber(_ n: Int) -> RightPanelTab? {
        allCases.first { $0.number == n }
    }
}

/// 우측 사이드바 — 아이콘 탭 바 + 패널 전환
struct RightSidebarView: View {
    var provider: TerminalProcessProvider
    var systemMonitor: SystemMonitor?
    var surfaceView: GhosttySurfaceView?
    var claudeMonitor: ClaudeSessionMonitor?
    var claudeFileWatcher: ClaudeSessionFileWatcher?
    var currentDirectory: String?
    var notificationCoordinator: NotificationCoordinator?
    /// 패널 포커스 전환 시 증가하여 Git 등 패널 강제 갱신
    var refreshTrigger: Int = 0
    var onClose: (() -> Void)?
    var onExecuteCommand: ((String) -> Void)?

    @State private var selectedTab: RightPanelTab = .processes

    var body: some View {
        HStack(spacing: 0) {
            // 패널 콘텐츠
            panelContent

            // 아이콘 탭 바 (우측 세로)
            iconBar
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .onReceive(NotificationCenter.default.publisher(for: .switchRightPanelTab)) { notification in
            if let number = notification.object as? Int,
               let tab = RightPanelTab.fromNumber(number) {
                if selectedTab == tab {
                    // 같은 탭 → 패널 닫기
                    onClose?()
                } else {
                    selectedTab = tab
                }
            }
        }
    }

    // MARK: - Icon Bar

    private var iconBar: some View {
        VStack(spacing: 4) {
            ForEach(RightPanelTab.allCases) { tab in
                Button(action: {
                    if selectedTab == tab {
                        onClose?()
                    } else {
                        selectedTab = tab
                    }
                }) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 22))
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                            .frame(width: 44, height: 44)
                            .background(
                                selectedTab == tab
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                            .cornerRadius(8)
                            .overlay(alignment: .topTrailing) {
                                if tab == .notifications,
                                   let unread = notificationCoordinator?.unreadCount,
                                   unread > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 2, y: -2)
                                }
                            }

                        Text(verbatim: "\(tab.number)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.4))
                            .offset(x: -3, y: -2)
                    }
                }
                .buttonStyle(.plain)
                .help(tab.help)
            }

            Spacer()

            Button(action: { onClose?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .help("Close Panel (Cmd+Shift+B)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(width: 52)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    // MARK: - Panel Content

    @ViewBuilder
    private var panelContent: some View {
        switch selectedTab {
        case .processes:
            ProcessPanelView(provider: provider, systemMonitor: systemMonitor)
        case .system:
            SystemPanelView(systemMonitor: systemMonitor)
        case .git:
            GitPanelView(currentDirectory: currentDirectory)
                .id("git-\(currentDirectory ?? "")-\(refreshTrigger)")
        case .scripts:
            ScriptsPanelView(currentDirectory: currentDirectory, onExecute: onExecuteCommand)
                .id("scripts-\(currentDirectory ?? "")-\(refreshTrigger)")
        case .docker:
            DockerPanelView()
        case .ssh:
            SSHPanelView(onConnect: onExecuteCommand)
        case .snippets:
            SnippetPanelView(onExecute: onExecuteCommand)
        case .claude:
            ClaudeTimelinePanelView(claudeMonitor: claudeMonitor, claudeFileWatcher: claudeFileWatcher, currentDirectory: currentDirectory)
        case .environment:
            EnvironmentPanelView(surfaceView: surfaceView)
        case .notifications:
            NotificationPanelView(coordinator: notificationCoordinator)
        }
    }
}
