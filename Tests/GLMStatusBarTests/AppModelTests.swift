import XCTest
@testable import GLMStatusBar

final class AppModelTests: XCTestCase {
    private func http(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: AppModel.apiURL, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    private let okBody = """
    {"code":200,"success":true,"msg":null,
     "data":{"level":"","limits":[
       {"type":"credits","unit":"fiveHours","percentage":7,"usage":2140,"currentValue":28000,"nextResetTime":"2026-09-10 21:05:00"},
       {"type":"credits","unit":"week","percentage":1,"usage":2140,"currentValue":140000,"nextResetTime":"2026-09-17 15:41:00"}
     ]}}
    """

    func testClassifySuccess() {
        let outcome = AppModel.classify(data: Data(okBody.utf8), response: http(200), error: nil)
        guard case .success(let limits) = outcome else {
            return XCTFail("expected success, got \(outcome)")
        }
        XCTAssertEqual(limits.count, 2)
    }

    func testClassifyHTTP401() {
        let outcome = AppModel.classify(data: Data("{}".utf8), response: http(401), error: nil)
        guard case .authFailure = outcome else { return XCTFail("got \(outcome)") }
    }

    func testClassifyBodyCode401() {
        let body = #"{"code":401,"msg":"令牌已过期或验证不正确","success":false}"#
        let outcome = AppModel.classify(data: Data(body.utf8), response: http(200), error: nil)
        guard case .authFailure = outcome else { return XCTFail("got \(outcome)") }
    }

    func testClassifyMissingAuthHeader() {
        let body = #"{"code":1001,"msg":"Header中未收到Authorization参数","success":false}"#
        let outcome = AppModel.classify(data: Data(body.utf8), response: http(200), error: nil)
        guard case .authFailure = outcome else { return XCTFail("got \(outcome)") }
    }

    func testClassifyNetworkError() {
        let outcome = AppModel.classify(data: nil, response: nil, error: URLError(.notConnectedToInternet))
        guard case .failure(let message) = outcome else { return XCTFail("got \(outcome)") }
        XCTAssertTrue(message.hasPrefix("网络错误"))
    }

    func testClassifyServerHTTPError() {
        let outcome = AppModel.classify(data: nil, response: http(500), error: nil)
        guard case .failure(let message) = outcome else { return XCTFail("got \(outcome)") }
        XCTAssertTrue(message.contains("500"))
    }

    func testClassifyInvalidJSON() {
        let outcome = AppModel.classify(data: Data("<html>".utf8), response: http(200), error: nil)
        guard case .failure = outcome else { return XCTFail("got \(outcome)") }
    }

    func testClassifyEmptyLimits() {
        let body = #"{"code":200,"success":true,"data":{"level":"","limits":[]}}"#
        let outcome = AppModel.classify(data: Data(body.utf8), response: http(200), error: nil)
        guard case .failure(let message) = outcome else { return XCTFail("got \(outcome)") }
        XCTAssertTrue(message.contains("暂无额度数据"))
    }

    func testClassifyBusinessError() {
        let body = #"{"code":500,"msg":"内部错误","success":false}"#
        let outcome = AppModel.classify(data: Data(body.utf8), response: http(200), error: nil)
        guard case .failure(let message) = outcome else { return XCTFail("got \(outcome)") }
        XCTAssertEqual(message, "内部错误")
    }
}

final class TokenStoreTests: XCTestCase {
    func testNormalizeRawValue() {
        XCTAssertEqual(TokenStore.normalize("  abc.def.ghi  "), "abc.def.ghi")
    }

    func testNormalizeEmpty() {
        XCTAssertNil(TokenStore.normalize(""))
        XCTAssertNil(TokenStore.normalize("   "))
    }

    func testNormalizeJSONWrappedToken() {
        XCTAssertEqual(TokenStore.normalize(#"{"token":"tok-123"}"#), "tok-123")
        XCTAssertEqual(TokenStore.normalize(#"{"access_token":"tok-456","expires":7}"#), "tok-456")
    }

    func testNormalizeJSONWithoutTokenField() {
        XCTAssertNil(TokenStore.normalize(#"{"foo":1}"#))
    }

    func testNormalizeCookiePercentEncoded() {
        XCTAssertEqual(TokenStore.normalizeCookie("tok%2B123"), "tok+123")
        XCTAssertEqual(TokenStore.normalizeCookie("plain-token"), "plain-token")
        XCTAssertEqual(TokenStore.normalizeCookie(""), nil)
    }
}
