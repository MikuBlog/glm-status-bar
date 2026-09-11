import XCTest
@testable import GLMStatusBar

final class UsageDetailTests: XCTestCase {
    /// Real MODEL payload (captured 2026-09-11, trimmed arrays).
    private let modelFixture = """
    {"code":200,"msg":"操作成功","success":true,
     "data":{"granularity":"HOUR","timezone":"Asia/Shanghai",
      "summary":{
        "cacheHitRate":{"value":"0.8307","trend":"-0.1122"},
        "offPeakUsageRate":{"value":"0.7815","trend":"1.7051"},
        "totalCredits":{"value":"2232.5331","trend":"-0.7696"},
        "averageDailyCredits":{"value":"2232.5331","trend":"-0.7696"}},
      "modelUsage":{
        "xTime":["2026-09-11 10:00:00","2026-09-11 11:00:00"],
        "totalUsage":{"totalTokens":41658694,"totalCredits":"2017.7331"},
        "modelDataList":[
          {"modelCode":"glm-5.3","modelName":"GLM-5.3",
           "totalTokensUsage":[100,200.5,null],"totalCreditsUsage":["1200","500.5",null]},
          {"modelCode":"glm-5.3-flash","modelName":"GLM-5.3-Flash",
           "totalTokensUsage":[10,20],"totalCreditsUsage":["80","40"]}]}}}
    """

    /// Real MCP payload (captured 2026-09-11).
    private let mcpFixture = """
    {"code":200,"msg":"操作成功","success":true,
     "data":{"granularity":"HOUR","timezone":"Asia/Shanghai",
      "summary":{"cacheHitRate":{"value":"0.8307"}},
      "mcpUsage":{
        "xTime":["2026-09-11 10:00:00"],
        "totalUsage":{"totalMcpCalls":163,"totalCredits":"214.8000"},
        "toolSummaryList":[
          {"mcpCode":"search-prime","mcpName":"搜索","totalMcpCalls":120,"totalCredits":"150.2"},
          {"toolCode":"web-reader","toolName":"网页阅读","totalUsageCount":23}]}}}
    """

    func testDecodeModelFixture() throws {
        let body = try JSONDecoder().decode(UsageDetailResponse.self, from: Data(modelFixture.utf8))
        XCTAssertTrue(body.success)
        let payload = try XCTUnwrap(body.data)
        XCTAssertEqual(payload.granularity, "HOUR")

        let summary = try XCTUnwrap(payload.summary)
        XCTAssertEqual(summary.cacheHitRate?.fractionValue ?? 0, 0.8307, accuracy: 0.0001)
        XCTAssertEqual(summary.cacheHitRate?.fractionTrend ?? 0, -0.1122, accuracy: 0.0001)
        XCTAssertEqual(summary.offPeakUsageRate?.fractionValue ?? 0, 0.7815, accuracy: 0.0001)
        XCTAssertEqual(summary.totalCredits?.rawValue ?? 0, 2232.5331, accuracy: 0.001)

        let modelUsage = try XCTUnwrap(payload.modelUsage)
        XCTAssertEqual(modelUsage.totalUsage?.totalTokens ?? 0, 41658694, accuracy: 0.001)
        XCTAssertEqual(modelUsage.totalUsage?.totalCredits ?? 0, 2017.7331, accuracy: 0.001)

        // Series sums, tolerating null entries inside the arrays.
        let glm = try XCTUnwrap(modelUsage.modelDataList?.first)
        XCTAssertEqual(glm.totalTokens ?? 0, 300.5, accuracy: 0.001)
        XCTAssertEqual(glm.totalCredits ?? 0, 1700.5, accuracy: 0.001)

        // Chart aggregation across models.
        XCTAssertEqual(modelUsage.creditsSeries, [1280.0, 540.5])
        XCTAssertEqual(modelUsage.xDates.count, 2)
    }

    func testDecodeMcpFixture() throws {
        let body = try JSONDecoder().decode(UsageDetailResponse.self, from: Data(mcpFixture.utf8))
        let mcpUsage = try XCTUnwrap(body.data?.mcpUsage)
        XCTAssertEqual(mcpUsage.totalUsage?.totalMcpCalls ?? 0, 163, accuracy: 0.001)
        XCTAssertEqual(mcpUsage.totalUsage?.totalCredits ?? 0, 214.8, accuracy: 0.001)
        let tools = try XCTUnwrap(mcpUsage.toolSummaryList)
        XCTAssertEqual(tools[0].displayName, "搜索")
        XCTAssertEqual(tools[0].calls ?? 0, 120, accuracy: 0.001)
        XCTAssertEqual(tools[1].displayName, "网页阅读")
        XCTAssertEqual(tools[1].calls ?? 0, 23, accuracy: 0.001)
    }

    func testRangeStartAndEnd() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let now = cal.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 13))!

        let today = UsageRange.today.startAndEnd(now: now, calendar: cal)
        XCTAssertEqual(cal.dateComponents([.hour, .minute], from: today.start).hour, 0)
        XCTAssertEqual(cal.dateComponents([.day], from: today.start, to: today.end).day, 0)

        let week = UsageRange.week.startAndEnd(now: now, calendar: cal)
        XCTAssertEqual(cal.dateComponents([.day], from: week.start, to: week.end).day, 6)

        let month = UsageRange.month.startAndEnd(now: now, calendar: cal)
        XCTAssertEqual(cal.dateComponents([.day], from: month.start, to: month.end).day, 29)
    }

    func testFlexibleNumbers() throws {
        // totalTokens as string, totalMcpCalls as number, totalCredits missing.
        let json = #"{"totalTokens":"12345","totalMcpCalls":7}"#
        let total = try JSONDecoder().decode(UsageTotalUsage.self, from: Data(json.utf8))
        XCTAssertEqual(total.totalTokens ?? 0, 12345, accuracy: 0.001)
        XCTAssertNil(total.totalCredits)
        XCTAssertEqual(total.totalMcpCalls ?? 0, 7, accuracy: 0.001)
    }

    func testTrendFormatting() {
        XCTAssertEqual(QuotaFormat.trend(-0.1247)?.text, "-12.5%")
        XCTAssertFalse(QuotaFormat.trend(-0.1247)!.up)
        XCTAssertEqual(QuotaFormat.trend(1.7051)?.text, "+170.5%")
        XCTAssertTrue(QuotaFormat.trend(1.7051)!.up)
        XCTAssertNil(QuotaFormat.trend(nil))
        XCTAssertEqual(QuotaFormat.trend(0)?.text, "0%")
    }

    func testBigCountFormatting() {
        XCTAssertEqual(QuotaFormat.bigCount(41658694), "4,165.9万")
        XCTAssertEqual(QuotaFormat.bigCount(120000000), "1.2亿")
        XCTAssertEqual(QuotaFormat.bigCount(5000), "5,000")
        XCTAssertEqual(QuotaFormat.bigCount(nil), "--")
    }

    func testCreditsFormatting() {
        XCTAssertEqual(QuotaFormat.credits(2232.5331), "2,232.53")
        XCTAssertEqual(QuotaFormat.credits(11923.85), "11,923.85")
        XCTAssertEqual(QuotaFormat.credits(nil), "--")
    }
}
