import Charts
import SwiftUI

// MARK: - Dashboard container

struct UsageDashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 7) {
            RangeSegmented(selection: $model.selectedRange, statsForCaption: stats)

            if let stats = stats {
                KpiRow(stats: stats)
                UsageTrendCard(stats: stats)
                HStack(alignment: .top, spacing: 8) {
                    ModelsCard(stats: stats)
                    ToolsCard(stats: stats)
                    MiscCard(stats: stats)
                }
            } else {
                loadingCard
            }
        }
        .onAppear {
            model.fetchUsageStatsIfNeeded(force: false)
        }
    }

    private var stats: RangeUsageStats? {
        model.usageStats[model.selectedRange]
    }

    @ViewBuilder
    private var loadingCard: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small).tint(.cyan)
            Text("加载统计数据…")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .dashboardCard()
    }
}

// MARK: - Range segmented control

struct RangeSegmented: View {
    @Binding var selection: UsageRange
    var statsForCaption: RangeUsageStats?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(UsageRange.allCases) { range in
                let selected = selection == range
                Text(range.label)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .white : Theme.textSecondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 3)
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

            if let stats = statsForCaption {
                Text("更新于 \(stats.fetchedAt.formatted(.dateTime.hour().minute().second()))")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
            }
        }
        .padding(2.5)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }
}

// MARK: - KPI row (5 compact chips)

struct KpiRow: View {
    let stats: RangeUsageStats

    private var summary: UsageSummary? { stats.modelPayload?.summary ?? stats.mcpPayload?.summary }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                KpiChip(
                    title: "缓存命中率",
                    value: summary?.cacheHitRate?.fractionValue.map(QuotaFormat.rateText) ?? "--",
                    trend: QuotaFormat.trend(summary?.cacheHitRate?.fractionTrend),
                    invertTrendColor: true
                )
                KpiChip(
                    title: "错峰使用率",
                    value: summary?.offPeakUsageRate?.fractionValue.map(QuotaFormat.rateText) ?? "--",
                    trend: QuotaFormat.trend(summary?.offPeakUsageRate?.fractionTrend),
                    invertTrendColor: true
                )
            }
            HStack(spacing: 6) {
                KpiChip(
                    title: "Token 总量",
                    value: QuotaFormat.bigCount(stats.modelPayload?.modelUsage?.totalUsage?.totalTokens)
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
}

struct KpiChip: View {
    let title: String
    let value: String
    var trend: (text: String, up: Bool)? = nil
    /// Rates like cache hit: down = bad → orange.
    var invertTrendColor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                if let trend {
                    HStack(spacing: 1) {
                        Image(systemName: trend.up ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 7, weight: .black))
                        Text(trend.text)
                            .font(.system(size: 8, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle((trend.up != invertTrendColor) ? Color.orange : Color.green)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("积分消耗趋势")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(stats.range.label)
                    .font(.system(size: 8, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.white.opacity(0.07)))
                    .foregroundStyle(Theme.textSecondary)
            }

            if points.isEmpty {
                Text("暂无消耗数据")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                Chart(points, id: \.date) { point in
                    AreaMark(
                        x: .value("时间", point.date),
                        y: .value("积分", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.32), Color.cyan.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("时间", point.date),
                        y: .value("积分", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.cyan)
                    .shadow(color: Color.cyan.opacity(0.5), radius: 2.5)
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(QuotaFormat.bigCount(number))
                                    .font(.system(size: 7.5))
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
                                Text(date, format: .dateTime.day().month().hour().minute())
                                    .font(.system(size: 7.5))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 64)
            }
        }
        .dashboardCard()
    }

}

// MARK: - Models card

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
        VStack(alignment: .leading, spacing: 8) {
            Text("模型排行")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            if models.isEmpty {
                Text("暂无数据")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            } else {
                ForEach(models) { model in
                    ModelUsageRow(model: model, share: totalCredits > 0 ? (model.totalCredits ?? 0) / totalCredits : 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard()
    }
}

struct ModelUsageRow: View {
    let model: UsageModelData
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text("\(QuotaFormat.bigCount(model.totalTokens)) tokens")
                    .font(.system(size: 9, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(Theme.accentGradient)
                            .frame(width: max(3, geo.size.width * share))
                    }
                }
                .frame(height: 4)

                Text("积分 \(QuotaFormat.credits(model.totalCredits))")
                    .font(.system(size: 9, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize()
            }
        }
    }
}

// MARK: - MCP tools card

struct ToolsCard: View {
    let stats: RangeUsageStats

    private var mcpUsage: UsageSeries? { stats.mcpPayload?.mcpUsage }
    private var tools: [UsageToolSummary] {
        (mcpUsage?.toolSummaryList ?? []).sorted { ($0.calls ?? 0) > ($1.calls ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MCP 工具")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(QuotaFormat.used(mcpUsage?.totalUsage?.totalMcpCalls)) 次")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text("调用 \(QuotaFormat.credits(mcpUsage?.totalUsage?.totalCredits)) 积分")
                    .font(.system(size: 9, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }

            if !tools.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(tools.prefix(2)) { tool in
                        HStack {
                            Circle().fill(Color.white.opacity(0.25)).frame(width: 3, height: 3)
                            Text(tool.displayName)
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text("\(QuotaFormat.used(tool.calls)) 次")
                                .font(.system(size: 9))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard()
    }
}

// MARK: - Misc card

struct MiscCard: View {
    let stats: RangeUsageStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("其他指标")
                .font(.system(size: 11, weight: .semibold))
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard()
    }

    private func miscRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(Theme.accentGradient)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
    }
}

// MARK: - Card style

extension View {
    func dashboardCard() -> some View {
        self
            .padding(9)
            .background(Theme.cardShape(radius: 14).fill(Theme.cardFill))
            .overlay(Theme.cardShape(radius: 14).strokeBorder(Theme.cardBorder))
    }
}
