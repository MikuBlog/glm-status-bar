import Foundation

/// Time range selector for the usage dashboard.
enum UsageRange: String, CaseIterable, Identifiable, Equatable {
    case today
    case week
    case month

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "当日"
        case .week: return "近7天"
        case .month: return "近30天"
        }
    }

    /// Start (00:00:00) and end (23:59:59) of the covered window.
    func startAndEnd(now: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date) {
        let dayStart = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart) ?? now
        switch self {
        case .today:
            return (dayStart, end)
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: dayStart) ?? dayStart
            return (start, end)
        case .month:
            let start = calendar.date(byAdding: .day, value: -29, to: dayStart) ?? dayStart
            return (start, end)
        }
    }
}

/// GET https://bigmodel.cn/api/monitor/credit-usage/usage-detail
/// usageType=MODEL → data.modelUsage; usageType=MCP → data.mcpUsage.
/// Numeric fields arrive as JSON numbers *or* numeric strings.
struct UsageDetailResponse: Codable, Equatable {
    let code: Int
    let success: Bool
    let msg: String?
    let data: UsageDetailPayload?
}

struct UsageDetailPayload: Codable, Equatable {
    let granularity: String?
    let summary: UsageSummary?
    let modelUsage: UsageSeries?
    let mcpUsage: UsageSeries?
}

/// KPI summary — every metric is a {value, trend} pair of fraction strings.
struct UsageSummary: Codable, Equatable {
    let cacheHitRate: UsageMetric?
    let offPeakUsageRate: UsageMetric?
    let totalCredits: UsageMetric?
    let averageDailyCredits: UsageMetric?
}

struct UsageMetric: Codable, Equatable {
    let value: String?
    let trend: String?

    /// Raw numeric value — unclamped (credits/counts are NOT 0-1 rates).
    var rawValue: Double? {
        value.flatMap(Double.init)
    }

    /// Clamped to 0...1 — for rate metrics only (cacheHitRate 等).
    var fractionValue: Double? {
        rawValue.map { min(max($0, 0), 1) }
    }

    var fractionTrend: Double? {
        trend.flatMap(Double.init)
    }
}

struct UsageToolSummary: Codable, Equatable, Identifiable {
    let mcpCode: String?
    let toolCode: String?
    let mcpName: String?
    let toolName: String?
    let totalMcpCalls: Double?
    let totalUsageCount: Double?
    let totalCredits: Double?

    var id: String { mcpCode ?? toolCode ?? mcpName ?? toolName ?? UUID().uuidString }
    var displayName: String { mcpName ?? toolName ?? mcpCode ?? toolCode ?? "未知工具" }
    var calls: Double? { totalMcpCalls ?? totalUsageCount }

    private enum CodingKeys: String, CodingKey {
        case mcpCode, toolCode, mcpName, toolName
        case totalMcpCalls, totalUsageCount, totalCredits
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mcpCode = try c.decodeIfPresent(String.self, forKey: .mcpCode)
        toolCode = try c.decodeIfPresent(String.self, forKey: .toolCode)
        mcpName = try c.decodeIfPresent(String.self, forKey: .mcpName)
        toolName = try c.decodeIfPresent(String.self, forKey: .toolName)
        totalMcpCalls = Self.flexibleDouble(c, .totalMcpCalls)
        totalUsageCount = Self.flexibleDouble(c, .totalUsageCount)
        totalCredits = Self.flexibleDouble(c, .totalCredits)
    }

    init(mcpCode: String?, toolCode: String?, mcpName: String?, toolName: String?,
         totalMcpCalls: Double?, totalUsageCount: Double?, totalCredits: Double?) {
        self.mcpCode = mcpCode
        self.toolCode = toolCode
        self.mcpName = mcpName
        self.toolName = toolName
        self.totalMcpCalls = totalMcpCalls
        self.totalUsageCount = totalUsageCount
        self.totalCredits = totalCredits
    }

    private static func flexibleDouble(
        _ c: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Double? {
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Double(s) }
        return nil
    }
}

struct UsageTotalUsage: Codable, Equatable {
    let totalTokens: Double?
    let totalCredits: Double?
    let totalMcpCalls: Double?

    private enum CodingKeys: String, CodingKey {
        case totalTokens, totalCredits, totalMcpCalls
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalTokens = Self.flexibleDouble(c, .totalTokens)
        totalCredits = Self.flexibleDouble(c, .totalCredits)
        totalMcpCalls = Self.flexibleDouble(c, .totalMcpCalls)
    }

    init(totalTokens: Double?, totalCredits: Double?, totalMcpCalls: Double?) {
        self.totalTokens = totalTokens
        self.totalCredits = totalCredits
        self.totalMcpCalls = totalMcpCalls
    }

    private static func flexibleDouble(
        _ c: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Double? {
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Double(s) }
        return nil
    }
}

/// Per-range series container shared by MODEL and MCP responses.
struct UsageSeries: Codable, Equatable {
    let xTime: [String]?
    let totalUsage: UsageTotalUsage?
    let modelDataList: [UsageModelData]?
    let toolSummaryList: [UsageToolSummary]?

    /// Credits per bucket: sum of every model's `totalCreditsUsage` series.
    var creditsSeries: [Double] {
        guard let lists = modelDataList, let count = xTime?.count, count > 0 else { return [] }
        var out = [Double](repeating: 0, count: count)
        for list in lists {
            for (index, raw) in (list.totalCreditsUsage ?? []).enumerated() where index < count {
                out[index] += raw.flatMap(Double.init) ?? 0
            }
        }
        return out
    }

    /// Parsed x-axis dates (tolerates "yyyy-MM-dd HH:mm:ss" and "yyyy-MM-dd").
    var xDates: [Date] {
        guard let xTime else { return [] }
        let withTime = DateFormatter()
        withTime.locale = Locale(identifier: "en_US_POSIX")
        withTime.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateOnly = DateFormatter()
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.dateFormat = "yyyy-MM-dd"
        return xTime.map { withTime.date(from: $0) ?? dateOnly.date(from: $0) ?? .distantPast }
    }
}

struct UsageModelData: Codable, Equatable, Identifiable {
    let modelCode: String?
    let modelName: String?
    let totalTokensUsage: [Double?]?
    let totalCreditsUsage: [String?]?

    var id: String { modelCode ?? modelName ?? "unknown" }
    var displayName: String { modelName ?? modelCode ?? "未知模型" }

    var totalTokens: Double? {
        guard let series = totalTokensUsage else { return nil }
        return series.compactMap { $0 }.reduce(0, +)
    }

    var totalCredits: Double? {
        guard let series = totalCreditsUsage else { return nil }
        return series.compactMap { $0.flatMap(Double.init) }.reduce(0, +)
    }
}



/// Cached dashboard payload for one range, refreshed on its own cadence.
struct RangeUsageStats: Equatable {
    let range: UsageRange
    let modelPayload: UsageDetailPayload?
    let mcpPayload: UsageDetailPayload?
    let fetchedAt: Date
}
