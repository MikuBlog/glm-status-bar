import XCTest
@testable import GLMStatusBar

final class ResetQuotaTests: XCTestCase {
    /// Real API payload (captured 2026-09-26).
    private let fixture = """
    {"code":200,"msg":"操作成功","success":true,
     "data":{"customerId":20181759839416652,"targetType":"PERSONAL",
      "organizationId":null,"projectId":null,
      "lastFiveHourResetTime":null,"lastWeekResetTime":null,
      "fiveHourResets":[{"recordId":783545,"grantType":"DIRECT",
        "expireTime":"2026-10-21 09:36:21","available":true}],
      "weekResets":[{"recordId":783544,"grantType":"DIRECT",
        "expireTime":"2026-10-21 09:36:21","available":true}]}}
    """

    func testParsesResetQuota() throws {
        let quota = try XCTUnwrap(AppModel.parseResetQuota(data: Data(fixture.utf8)))
        XCTAssertEqual(quota.fiveHourCount, 1)
        XCTAssertEqual(quota.weekCount, 1)
        XCTAssertEqual(quota.totalCount, 2)
    }

    func testOnlyAvailableCounts() throws {
        let used = """
        {"code":200,"success":true,
         "data":{"fiveHourResets":[{"recordId":1,"available":false}],
          "weekResets":[{"recordId":2,"available":true}]}}
        """
        let quota = try XCTUnwrap(AppModel.parseResetQuota(data: Data(used.utf8)))
        XCTAssertEqual(quota.fiveHourCount, 0)
        XCTAssertEqual(quota.totalCount, 1)
    }

    func testNilOnAuthFailure() {
        let body = #"{"code":401,"success":false}"#
        XCTAssertNil(AppModel.parseResetQuota(data: Data(body.utf8)))
        XCTAssertNil(AppModel.parseResetQuota(data: nil))
    }
}
