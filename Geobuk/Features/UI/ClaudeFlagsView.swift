import SwiftUI

/// Claude Code 실행 플래그를 토글/선택하는 설정 뷰
/// TerminalSettingsView 내에 섹션으로 표시된다
struct ClaudeFlagsView: View {
    @Bindable var settings: ClaudeLaunchSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Claude Session Flags")
                .font(.system(size: 13, weight: .semibold))

            // 토글 플래그
            flagToggle("--chrome", description: "Browser integration", isOn: $settings.chrome)
            flagToggle("--dangerously-skip-permissions", description: "Skip all permissions", isOn: $settings.dangerouslySkipPermissions)
            flagToggle("--verbose", description: "Verbose output", isOn: $settings.verbose)
            flagToggle("--continue", description: "Continue last conversation", isOn: $settings.continueSession)
            flagToggle("--worktree", description: "Git worktree isolation", isOn: $settings.worktree)

            Divider()
                .padding(.vertical, 2)

            // 선택 플래그: Model
            pickerRow(label: "Model", selection: $settings.model, options: ClaudeLaunchSettings.availableModels)

            // 선택 플래그: Effort
            pickerRow(label: "Effort", selection: $settings.effort, options: ClaudeLaunchSettings.availableEfforts)

            // 선택 플래그: Permission
            pickerRow(label: "Permission", selection: $settings.permissionMode, options: ClaudeLaunchSettings.availablePermissionModes)
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private func flagToggle(_ flag: String, description: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 4) {
                Text(flag)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.primary)
                Text("(\(description))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
    }

    @ViewBuilder
    private func pickerRow(label: String, selection: Binding<String>, options: [String]) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option)
                        .font(.system(size: 10))
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
        }
    }
}
