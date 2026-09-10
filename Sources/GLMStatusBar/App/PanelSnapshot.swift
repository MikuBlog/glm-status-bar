import AppKit
import SwiftUI

/// Developer-only UI snapshot mode:
/// `GLM_PANEL_SNAPSHOT=/path/out.png GLM StatusBar.app/Contents/MacOS/GLMStatusBar`
/// renders the dropdown panel with representative mock data and exits.
enum PanelSnapshot {
    @MainActor
    static func maybeRunSnapshotMode() {
        guard let path = ProcessInfo.processInfo.environment["GLM_PANEL_SNAPSHOT"], !path.isEmpty else {
            return
        }

        let mock: [QuotaLimit] = [
            QuotaLimit(
                type: "credits", unit: "fiveHours", percentage: 7,
                usage: 2140, currentValue: 28000,
                nextResetTime: ResetTimeTestsFixtures.todayAt(hour: 21, minute: 5),
                usageDetails: nil
            ),
            QuotaLimit(
                type: "credits", unit: "week", percentage: 1,
                usage: 2140, currentValue: 140000,
                nextResetTime: "2026-09-17 15:41:00",
                usageDetails: nil
            ),
        ]

        let model = AppModel()
        model.overrideForSnapshot(.ok(mock, Date()))

        let renderer = ImageRenderer(
            content: PanelView()
                .environmentObject(model)
                .frame(width: 330)
                .padding(8)
                .background(Color(nsColor: .windowBackgroundColor))
        )
        renderer.scale = 2
        if let image = renderer.nsImage {
            image.lockFocus()
            let rep = NSBitmapImageRep(data: image.tiffRepresentation ?? Data()) ?? NSBitmapImageRep()
            image.unlockFocus()
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
            }
        }
        exit(0)
    }
}

enum ResetTimeTestsFixtures {
    static func todayAt(hour: Int, minute: Int) -> String {
        let c = Calendar.current
        let now = Date()
        var comps = c.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        guard let date = c.date(from: comps) else { return "21:05" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }
}
