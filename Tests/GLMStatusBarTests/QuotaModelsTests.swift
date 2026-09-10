import XCTest
@testable import GLMStatusBar

final class QuotaModelsTests: XCTestCase {
    /// Exact structure captured from the live API on 2026-09-10.
    private let fixture = """
    {"code":200,"msg":"操作成功","success":true,
     "data":{"level":"max","limits":[
       {"type":"CREDIT_LIMIT","unit":3,"number":5,
        "usage":28000,"currentValue":5894,"remaining":22105,
        "percentage":21,"nextResetTime":1789045559098},
       {"type":"CREDIT_LIMIT","unit":6,"number":1,
        "usage":140000,"currentValue":5894,"remaining":134105,
        "percentage":4,"nextResetTime":1789630895994}
     ]}}
    """

    func testDecodesLiveFixture() throws {
        let body = try JSONDecoder().decode(QuotaResponse.self, from: Data(fixture.utf8))
        XCTAssertEqual(body.code, 200)
        XCTAssertTrue(body.success)
        XCTAssertEqual(body.data?.level, "max")

        let limits = try XCTUnwrap(body.data?.limits)
        XCTAssertEqual(limits.count, 2)

        let fiveHour = limits[0]
        XCTAssertEqual(fiveHour.displayTitle, "5小时额度")
        XCTAssertEqual(fiveHour.totalCredits, 28000)
        XCTAssertEqual(fiveHour.usedCredits, 5894)
        XCTAssertEqual(fiveHour.remaining, 22105)
        XCTAssertEqual(fiveHour.effectivePercentage, 21, accuracy: 0.001)
        XCTAssertEqual(fiveHour.nextResetTime ?? 0, 1_789_045_559_098, accuracy: 1)

        let weekly = limits[1]
        XCTAssertEqual(weekly.displayTitle, "周额度")
        XCTAssertEqual(weekly.effectivePercentage, 4, accuracy: 0.001)
    }

    func testNextResetTimeAcceptsNumericString() throws {
        let json = #"{"type":"CREDIT_LIMIT","unit":3,"number":5,"usage":100,"currentValue":10,"percentage":10,"nextResetTime":"1789045559098"}"#
        let limit = try JSONDecoder().decode(QuotaLimit.self, from: Data(json.utf8))
        XCTAssertEqual(limit.nextResetTime ?? 0, 1_789_045_559_098, accuracy: 1)
    }

    func testDisplayTitleAndRank() {
        func limit(_ unit: Int?, _ number: Double? = nil) -> QuotaLimit {
            QuotaLimit(type: "CREDIT_LIMIT", unit: unit, number: number, usage: nil,
                       currentValue: nil, remaining: nil, percentage: nil, nextResetTime: nil)
        }
        XCTAssertEqual(limit(3, 5).displayTitle, "5小时额度")
        XCTAssertEqual(limit(6, 1).displayTitle, "周额度")
        XCTAssertEqual(limit(6, 2).displayTitle, "2周额度")
        XCTAssertEqual(limit(nil).displayTitle, "额度")

        XCTAssertEqual(limit(3, 5).rank, 0)
        XCTAssertEqual(limit(6, 1).rank, 1)
        XCTAssertEqual(limit(99).rank, 2)
    }

    func testEffectivePercentageFallbackAndClamping() {
        // percentage nil -> derive from used/total
        let derived = QuotaLimit(type: "CREDIT_LIMIT", unit: 3, number: 5, usage: 10000,
                                 currentValue: 2500, remaining: 7500, percentage: nil,
                                 nextResetTime: nil)
        XCTAssertEqual(derived.effectivePercentage, 25, accuracy: 0.001)

        let clampedHigh = QuotaLimit(type: "CREDIT_LIMIT", unit: 3, number: 5, usage: 100,
                                     currentValue: 0, remaining: 100, percentage: 120,
                                     nextResetTime: nil)
        XCTAssertEqual(clampedHigh.effectivePercentage, 100)

        let clampedLow = QuotaLimit(type: "CREDIT_LIMIT", unit: 3, number: 5, usage: 100,
                                    currentValue: 0, remaining: 100, percentage: -5,
                                    nextResetTime: nil)
        XCTAssertEqual(clampedLow.effectivePercentage, 0)
    }

    func testEpochMillisecondsParsing() {
        let date = ResetTime.parse(epochMilliseconds: 1_789_045_559_098)
        XCTAssertEqual(date.timeIntervalSince1970, 1_789_045_559.098, accuracy: 0.002)
    }
}
