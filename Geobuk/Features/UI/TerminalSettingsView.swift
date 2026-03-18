import SwiftUI

/// 터미널 외관 설정 뷰 (슬라이더 방식)
struct TerminalSettingsView: View {
    @Binding var fontSize: Double
    @Binding var paddingX: Double
    @Binding var paddingY: Double
    @Binding var lineHeight: Double
    @Bindable var claudeSettings: ClaudeLaunchSettings

    var onFontSizeChange: (Double) -> Void
    var onConfigChanged: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terminal Settings")
                    .font(.headline)

                // 폰트 크기: binding action으로 즉시 반영
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Font Size")
                            .font(.system(size: 12))
                        Spacer()
                        Text(String(format: "%.0f pt", fontSize))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $fontSize, in: 8...32, step: 1) { editing in
                        if !editing {
                            onFontSizeChange(fontSize)
                        }
                    }
                }

                // 행간: config update로 즉시 반영
                settingRow(
                    label: "Line Height",
                    value: $lineHeight,
                    range: 0.8...2.0,
                    step: 0.05,
                    format: "%.2f"
                )

                Divider()

                // 패딩: 설정 파일 저장 (다음 surface 생성 시 적용)
                Text("Padding (applies to new panes)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                settingRow(
                    label: "Padding X",
                    value: $paddingX,
                    range: 0...40,
                    step: 2,
                    format: "%.0f px"
                )

                settingRow(
                    label: "Padding Y",
                    value: $paddingY,
                    range: 0...40,
                    step: 2,
                    format: "%.0f px"
                )

                Divider()

                // Claude Session Flags 섹션
                ClaudeFlagsView(settings: claudeSettings)

                Divider()

                Button(action: resetToDefaults) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                        Text("Reset to Defaults")
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            .padding(20)
        }
        .frame(width: 320)
        .frame(maxHeight: 600)
    }

    private func resetToDefaults() {
        fontSize = Defaults.fontSize
        paddingX = Defaults.paddingX
        paddingY = Defaults.paddingY
        lineHeight = Defaults.lineHeight
        onFontSizeChange(fontSize)
        onConfigChanged()
    }

    enum Defaults {
        static let fontSize: Double = 14
        static let paddingX: Double = 8
        static let paddingY: Double = 4
        static let lineHeight: Double = 1.0
    }

    @ViewBuilder
    private func settingRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range, step: step) { _ in
                onConfigChanged()
            }
        }
    }
}
