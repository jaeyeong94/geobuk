import SwiftUI

/// 워크스페이스 목록을 표시하는 사이드바 뷰
struct SidebarView: View {
    @Bindable var workspaceManager: WorkspaceManager
    var claudeMonitor: ClaudeSessionMonitor?
    var onWorkspaceSwitch: (() -> Void)?
    var onCreateWorkspace: (() -> Void)?
    var onNewClaudeSession: (() -> Void)?
    @State private var editingIndex: Int? = nil
    @State private var editingName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("Workspaces")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button(action: {
                    onCreateWorkspace?()
                }) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Workspace")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // 워크스페이스 목록
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(workspaceManager.workspaces.enumerated()), id: \.element.id) { index, workspace in
                        WorkspaceTabView(
                            workspace: workspace,
                            index: index,
                            isActive: index == workspaceManager.activeIndex,
                            isEditing: editingIndex == index,
                            editingName: $editingName,
                            onSelect: {
                                workspaceManager.switchToWorkspace(at: index)
                                onWorkspaceSwitch?()
                            },
                            onBeginRename: {
                                editingName = workspace.name
                                editingIndex = index
                            },
                            onCommitRename: {
                                workspaceManager.renameWorkspace(at: index, name: editingName)
                                editingIndex = nil
                            },
                            onCancelRename: {
                                editingIndex = nil
                            },
                            onClose: {
                                workspaceManager.closeWorkspace(at: index)
                            }
                        )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)
            }

            // Claude 세션 상태 섹션
            if let monitor = claudeMonitor {
                Divider()
                claudeSessionSection(monitor: monitor)
            }
        }
        .frame(minWidth: 160, idealWidth: 200, maxWidth: 280)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Claude Session Section

    @ViewBuilder
    private func claudeSessionSection(monitor: ClaudeSessionMonitor) -> some View {
        VStack(spacing: 0) {
            // Claude 섹션 헤더
            HStack {
                Text("Claude")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button(action: {
                    onNewClaudeSession?()
                }) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Claude Session (Cmd+Shift+C)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // 세션 상태 표시
            if monitor.sessionState.phase != .idle {
                ClaudeStatusView(sessionState: monitor.sessionState)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
            } else {
                Button(action: { onNewClaudeSession?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                            .font(.system(size: 10))
                        Text("New Session")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
        }
    }
}

// MARK: - Workspace Tab

/// 사이드바에서 개별 워크스페이스를 나타내는 탭 뷰
struct WorkspaceTabView: View {
    let workspace: Workspace
    let index: Int
    let isActive: Bool
    let isEditing: Bool
    @Binding var editingName: String
    let onSelect: () -> Void
    let onBeginRename: () -> Void
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void
    let onClose: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            // 숫자 인덱스
            Text("\(index + 1)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                if isEditing {
                    TextField("Name", text: $editingName, onCommit: onCommitRename)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .focused($isTextFieldFocused)
                        .onExitCommand(perform: onCancelRename)
                        .onAppear { isTextFieldFocused = true }
                } else {
                    Text(workspace.name)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(abbreviatedPath(workspace.cwd))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Rename") { onBeginRename() }
            Divider()
            Button("Close") { onClose() }
        }
    }

    /// 경로를 축약하여 표시 (홈 디렉토리 → ~)
    private func abbreviatedPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path == home {
            return "~"
        } else if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
