import XCTest
@testable import GLMStatusBar

final class CacheHitTests: XCTestCase {
    /// Real API payload (values captured 2026-09-11).
    private let fixture = """
    {"code":200,"msg":"操作成功","success":true,
     "data":{"granularity":"HOUR","timezone":"Asia/Shanghai",
      "summary":{
        "cacheHitRate":{"value":"0.8190","trend":"-0.1247"},
        "offPeakUsageRate":{"value":"0.7618","trend":"1.6369"},
        "totalCredits":{"value":"2048.0751","trend":"-0.7887"},
        "averageDailyCredits":{"value":"2048.0751","trend":"-0.7887"}},
      "modelUsage":{"totalUsage":{"totalTokens":36246180,"totalCredits":"1835.6751"},"modelDataList":[]}}}
    """

    func testParsesCacheHitRate() {
        let rate = AppModel.parseCacheHitRate(data: Data(fixture.utf8))
        XCTAssertEqual(rate ?? 0, 0.819, accuracy: 0.0001)
    }

    func testNilOnAuthFailure() {
        let body = #"{"code":401,"msg":"令牌已过期","success":false}"#
        XCTAssertNil(AppModel.parseCacheHitRate(data: Data(body.utf8)))
    }

    func testNilOnInvalidPayload() {
        XCTAssertNil(AppModel.parseCacheHitRate(data: Data("<html>".utf8)))
        XCTAssertNil(AppModel.parseCacheHitRate(data: nil))
    }

    func testRateClamping() {
        let body = #"{"code":200,"success":true,"data":{"summary":{"cacheHitRate":{"value":"1.5"}}}}"#
        XCTAssertEqual(AppModel.parseCacheHitRate(data: Data(body.utf8)) ?? 0, 1.0, accuracy: 0.0001)
    }

    func testRateText() {
        XCTAssertEqual(QuotaFormat.rateText(0.819), "81.9%")
        XCTAssertEqual(QuotaFormat.rateText(0.9), "90.0%")
        XCTAssertEqual(QuotaFormat.rateText(0), "0.0%")
    }
}
