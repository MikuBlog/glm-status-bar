import Foundation

/// GET /api/biz/customer-package-reset/list?targetType=PERSONAL
/// Manual quota-reset entitlements granted with the plan.
struct ResetListResponse: Codable, Equatable {
    let code: Int
    let success: Bool
    let msg: String?
    let data: ResetQuotaData?
}

struct ResetQuotaData: Codable, Equatable {
    let fiveHourResets: [ResetRecord]?
    let weekResets: [ResetRecord]?

    var fiveHourCount: Int { (fiveHourResets ?? []).filter { $0.available == true }.count }
    var weekCount: Int { (weekResets ?? []).filter { $0.available == true }.count }
    var totalCount: Int { fiveHourCount + weekCount }
}

struct ResetRecord: Codable, Equatable {
    let recordId: Double?
    let grantType: String?
    let expireTime: String?
    let available: Bool?
}
