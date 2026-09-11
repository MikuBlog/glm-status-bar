import AppKit
import Foundation

/// A coding assistant the menu can launch, falling back to its official
/// website when the app is not installed on this Mac.
struct CodingTool {
    let name: String
    let bundleIdentifier: String
    let website: URL

    static let codex = CodingTool(
        name: "Codex",
        bundleIdentifier: "com.openai.codex",
        website: URL(string: "https://openai.com/codex/")!
    )
    static let zcode = CodingTool(
        name: "ZCode",
        bundleIdentifier: "dev.zcode.app",
        website: URL(string: "https://zcode.z.ai/")!
    )

    static let all: [CodingTool] = [.codex, .zcode]

    /// Resolves through LaunchServices, independent of the install location.
    var installedAppURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    var isInstalled: Bool { installedAppURL != nil }

    var menuItemTitle: String {
        Self.menuItemTitle(name: name, installed: isInstalled)
    }

    static func menuItemTitle(name: String, installed: Bool) -> String {
        installed ? "打开 \(name)" : "前往 \(name) 官网"
    }

    /// Launch the app if present; otherwise open the official website.
    func openOrVisitWebsite() {
        if let appURL = installedAppURL {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(website)
        }
    }
}
