import SwiftUI

/// 터미널 외관 설정 뷰 (슬라이더 방식)
struct TerminalSettingsView: View {
    @Binding var fontSize: Double
    @Binding var paddingX: Double
    @Binding var paddingY: Double
    @Binding var lineHeight: Double

    var onChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Terminal Settings")
                .font(.headline)

            settingRow(
                label: "Font Size",
                value: $fontSize,
                range: 8...32,
                step: 1,
                format: "%.0f pt"
            )

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

            settingRow(
                label: "Line Height",
                value: $lineHeight,
                range: 0.8...2.0,
                step: 0.05,
                format: "%.2f"
            )
        }
        .padding(20)
        .frame(width: 320)
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
                onChanged()
            }
        }
    }
}
