import Foundation

/// GET https://bigmodel.cn/api/monitor/usage/quota/limit
struct QuotaResponse: Codable, Equatable {
    let code: Int
    let success: Bool
    let msg: String?
    let data: QuotaData?
}

struct QuotaData: Codable, Equatable {
    let limits: [QuotaLimit]
    let level: String?
}

struct QuotaLimit: Codable, Equatable, Identifiable {
    let type: String?
    let unit: String?
    let percentage: Double?
    let usage: Double?
    let currentValue: Double?
    let nextResetTime: String?
    let usageDetails: [UsageDetail]?

    var id: String { stableID }

    /// Stable identity that survives repeated decoding of the same server payload.
    var stableID: String {
        "\(type ?? "-")|\(unit ?? "-")|\(nextResetTime ?? "-")|\(currentValue ?? 0)"
    }

    /// Percentage of quota used, clamped to 0...100.
    /// Falls back to usage/currentValue when the API omits `percentage`.
    var effectivePercentage: Double {
        if let p = percentage {
            return min(max(p, 0), 100)
        }
        if let used = usage, let total = currentValue, total > 0 {
            return min(max(used / total * 100, 0), 100)
        }
        return 0
    }

    /// Human readable card title (defensive mapping, never crashes on unknown values).
    var displayTitle: String {
        let u = (unit ?? "").lowercased()
        let t = (type ?? "").lowercased()
        let combined = "\(u) \(t)"
        if combined.contains("five") || u.contains("5") || combined.contains("hour") || combined.contains("小时") {
            return "5小时额度"
        }
        if combined.contains("week") || combined.contains("周") {
            return "周额度"
        }
        if combined.contains("month") || combined.contains("月") {
            return "月额度"
        }
        if let unit, !unit.isEmpty { return unit }
        if let type, !type.isEmpty { return type }
        return "额度"
    }

    /// Display order: 5h window first, weekly second, everything else after.
    var rank: Int {
        switch displayTitle {
        case "5小时额度": return 0
        case "周额度": return 1
        default: return 2
        }
    }
}

/// Per-model usage breakdown shown in tooltips on the web page.
/// The web frontend historically reads a field literally named `mdoelCode` (typo preserved),
/// so we decode both spellings.
struct UsageDetail: Codable, Equatable {
    let modelCode: String?
    let name: String?
    let usage: Double?

    enum CodingKeys: String, CodingKey {
        case modelCode
        case mdoelCode
        case name
        case usage
    }

    init(modelCode: String?, name: String?, usage: Double?) {
        self.modelCode = modelCode
        self.name = name
        self.usage = usage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let v = try c.decodeIfPresent(String.self, forKey: .modelCode) {
            modelCode = v
        } else if let v = try c.decodeIfPresent(String.self, forKey: .mdoelCode) {
            modelCode = v
        } else {
            modelCode = nil
        }
        name = try c.decodeIfPresent(String.self, forKey: .name)
        usage = try c.decodeIfPresent(Double.self, forKey: .usage)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(modelCode, forKey: .mdoelCode)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(usage, forKey: .usage)
    }
}
