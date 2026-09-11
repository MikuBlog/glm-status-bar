import XCTest
@testable import GLMStatusBar

final class CodingToolTests: XCTestCase {
    func testMenuItemTitles() {
        XCTAssertEqual(CodingTool.menuItemTitle(name: "Codex", installed: true), "打开 Codex")
        XCTAssertEqual(
            CodingTool.menuItemTitle(name: "ZCode", installed: false),
            "前往 ZCode 官网"
        )
    }

    func testToolWebsites() {
        XCTAssertEqual(CodingTool.codex.website.absoluteString, "https://openai.com/codex/")
        XCTAssertEqual(CodingTool.zcode.website.absoluteString, "https://zcode.z.ai/")
    }

    func testBundleIdentifiers() {
        XCTAssertEqual(CodingTool.codex.bundleIdentifier, "com.openai.codex")
        XCTAssertEqual(CodingTool.zcode.bundleIdentifier, "dev.zcode.app")
        XCTAssertEqual(CodingTool.all.count, 2)
    }
}
