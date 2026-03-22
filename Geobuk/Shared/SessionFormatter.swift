import Foundation

/// AI 세션 관련 값의 표시 포맷을 담당하는 유틸리티
enum SessionFormatter {

    /// 토큰 수를 읽기 쉬운 형식으로 변환한다
    /// - 999 이하: 그대로 표시 (예: "123")
    /// - 1,000 ~ 999,999: k 단위 (예: "12.5k")
    /// - 1,000,000 이상: M 단위 (예: "1.5M")
    static func formatTokenCount(_ count: Int) -> String {
        guard count > 0 else { return "0" }

        if count >= 1_000_000 {
            let millions = Double(count) / 1_000_000.0
            return String(format: "%.1fM", millions)
        } else if count >= 1_000 {
            let thousands = Double(count) / 1_000.0
            return String(format: "%.1fk", thousands)
        } else {
            return "\(count)"
        }
    }

    /// 비용(USD)을 달러 형식으로 변환한다
    /// - 음수는 $0.00으로 표시
    /// - 소수점 2자리까지 표시 (예: "$0.12")
    static func formatCost(_ cost: Double) -> String {
        guard cost > 0 else { return "$0.00" }
        return String(format: "$%.2f", cost)
    }

    /// 경과 시간을 읽기 쉬운 형식으로 변환한다
    /// - 60초 미만: "30s"
    /// - 60초 이상 ~ 3600초 미만: "2m 34s"
    /// - 3600초 이상: "1h 5m"
    static func formatElapsedTime(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "0s" }

        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// bytes/sec를 읽기 쉽게 포맷 (1048576 → "1.0 MB/s")
    static func formatBytes(_ bytesPerSec: UInt64) -> String {
        if bytesPerSec >= 1_048_576 { return String(format: "%.1f MB/s", Double(bytesPerSec) / 1_048_576) }
        if bytesPerSec >= 1024 { return String(format: "%.0f KB/s", Double(bytesPerSec) / 1024) }
        return "\(bytesPerSec) B/s"
    }

    /// MB를 읽기 쉽게 포맷 (2048 → "2.0 GB")
    static func formatMB(_ mb: UInt64) -> String {
        if mb >= 1024 { return String(format: "%.1f GB", Double(mb) / 1024.0) }
        return "\(mb) MB"
    }

    /// 밀리초를 읽기 쉽게 포맷 (65432 → "1m 5s")
    static func formatDuration(_ ms: Int) -> String {
        let seconds = Double(ms) / 1000.0
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes)m \(secs)s"
    }
}
