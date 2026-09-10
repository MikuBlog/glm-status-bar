import Foundation

/// GET https://bigmodel.cn/api/monitor/usage/quota/limit
///
/// Verified live response shape:
/// {"code":200,"msg":"操作成功","success":true,
///  "data":{"level":"max","limits":[
///    {"type":"CREDIT_LIMIT","unit":3,"number":5,
///     "usage":28000,"currentValue":5894,"remaining":22105,
///     "percentage":21,"nextResetTime":1789045559098},
///    {"type":"CREDIT_LIMIT","unit":6,"number":1,
///     "usage":140000,"currentValue":5894,"remaining":134105,
///     "percentage":4,"nextResetTime":1789630895994}]}}
///
/// Field semantics (contrary to their names):
/// - `usage`        = TOTAL quota credits (e.g. 28000 = 2.8万)
/// - `currentValue` = USED credits
/// - `remaining`    = remaining credits
/// - `unit` 3 + `number` 5 = 5-hour window; `unit` 6 + `number` 1 = weekly
/// - `nextResetTime` = epoch milliseconds (JSON number)
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
    let unit: Int?
    let number: Double?
    let usage: Double?
    let currentValue: Double?
    let remaining: Double?
    let percentage: Double?
    let nextResetTime: Double?

    var id: String { stableID }

    var stableID: String {
        "\(type ?? "-")|\(unit ?? -1)|\(number ?? 0)|\(nextResetTime ?? 0)"
    }

    /// Total quota credits (the API calls this `usage`).
    var totalCredits: Double? { usage }

    /// Used credits (the API calls this `currentValue`).
    var usedCredits: Double? { currentValue }

    /// Percentage of quota used, clamped to 0...100.
    var effectivePercentage: Double {
        if let p = percentage {
            return min(max(p, 0), 100)
        }
        if let used = usedCredits, let total = totalCredits, total > 0 {
            return min(max(used / total * 100, 0), 100)
        }
        return 0
    }

    /// Human readable title derived from the numeric `unit` enum.
    var displayTitle: String {
        switch unit {
        case 3:
            let hours = Int(number ?? 5)
            return "\(hours)小时额度"
        case 6:
            let weeks = Int(number ?? 1)
            return weeks == 1 ? "周额度" : "\(weeks)周额度"
        default:
            return "额度"
        }
    }

    /// Display order: 5h window first, weekly second, others after.
    var rank: Int {
        switch unit {
        case 3: return 0
        case 6: return 1
        default: return 2
        }
    }

    init(type: String?, unit: Int?, number: Double?, usage: Double?,
         currentValue: Double?, remaining: Double?, percentage: Double?,
         nextResetTime: Double?) {
        self.type = type
        self.unit = unit
        self.number = number
        self.usage = usage
        self.currentValue = currentValue
        self.remaining = remaining
        self.percentage = percentage
        self.nextResetTime = nextResetTime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        unit = try c.decodeIfPresent(Int.self, forKey: .unit)
        number = try c.decodeIfPresent(Double.self, forKey: .number)
        usage = try c.decodeIfPresent(Double.self, forKey: .usage)
        currentValue = try c.decodeIfPresent(Double.self, forKey: .currentValue)
        remaining = try c.decodeIfPresent(Double.self, forKey: .remaining)
        percentage = try c.decodeIfPresent(Double.self, forKey: .percentage)
        // Accept epoch-ms as JSON number or numeric string.
        if let n = try? c.decodeIfPresent(Double.self, forKey: .nextResetTime) {
            nextResetTime = n
        } else if let s = try c.decodeIfPresent(String.self, forKey: .nextResetTime) {
            nextResetTime = Double(s)
        } else {
            nextResetTime = nil
        }
    }
}
