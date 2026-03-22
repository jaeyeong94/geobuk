import SwiftUI

/// 시스템 모니터/프로세스 뷰에서 사용하는 공용 색상 헬퍼
enum ColorHelpers {
    /// CPU 사용률 색상 (0~100%)
    static func cpuColor(_ percent: Double) -> Color {
        if percent >= 50 { return .red }
        if percent >= 20 { return .orange }
        return .green
    }

    /// 메모리 사용량 색상 (MB 단위)
    static func memoryColor(_ mb: UInt64) -> Color {
        if mb >= 512 { return .red }
        if mb >= 256 { return .orange }
        return .primary
    }

    /// CPU 코어 사용률 히트맵 색상 (0.0~1.0 → 초록~빨강)
    static func coreColor(usage: Double) -> Color {
        let clamped = min(max(usage, 0), 1)
        let red = min(clamped * 2, 1.0)
        let green = min((1 - clamped) * 2, 1.0)
        return Color(red: red, green: green, blue: 0).opacity(max(clamped, 0.15))
    }

    /// 디스크 사용 비율 색상 (0.0~1.0)
    static func diskColor(ratio: Double) -> Color {
        if ratio > 0.85 { return .red }
        if ratio > 0.6 { return .yellow }
        return .green
    }

    /// Swap 사용 색상
    static func swapColor(used: UInt64, total: UInt64) -> Color {
        guard total > 0 else { return .gray }
        let ratio = Double(used) / Double(total)
        if ratio > 0.7 { return .red }
        if ratio > 0.3 { return .orange }
        return .yellow
    }
}
