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
                type: "CREDIT_LIMIT", unit: 3, number: 5,
                usage: 28000, currentValue: 5894, remaining: 22105,
                percentage: 21,
                nextResetTime: ResetTimeTestsFixtures.todayEpochMs(hour: 21, minute: 5)
            ),
            QuotaLimit(
                type: "CREDIT_LIMIT", unit: 6, number: 1,
                usage: 140000, currentValue: 5894, remaining: 134105,
                percentage: 4,
                nextResetTime: 1789630895994
            ),
        ]

        let model = AppModel()
        model.overrideForSnapshot(.ok(mock, level: "max", Date()))

        let renderer = ImageRenderer(
            content: PanelView()
                .environmentObject(model)
                .frame(width: 360)
                .padding(8)
                .background(Color.black)
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
    static func todayEpochMs(hour: Int, minute: Int) -> Double {
        let c = Calendar.current
        let now = Date()
        var comps = c.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        guard let date = c.date(from: comps) else { return 1_789_045_500_000 }
        return date.timeIntervalSince1970 * 1000
    }
}
