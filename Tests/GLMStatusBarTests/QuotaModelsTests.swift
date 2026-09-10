import XCTest
@testable import GLMStatusBar

final class QuotaModelsTests: XCTestCase {
    private let fixture = """
    {
      "code": 200,
      "success": true,
      "msg": null,
      "data": {
        "level": "",
        "limits": [
          {
            "type": "credits",
            "unit": "fiveHours",
            "percentage": 7,
            "usage": 2140,
            "currentValue": 28000,
            "nextResetTime": "2026-09-10 21:05:00",
            "usageDetails": [{"mdoelCode": "search", "name": "搜索", "usage": 3}]
          },
          {
            "type": "credits",
            "unit": "week",
            "percentage": 1,
            "usage": 2140,
            "currentValue": 140000,
            "nextResetTime": "2026-09-17T15:41:00+08:00"
          }
        ]
      }
    }
    """

    func testDecodesFixture() throws {
        let body = try JSONDecoder().decode(QuotaResponse.self, from: Data(fixture.utf8))
        XCTAssertEqual(body.code, 200)
        XCTAssertTrue(body.success)
        let limits = try XCTUnwrap(body.data?.limits)
        XCTAssertEqual(limits.count, 2)
        XCTAssertEqual(limits[0].usage, 2140)
        XCTAssertEqual(limits[0].currentValue, 28000)
        XCTAssertEqual(limits[0].nextResetTime, "2026-09-10 21:05:00")
        XCTAssertEqual(limits[1].displayTitle, "周额度")
        // The web frontend's `mdoelCode` typo must still decode.
        XCTAssertEqual(limits[0].usageDetails?.first?.modelCode, "search")
        XCTAssertEqual(limits[0].usageDetails?.first?.name, "搜索")
    }

    func testDisplayTitleMapping() {
        func limit(_ unit: String?, _ type: String? = "credits") -> QuotaLimit {
            QuotaLimit(type: type, unit: unit, percentage: nil, usage: nil,
                       currentValue: nil, nextResetTime: nil, usageDetails: nil)
        }
        XCTAssertEqual(limit("fiveHours").displayTitle, "5小时额度")
        XCTAssertEqual(limit("5-hours").displayTitle, "5小时额度")
        XCTAssertEqual(limit("week").displayTitle, "周额度")
        XCTAssertEqual(limit("weekly").displayTitle, "周额度")
        XCTAssertEqual(limit("monthly").displayTitle, "月额度")
        XCTAssertEqual(limit("mcp-pool").displayTitle, "mcp-pool")
        XCTAssertEqual(limit(nil, nil).displayTitle, "额度")
    }

    func testRankOrdering() {
        XCTAssertEqual(QuotaLimit(type: "credits", unit: "fiveHours", percentage: nil, usage: nil,
                                  currentValue: nil, nextResetTime: nil, usageDetails: nil).rank, 0)
        XCTAssertEqual(QuotaLimit(type: "credits", unit: "week", percentage: nil, usage: nil,
                                  currentValue: nil, nextResetTime: nil, usageDetails: nil).rank, 1)
        XCTAssertEqual(QuotaLimit(type: "credits", unit: "monthly", percentage: nil, usage: nil,
                                  currentValue: nil, nextResetTime: nil, usageDetails: nil).rank, 2)
    }

    func testEffectivePercentageFallback() {
        let l1 = QuotaLimit(type: "c", unit: "week", percentage: nil, usage: 5000,
                            currentValue: 10000, nextResetTime: nil, usageDetails: nil)
        XCTAssertEqual(l1.effectivePercentage, 50, accuracy: 0.001)

        let l2 = QuotaLimit(type: "c", unit: "week", percentage: 120, usage: nil,
                            currentValue: nil, nextResetTime: nil, usageDetails: nil)
        XCTAssertEqual(l2.effectivePercentage, 100)

        let l3 = QuotaLimit(type: "c", unit: "week", percentage: -3, usage: nil,
                            currentValue: nil, nextResetTime: nil, usageDetails: nil)
        XCTAssertEqual(l3.effectivePercentage, 0)
    }
}
