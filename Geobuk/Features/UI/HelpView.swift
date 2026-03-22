import SwiftUI

struct HelpView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ShortcutSection(title: "Workspaces", rows: [
                        ("Cmd+T", "New workspace"),
                        ("Cmd+Option+W", "Close workspace"),
                        ("Cmd+1 ~ Cmd+9", "Switch workspace by number"),
                    ])

                    ShortcutSection(title: "Panes", rows: [
                        ("Cmd+D", "Split horizontally (left/right)"),
                        ("Cmd+Shift+D", "Split vertically (top/bottom)"),
                        ("Cmd+W", "Close focused pane"),
                        ("Cmd+Shift+Enter", "Toggle maximize pane"),
                        ("Cmd+Option+←→↑↓", "Directional pane focus"),
                    ])

                    ShortcutSection(title: "View", rows: [
                        ("Cmd+B", "Toggle left sidebar"),
                        ("Cmd+Shift+B", "Toggle right panel"),
                        ("Cmd+,", "Terminal settings"),
                    ])

                    ShortcutSection(title: "Claude", rows: [
                        ("Cmd+Shift+C", "New Claude session"),
                    ])

                    ShortcutSection(title: "Font Size", rows: [
                        ("Cmd++", "Increase font size"),
                        ("Cmd+-", "Decrease font size"),
                        ("Cmd+0", "Reset font size"),
                    ])

                    ShortcutSection(title: "Right Panel Tabs", rows: [
                        ("Ctrl+1", "Processes"),
                        ("Ctrl+2", "System"),
                        ("Ctrl+3", "Git"),
                        ("Ctrl+4", "Scripts"),
                        ("Ctrl+5", "Docker"),
                        ("Ctrl+6", "SSH"),
                        ("Ctrl+7", "Snippets"),
                        ("Ctrl+8", "Claude Timeline & Config"),
                        ("Ctrl+9", "Environment"),
                        ("Ctrl+0", "Notifications"),
                    ])
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 540)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Section

private struct ShortcutSection: View {
    let title: String
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    ShortcutRow(key: row.0, description: row.1)
                    if index < rows.count - 1 {
                        Divider()
                            .padding(.leading, 120)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

// MARK: - Row

private struct ShortcutRow: View {
    let key: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 108, alignment: .trailing)

            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

#Preview {
    HelpView(isPresented: .constant(true))
}
