import XCTest
@testable import GLMStatusBar

final class QuotaFormatTests: XCTestCase {
    func testUsedFormatting() {
        XCTAssertEqual(QuotaFormat.used(2140), "2,140")
        XCTAssertEqual(QuotaFormat.used(0), "0")
        XCTAssertEqual(QuotaFormat.used(nil), "--")
    }

    func testTotalFormatting() {
        XCTAssertEqual(QuotaFormat.total(28000), "2.8万")
        XCTAssertEqual(QuotaFormat.total(140000), "14万")
        XCTAssertEqual(QuotaFormat.total(9800), "9,800")
        XCTAssertEqual(QuotaFormat.total(nil), "--")
    }

    func testUsageLevels() {
        XCTAssertEqual(QuotaFormat.level(for: 0), .normal)
        XCTAssertEqual(QuotaFormat.level(for: 49.9), .normal)
        XCTAssertEqual(QuotaFormat.level(for: 50), .warning)
        XCTAssertEqual(QuotaFormat.level(for: 79.9), .warning)
        XCTAssertEqual(QuotaFormat.level(for: 80), .critical)
        XCTAssertEqual(QuotaFormat.level(for: 100), .critical)
    }

    func testPercentText() {
        XCTAssertEqual(QuotaFormat.percentText(7.4), "7")
        XCTAssertEqual(QuotaFormat.percentText(7.5), "8")
        XCTAssertEqual(QuotaFormat.percentText(0), "0")
    }
}

final class ResetTimeTests: XCTestCase {
    private func date(_ s: TimeInterval) -> Date { Date(timeIntervalSince1970: s) }

    func testParsesEpochMilliseconds() {
        let d = ResetTime.parse("1789047900000")
        XCTAssertNotNil(d)
        XCTAssertEqual(d?.timeIntervalSince1970 ?? 0, 1_789_047_900, accuracy: 0.001)
    }

    func testParsesEpochSeconds() {
        let d = ResetTime.parse("1789047900")
        XCTAssertEqual(d?.timeIntervalSince1970 ?? 0, 1_789_047_900, accuracy: 0.001)
    }

    func testParsesISO8601() {
        XCTAssertNotNil(ResetTime.parse("2026-09-17T15:41:00+08:00"))
        XCTAssertNotNil(ResetTime.parse("2026-09-17T15:41:00.123Z"))
    }

    func testParsesPlainDateTime() {
        XCTAssertNotNil(ResetTime.parse("2026-09-17 15:41:00"))
        XCTAssertNotNil(ResetTime.parse("2026/09/17 15:41:00"))
    }

    func testParseFailures() {
        XCTAssertNil(ResetTime.parse(nil))
        XCTAssertNil(ResetTime.parse(""))
        XCTAssertNil(ResetTime.parse("not-a-date"))
    }

    func testRelativeCountdown() {
        let now = date(1_000_000)
        XCTAssertEqual(ResetTime.relative(date(1_000_030), now: now), "30秒后")
        XCTAssertEqual(ResetTime.relative(date(1_000_300), now: now), "5分钟后")
        XCTAssertEqual(ResetTime.relative(date(1_003_600), now: now), "1小时后")
        XCTAssertEqual(ResetTime.relative(date(1_011_100), now: now), "3小时5分后")
        XCTAssertEqual(ResetTime.relative(date(1_519_200), now: now), "6天后")
        XCTAssertEqual(ResetTime.relative(date(999_999), now: now), "即将重置")
    }

    func testAbsoluteSameDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let now = cal.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 16, minute: 55))!
        let reset = cal.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 21, minute: 5))!
        XCTAssertEqual(ResetTime.absolute(reset, now: now, calendar: cal), "21:05 重置")
    }

    func testAbsoluteOtherDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let now = cal.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 16, minute: 55))!
        let reset = cal.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 15, minute: 41))!
        XCTAssertEqual(ResetTime.absolute(reset, now: now, calendar: cal), "9月17日 15:41 重置")
    }
}
