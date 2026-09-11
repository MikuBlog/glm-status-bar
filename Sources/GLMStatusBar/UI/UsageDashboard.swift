import Charts
import SwiftUI

// MARK: - Dashboard container

struct UsageDashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            RangeSegmented(selection: $model.selectedRange)

            if let stats = model.usageStats[model.selectedRange] {
                KpiRow(stats: stats)
                UsageTrendCard(stats: stats)
                ModelsCard(stats: stats)
                ToolsCard(stats: stats)
                MiscStatsCard(stats: stats)
            } else {
                loadingCard
            }
        }
        .onAppear {
            model.fetchUsageStatsIfNeeded(force: false)
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small).tint(.cyan)
            Text("加载统计数据…")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .dashboardCard()
    }
}

// MARK: - Range segmented control

struct RangeSegmented: View {
    @Binding var selection: UsageRange

    var body: some View {
        HStack(spacing: 4) {
            ForEach(UsageRange.allCases) { range in
                let selected = selection == range
                Text(range.label)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .white : Theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            selected
                                ? AnyShapeStyle(Theme.accentGradient)
                                : AnyShapeStyle(Color.white.opacity(0.06))
                        )
                    )
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            selection = range
                        }
                    }
            }
            Spacer(minLength: 0)
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }
}

// MARK: - KPI row

struct KpiRow: View {
    let stats: RangeUsageStats

    private var summary: UsageSummary? { stats.modelPayload?.summary ?? stats.mcpPayload?.summary }

    var body: some View {
        HStack(spacing: 10) {
            KpiChip(
                title: "缓存命中率",
                value: summary?.cacheHitRate?.fractionValue.map(QuotaFormat.rateText) ?? "--",
                trend: QuotaFormat.trend(summary?.cacheHitRate?.fractionTrend),
                invertTrendColor: true
            )
            KpiChip(
                title: "积分总数",
                value: QuotaFormat.credits(summary?.totalCredits?.rawValue),
                trend: QuotaFormat.trend(summary?.totalCredits?.fractionTrend)
            )
            KpiChip(
                title: "日均积分",
                value: QuotaFormat.credits(summary?.averageDailyCredits?.rawValue),
                trend: QuotaFormat.trend(summary?.averageDailyCredits?.fractionTrend)
            )
        }
    }
}

struct KpiChip: View {
    let title: String
    let value: String
    let trend: (text: String, up: Bool)?
    /// For cost metrics, down = good (green). For rates like cache hit,
    /// down = bad (orange), so the semantic flips.
    var invertTrendColor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
            if let trend {
                HStack(spacing: 2) {
                    Image(systemName: trend.up ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                    Text(trend.text)
                        .font(.system(size: 9, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle((trend.up != invertTrendColor) ? Color.orange : Color.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .dashboardCard()
    }
}

// MARK: - Credits trend chart

struct UsageTrendCard: View {
    let stats: RangeUsageStats

    private var points: [(date: Date, value: Double)] {
        guard let modelUsage = stats.modelPayload?.modelUsage else { return [] }
        let dates = modelUsage.xDates
        let values = modelUsage.creditsSeries
        let count = min(dates.count, values.count)
        return (0..<count).map { (dates[$0], values[$0]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("积分消耗趋势")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(stats.range.label)
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.07)))
                    .foregroundStyle(Theme.textSecondary)
            }

            if points.isEmpty {
                Text("暂无消耗数据")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
            } else {
                Chart(points, id: \.date) { point in
                    AreaMark(
                        x: .value("时间", point.date),
                        y: .value("积分", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.35), Color.cyan.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("时间", point.date),
                        y: .value("积分", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.cyan)
                    .shadow(color: Color.cyan.opacity(0.5), radius: 3)
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.07))
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(QuotaFormat.bigCount(number))
                                    .font(.system(size: 8))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.hour().minute())
                                    .font(.system(size: 8))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 120)
            }
        }
        .dashboardCard()
    }
}

// MARK: - Models ranking

struct ModelsCard: View {
    let stats: RangeUsageStats

    private var models: [UsageModelData] {
        (stats.modelPayload?.modelUsage?.modelDataList ?? [])
            .sorted { ($0.totalCredits ?? 0) > ($1.totalCredits ?? 0) }
    }

    private var totalCredits: Double {
        models.reduce(0) { $0 + ($1.totalCredits ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("模型用量排行")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("按积分")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textTertiary)
            }

            if models.isEmpty {
                Text("暂无数据")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(models) { model in
                    ModelUsageRow(
                        model: model,
                        share: totalCredits > 0 ? (model.totalCredits ?? 0) / totalCredits : 0
                    )
                }
            }
        }
        .dashboardCard()
    }
}

struct ModelUsageRow: View {
    let model: UsageModelData
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(QuotaFormat.bigCount(model.totalTokens)) tokens")
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(Theme.accentGradient)
                            .frame(width: max(3, geo.size.width * share))
                    }
                }
                .frame(height: 5)

                Text("积分 \(QuotaFormat.credits(model.totalCredits))")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize()
            }
        }
    }
}

// MARK: - MCP tools

struct ToolsCard: View {
    let stats: RangeUsageStats

    private var mcpUsage: UsageSeries? { stats.mcpPayload?.mcpUsage }
    private var tools: [UsageToolSummary] {
        (mcpUsage?.toolSummaryList ?? []).sorted { ($0.calls ?? 0) > ($1.calls ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MCP 工具调用")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(QuotaFormat.used(mcpUsage?.totalUsage?.totalMcpCalls)) 次")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Text("调用次数")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textTertiary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(QuotaFormat.credits(mcpUsage?.totalUsage?.totalCredits))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Text("消耗积分")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 0)
            }

            if !tools.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(tools.prefix(3)) { tool in
                        HStack {
                            Circle().fill(Color.white.opacity(0.25)).frame(width: 3, height: 3)
                            Text(tool.displayName)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text("\(QuotaFormat.used(tool.calls)) 次")
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
        }
        .dashboardCard()
    }
}

// MARK: - Misc stats

struct MiscStatsCard: View {
    let stats: RangeUsageStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("其他指标")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            miscRow(
                icon: "chart.bar.xaxis",
                title: "Token 总量",
                value: QuotaFormat.bigCount(stats.modelPayload?.modelUsage?.totalUsage?.totalTokens)
            )
            miscRow(
                icon: "moon.stars",
                title: "错峰使用率",
                value: stats.modelPayload?.summary?.offPeakUsageRate?.fractionValue.map(QuotaFormat.rateText) ?? "--"
            )
        }
        .dashboardCard()
    }

    private func miscRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Theme.accentGradient)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
    }
}

// MARK: - Card style

extension View {
    func dashboardCard() -> some View {
        self
            .padding(12)
            .background(Theme.cardShape(radius: 14).fill(Theme.cardFill))
            .overlay(Theme.cardShape(radius: 14).strokeBorder(Theme.cardBorder))
    }
}
