import Foundation

/// GET https://bigmodel.cn/api/monitor/credit-usage/usage-detail
/// Verified live response (trimmed):
/// {"code":200,"success":true,"data":{
///   "summary":{"cacheHitRate":{"value":"0.8190","trend":"-0.1247"}, ...},
///   "modelUsage":{...}}}
struct CacheHitResponse: Codable, Equatable {
    let code: Int
    let success: Bool
    let msg: String?
    let data: CacheHitData?
}

struct CacheHitData: Codable, Equatable {
    let summary: CacheHitSummary?
}

struct CacheHitSummary: Codable, Equatable {
    /// Fraction as a numeric string, e.g. "0.8190" = 81.9%.
    let cacheHitRate: CacheHitMetric?
}

struct CacheHitMetric: Codable, Equatable {
    let value: String?
    let trend: String?
}

struct CacheRates: Equatable {
    let today: Double?
    let weekly: Double?
}
