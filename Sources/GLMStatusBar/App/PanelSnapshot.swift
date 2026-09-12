import AppKit
import SwiftUI

/// Developer-only UI snapshot mode:
/// `GLM_PANEL_SNAPSHOT=/path/out.png GLM StatusBar.app/Contents/MacOS/GLMStatusBar`
/// renders the dropdown panel with representative mock data and exits.
enum PanelSnapshot {
    @MainActor
    static func maybeRunSnapshotMode() {
        guard let path = ProcessInfo.processInfo.environment["GLM_PANEL_SNAPSHOT"], !path.isEmpty else {
            maybeRunBadgeSnapshotMode()
            maybeRunDashboardSnapshotMode()
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

        let summary = UsageSummary(
            cacheHitRate: UsageMetric(value: "0.8307", trend: "-0.1122"),
            offPeakUsageRate: UsageMetric(value: "0.7815", trend: "1.7051"),
            totalCredits: UsageMetric(value: "2232.5331", trend: "-0.7696"),
            averageDailyCredits: UsageMetric(value: "2232.5331", trend: "-0.7696")
        )
        let modelUsage = UsageSeries(
            xTime: ["2026-09-11 10:00:00", "2026-09-11 11:00:00", "2026-09-11 12:00:00", "2026-09-11 13:00:00"],
            totalUsage: UsageTotalUsage(totalTokens: 41658694, totalCredits: 2017.7331, totalMcpCalls: nil),
            modelDataList: [
                UsageModelData(modelCode: "glm-5.3", modelName: "GLM-5.3",
                               totalTokensUsage: [30000000, 8000000, 3000000, 658694],
                               totalCreditsUsage: ["1200", "500", "250", "67.73"]),
                UsageModelData(modelCode: "glm-5.3-flash", modelName: "GLM-5.3-Flash",
                               totalTokensUsage: [80000, 60000, 40000, 20000],
                               totalCreditsUsage: ["30", "20", "10", "0.0000"]),
            ],
            toolSummaryList: nil
        )
        let mcpUsage = UsageSeries(
            xTime: nil,
            totalUsage: UsageTotalUsage(totalTokens: nil, totalCredits: 214.8, totalMcpCalls: 163),
            modelDataList: nil,
            toolSummaryList: [
                UsageToolSummary(mcpCode: "search-prime", toolCode: nil, mcpName: "搜索", toolName: nil,
                                 totalMcpCalls: 120, totalUsageCount: nil, totalCredits: 150.2),
                UsageToolSummary(mcpCode: "web-reader", toolCode: nil, mcpName: "网页阅读", toolName: nil,
                                 totalMcpCalls: 43, totalUsageCount: nil, totalCredits: 64.6),
            ]
        )
        let payload = UsageDetailPayload(
            granularity: "HOUR",
            summary: summary,
            modelUsage: modelUsage,
            mcpUsage: mcpUsage
        )
        let usageStats: [UsageRange: RangeUsageStats] = [
            .today: RangeUsageStats(range: .today, modelPayload: payload, mcpPayload: payload, fetchedAt: Date())
        ]

        let model = AppModel()
        model.overrideForSnapshot(
            .ok(mock, level: "max", Date()),
            usageStats: usageStats
        )

        // ImageRenderer cannot lay out ScrollView content — render through a
        // real NSHostingView inside a window so the full dashboard draws.
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 900
        let maxPanelHeight = min(720, screenHeight * 0.75)
        let maxContentHeight = max(360, maxPanelHeight - 96)
        let content = PanelView(maxContentHeight: maxContentHeight)
            .environmentObject(model)
            .frame(width: 520)
        let hostingView = NSHostingView(rootView: content)
hostingView.frame = NSRect(x: 0, y: 0, width: 520, height: min(766, screenHeight * 0.8))

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .black
        window.contentView = hostingView
        window.setFrameOrigin(NSPoint(x: 60, y: 60))
        window.orderFrontRegardless()

        // Pump the runloop so SwiftUI completes async layout (charts etc.).
        let deadline = Date().addingTimeInterval(1.2)
        while RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05)) && Date() < deadline {}

        // Render exactly what the user sees in the popover (content capped at
        // maxContentHeight, inner ScrollView handles overflow).
        hostingView.layoutSubtreeIfNeeded()
        if let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) {
            hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
            }
        }
        window.orderOut(nil)
        exit(0)
    }

    /// DEBUG: `GLM_DASH_SNAPSHOT=/path/out.png` renders only the dashboard.
    @MainActor
    static func maybeRunDashboardSnapshotMode() {
        guard let path = ProcessInfo.processInfo.environment["GLM_DASH_SNAPSHOT"], !path.isEmpty else {
            return
        }
        let model = AppModel()
        let payload = makeMockPayload()
        let usageStats: [UsageRange: RangeUsageStats] = [
            .today: RangeUsageStats(range: .today, modelPayload: payload, mcpPayload: payload, fetchedAt: Date())
        ]
        model.overrideForSnapshot(.ok(makeMockLimits(), level: "max", Date()), usageStats: usageStats)

        let hostingView = NSHostingView(rootView: UsageDashboardView()
            .environmentObject(model)
            .frame(width: 520))
        hostingView.frame = NSRect(x: 0, y: 0, width: 520, height: 1600)
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.setFrameOrigin(NSPoint(x: 60, y: 60))
        window.orderFrontRegardless()
        let deadline = Date().addingTimeInterval(1.2)
        while RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05)) && Date() < deadline {}
        hostingView.layoutSubtreeIfNeeded()
        if let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) {
            hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
            }
        }
        exit(0)
    }

    @MainActor
    static func makeMockLimits() -> [QuotaLimit] {
        [
            QuotaLimit(type: "CREDIT_LIMIT", unit: 3, number: 5,
                       usage: 28000, currentValue: 5894, remaining: 22106,
                       percentage: 21, nextResetTime: nil),
            QuotaLimit(type: "CREDIT_LIMIT", unit: 6, number: 1,
                       usage: 140000, currentValue: 5894, remaining: 134106,
                       percentage: 4, nextResetTime: nil),
        ]
    }

    @MainActor
    static func makeMockPayload() -> UsageDetailPayload {
        let summary = UsageSummary(
            cacheHitRate: UsageMetric(value: "0.8307", trend: "-0.1122"),
            offPeakUsageRate: UsageMetric(value: "0.7815", trend: "1.7051"),
            totalCredits: UsageMetric(value: "2232.5331", trend: "-0.7696"),
            averageDailyCredits: UsageMetric(value: "2232.5331", trend: "-0.7696")
        )
        let modelUsage = UsageSeries(
            xTime: ["2026-09-11 10:00:00", "2026-09-11 11:00:00", "2026-09-11 12:00:00"],
            totalUsage: UsageTotalUsage(totalTokens: 41658694, totalCredits: 2017.7331, totalMcpCalls: nil),
            modelDataList: [
                UsageModelData(modelCode: "glm-5.3", modelName: "GLM-5.3",
                               totalTokensUsage: [1200, 500, 317],
                               totalCreditsUsage: ["1200", "500", "317"]),
                UsageModelData(modelCode: "glm-5.3-flash", modelName: "GLM-5.3-Flash",
                               totalTokensUsage: [30, 20, 10],
                               totalCreditsUsage: ["30", "20", "10"]),
            ],
            toolSummaryList: nil
        )
        let mcpUsage = UsageSeries(
            xTime: nil,
            totalUsage: UsageTotalUsage(totalTokens: nil, totalCredits: 214.8, totalMcpCalls: 163),
            modelDataList: nil,
            toolSummaryList: [
                UsageToolSummary(mcpCode: "search-prime", toolCode: nil, mcpName: "搜索", toolName: nil,
                                 totalMcpCalls: 120, totalUsageCount: nil, totalCredits: 150.2),
            ]
        )
        return UsageDetailPayload(granularity: "HOUR", summary: summary,
                                  modelUsage: modelUsage, mcpUsage: mcpUsage)
    }

    /// `GLM_BADGE_SNAPSHOT=/path/out.png` renders the menu bar capsule in all
    /// its color states on a menu-bar-like strip, for the README.
    @MainActor
    static func maybeRunBadgeSnapshotMode() {
        guard let path = ProcessInfo.processInfo.environment["GLM_BADGE_SNAPSHOT"], !path.isEmpty else {
            return
        }

        func mockModel(fiveHour: Double, weekly: Double) -> AppModel {
            let model = AppModel()
            let limits = [
                QuotaLimit(type: "CREDIT_LIMIT", unit: 3, number: 5,
                           usage: 28000, currentValue: 28000 * fiveHour / 100,
                           remaining: 28000 * (1 - fiveHour / 100),
                           percentage: fiveHour, nextResetTime: nil),
                QuotaLimit(type: "CREDIT_LIMIT", unit: 6, number: 1,
                           usage: 140000, currentValue: 140000 * weekly / 100,
                           remaining: 140000 * (1 - weekly / 100),
                           percentage: weekly, nextResetTime: nil),
            ]
            model.overrideForSnapshot(.ok(limits, level: "max", Date()))
            return model
        }

        let normal = mockModel(fiveHour: 21, weekly: 4)
        let warning = mockModel(fiveHour: 65, weekly: 40)
        let critical = mockModel(fiveHour: 92, weekly: 85)

        let loggedOut = AppModel()
        loggedOut.overrideForSnapshot(.loggedOut)

        let error = AppModel()
        error.overrideForSnapshot(.error("网络错误", isAuthError: false))

        func badge(_ model: AppModel) -> some View {
            MenuBarBadge(model: model)
        }

        func caption(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
        }

        let content = VStack(spacing: 22) {
            HStack(spacing: 26) {
                VStack(spacing: 10) {
                    badge(normal)
                    caption("低用量 <50%")
                }
                VStack(spacing: 10) {
                    badge(warning)
                    caption("中用量 50–80%")
                }
                VStack(spacing: 10) {
                    badge(critical)
                    caption("高用量 >80%")
                }
            }
            HStack(spacing: 26) {
                VStack(spacing: 10) {
                    badge(loggedOut)
                    caption("未登录")
                }
                VStack(spacing: 10) {
                    badge(error)
                    caption("异常 / 凭证过期")
                }
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 22)
        .background(Color.black)

        let renderer = ImageRenderer(content: content)
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
