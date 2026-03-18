import Testing
import Foundation
@testable import Geobuk

@Suite("SessionFormatter")
struct SessionFormatterTests {

    // MARK: - 토큰 포맷팅 단위 테스트

    @Test("formatTokenCount_0_0반환")
    func formatTokenCount_zero_returnsZero() {
        #expect(SessionFormatter.formatTokenCount(0) == "0")
    }

    @Test("formatTokenCount_999_그대로반환")
    func formatTokenCount_underThousand_returnsAsIs() {
        #expect(SessionFormatter.formatTokenCount(999) == "999")
    }

    @Test("formatTokenCount_1000_1.0k")
    func formatTokenCount_thousand_returnsK() {
        #expect(SessionFormatter.formatTokenCount(1000) == "1.0k")
    }

    @Test("formatTokenCount_1234_1.2k")
    func formatTokenCount_1234_returns1point2k() {
        #expect(SessionFormatter.formatTokenCount(1234) == "1.2k")
    }

    @Test("formatTokenCount_12500_12.5k")
    func formatTokenCount_12500_returns12point5k() {
        #expect(SessionFormatter.formatTokenCount(12500) == "12.5k")
    }

    @Test("formatTokenCount_45300_45.3k")
    func formatTokenCount_45300_returns45point3k() {
        #expect(SessionFormatter.formatTokenCount(45300) == "45.3k")
    }

    @Test("formatTokenCount_100000_100.0k")
    func formatTokenCount_100000_returns100k() {
        #expect(SessionFormatter.formatTokenCount(100000) == "100.0k")
    }

    @Test("formatTokenCount_1000000_1.0M")
    func formatTokenCount_million_returnsM() {
        #expect(SessionFormatter.formatTokenCount(1_000_000) == "1.0M")
    }

    @Test("formatTokenCount_1500000_1.5M")
    func formatTokenCount_1500000_returns1point5M() {
        #expect(SessionFormatter.formatTokenCount(1_500_000) == "1.5M")
    }

    // MARK: - 비용 포맷팅 단위 테스트

    @Test("formatCost_0_$0.00")
    func formatCost_zero_returnsDollarZero() {
        #expect(SessionFormatter.formatCost(0) == "$0.00")
    }

    @Test("formatCost_0.12345_$0.12")
    func formatCost_decimal_roundsToTwoPlaces() {
        #expect(SessionFormatter.formatCost(0.12345) == "$0.12")
    }

    @Test("formatCost_0.005_$0.01")
    func formatCost_roundsUp() {
        #expect(SessionFormatter.formatCost(0.005) == "$0.01")
    }

    @Test("formatCost_18.0_$18.00")
    func formatCost_wholeDollars() {
        #expect(SessionFormatter.formatCost(18.0) == "$18.00")
    }

    @Test("formatCost_0.001_$0.00")
    func formatCost_verySmall_showsZero() {
        #expect(SessionFormatter.formatCost(0.001) == "$0.00")
    }

    // MARK: - 경과 시간 포맷팅 단위 테스트

    @Test("formatElapsedTime_0_0s")
    func formatElapsedTime_zero_returnsZeroSeconds() {
        #expect(SessionFormatter.formatElapsedTime(0) == "0s")
    }

    @Test("formatElapsedTime_30_30s")
    func formatElapsedTime_seconds_returnsSeconds() {
        #expect(SessionFormatter.formatElapsedTime(30) == "30s")
    }

    @Test("formatElapsedTime_60_1m 0s")
    func formatElapsedTime_oneMinute_returnsMinutesAndSeconds() {
        #expect(SessionFormatter.formatElapsedTime(60) == "1m 0s")
    }

    @Test("formatElapsedTime_154_2m 34s")
    func formatElapsedTime_154seconds_returns2m34s() {
        #expect(SessionFormatter.formatElapsedTime(154) == "2m 34s")
    }

    @Test("formatElapsedTime_3600_1h 0m")
    func formatElapsedTime_oneHour_returnsHoursAndMinutes() {
        #expect(SessionFormatter.formatElapsedTime(3600) == "1h 0m")
    }

    @Test("formatElapsedTime_3661_1h 1m")
    func formatElapsedTime_hourPlusMinute_returnsHoursAndMinutes() {
        #expect(SessionFormatter.formatElapsedTime(3661) == "1h 1m")
    }

    @Test("formatElapsedTime_59.7_59s")
    func formatElapsedTime_fractionalSeconds_truncates() {
        #expect(SessionFormatter.formatElapsedTime(59.7) == "59s")
    }

    // MARK: - 네거티브 테스트

    @Test("formatTokenCount_음수_0반환")
    func formatTokenCount_negative_returnsZero() {
        #expect(SessionFormatter.formatTokenCount(-1) == "0")
    }

    @Test("formatCost_음수_$0.00반환")
    func formatCost_negative_returnsZero() {
        #expect(SessionFormatter.formatCost(-1.0) == "$0.00")
    }

    @Test("formatElapsedTime_음수_0s반환")
    func formatElapsedTime_negative_returnsZero() {
        #expect(SessionFormatter.formatElapsedTime(-10) == "0s")
    }

    // MARK: - 퍼징 테스트

    @Test("formatTokenCount_랜덤값_크래시없음")
    func formatTokenCount_randomValues_doesNotCrash() {
        for _ in 0..<100 {
            let value = Int.random(in: -1000...10_000_000)
            _ = SessionFormatter.formatTokenCount(value)
        }
    }

    @Test("formatCost_랜덤값_크래시없음")
    func formatCost_randomValues_doesNotCrash() {
        for _ in 0..<100 {
            let value = Double.random(in: -100...10000)
            _ = SessionFormatter.formatCost(value)
        }
    }

    @Test("formatElapsedTime_랜덤값_크래시없음")
    func formatElapsedTime_randomValues_doesNotCrash() {
        for _ in 0..<100 {
            let value = TimeInterval.random(in: -100...100000)
            _ = SessionFormatter.formatElapsedTime(value)
        }
    }
}
