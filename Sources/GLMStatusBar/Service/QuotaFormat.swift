import Foundation
import SwiftUI

enum QuotaFormat {
    enum UsageLevel: Int, Equatable {
        case normal = 0
        case warning = 1
        case critical = 2
    }

    private static let grouping: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.usesGroupingSeparator = true
        return f
    }()

    /// Used credits, e.g. 2140 -> "2,140"
    static func used(_ value: Double?) -> String {
        guard let value else { return "--" }
        return grouping.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    /// Total credits, mirroring the web page: 28000 -> "2.8万", 140000 -> "14万"
    static func total(_ value: Double?) -> String {
        guard let value else { return "--" }
        if value >= 10_000 {
            let wan = value / 10_000
            let s = wan >= 100 ? String(format: "%.0f", wan) : String(format: "%.1f", wan)
            let trimmed = s.hasSuffix(".0") ? String(s.dropLast(2)) : s
            return "\(trimmed)万"
        }
        return used(value)
    }

    static func level(for percentage: Double) -> UsageLevel {
        if percentage >= 80 { return .critical }
        if percentage >= 50 { return .warning }
        return .normal
    }

    static func color(for percentage: Double) -> Color {
        switch level(for: percentage) {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    static func percentText(_ percentage: Double) -> String {
        String(Int(percentage.rounded()))
    }
}

enum ResetTime {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    /// Defensive date parsing: epoch seconds/milliseconds, ISO8601 (with/without
    /// fractional seconds), and the common "yyyy-MM-dd HH:mm:ss" shapes.
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let n = Double(raw) {
            if n > 1e12 { return Date(timeIntervalSince1970: n / 1000) }
            if n > 1e9 { return Date(timeIntervalSince1970: n) }
        }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: raw) { return d }
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFractional.date(from: raw) { return d }

        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "MM-dd HH:mm",
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        for format in formats {
            df.dateFormat = format
            if let d = df.date(from: raw) { return d }
        }
        return nil
    }

    /// Epoch milliseconds as delivered by the live API.
    static func parse(epochMilliseconds: Double) -> Date {
        Date(timeIntervalSince1970: epochMilliseconds / 1000)
    }

    /// "21:05 重置" for today, "9月17日 15:41 重置" otherwise.
    static func absolute(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "\(timeFormatter.string(from: date)) 重置"
        }
        return "\(dateTimeFormatter.string(from: date)) 重置"
    }

 /// Relative countdown, e.g. "3小时12分后" / "45分钟后" / "6天后" / "即将重置".
    static func relative(_ date: Date, now: Date = Date()) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 { return "即将重置" }
        if seconds < 60 { return "\(Int(seconds))秒后" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)分钟后" }
        let hours = Int(seconds / 3600)
        if hours < 24 {
            let remainderMinutes = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
            return remainderMinutes > 0 ? "\(hours)小时\(remainderMinutes)分后" : "\(hours)小时后"
        }
        return "\(Int(seconds / 86400))天后"
    }
}
