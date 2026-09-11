import AppKit
import Foundation
import WebKit

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    enum State: Equatable {
        case loggedOut
        case loading
        case ok([QuotaLimit], level: String?, Date)
        case error(String, isAuthError: Bool)
    }

    enum Outcome {
        case success([QuotaLimit], level: String?)
        case failure(String)
        case authFailure
    }

    /// Coarse state kind used for cheap change detection.
    var stateKind: String {
        switch state {
        case .loggedOut: return "loggedOut"
        case .loading: return "loading"
        case .ok: return "ok"
        case .error: return "error"
        }
    }

    static let apiURL = URL(string: "https://bigmodel.cn/api/monitor/usage/quota/limit")!
    static let cacheHitURL = URL(string: "https://bigmodel.cn/api/monitor/credit-usage/usage-detail")!
    static let overviewURL = URL(string: "https://bigmodel.cn/coding-plan/personal/overview")!
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    /// Auto refresh cadence (per product requirement: every 3 seconds).
    let pollInterval: TimeInterval = 3
    /// Cache hit rates move slowly — refresh them on a slower cadence.
    let cachePollInterval: TimeInterval = 15

    @Published private(set) var state: State
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var cacheRates: CacheRates?
    /// Shown on the logged-out panel, e.g. "凭证已过期，请重新登录".
    @Published var loginNotice: String?

    private var token: String?
    private var timer: Timer?
    private var cacheTimer: Timer?
    private var inFlight = false
    private var cacheInFlight = false
    private var loginController: LoginWindowController?

    /// Developer/UI-snapshot only: inject a state without touching the network.
    func overrideForSnapshot(_ newState: State, cacheRates: CacheRates? = nil) {
        token = nil
        timer?.invalidate()
        state = newState
        self.cacheRates = cacheRates
        if case .ok = newState { lastUpdated = Date() }
    }

    init() {
        token = TokenStore.load()
        if token != nil {
            state = .loading
            startPolling()
        } else {
            state = .loggedOut
        }
    }

    // MARK: - Polling

    func startPolling() {
        state = .loading
        fetch()
        restartTimer()
        fetchCacheRates()
        restartCacheTimer()
    }

    func refreshNow() {
        fetch()
        restartTimer()
        // Cache rates are on their own slower cadence; no need to refresh here.
    }

    private func restartCacheTimer() {
        cacheTimer?.invalidate()
        cacheTimer = Timer.scheduledTimer(withTimeInterval: cachePollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchCacheRates()
            }
        }
    }

    /// Serial fetch of today's and the trailing-7-day cache hit rates, then a
    /// single @Published update.
    private func fetchCacheRates() {
        guard !cacheInFlight else { return }
        guard let token else { return }
        cacheInFlight = true

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: Date())
        let dayEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart) ?? Date()
        let weekStart = calendar.date(byAdding: .day, value: -6, to: dayStart) ?? dayStart

        fetchCacheHit(start: weekStart, end: dayEnd) { [weak self] weekly in
            self?.fetchCacheHit(start: dayStart, end: dayEnd) { [weak self] today in
                self?.cacheRates = CacheRates(today: today, weekly: weekly)
                self?.cacheInFlight = false
            }
        }
    }

    private func fetchCacheHit(start: Date, end: Date, completion: @escaping (Double?) -> Void) {
        guard let token else {
            completion(nil)
            return
        }
        var comps = URLComponents(url: Self.cacheHitURL, resolvingAgainstBaseURL: false)!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        comps.queryItems = [
            URLQueryItem(name: "usageType", value: "MODEL"),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "startTime", value: formatter.string(from: start)),
            URLQueryItem(name: "endTime", value: formatter.string(from: end)),
        ]
        var request = URLRequest(url: comps.url!, timeoutInterval: 10)
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let rate = AppModel.parseCacheHitRate(data: data)
            Task { @MainActor in
                completion(rate)
            }
        }.resume()
    }

    /// Extract `data.summary.cacheHitRate.value` (fraction string) from the
    /// usage-detail response. Auth failures yield nil silently — the quota
    /// poll drives the global auth state.
    nonisolated static func parseCacheHitRate(data: Data?) -> Double? {
        guard let data,
              let body = try? JSONDecoder().decode(CacheHitResponse.self, from: data),
              body.success,
              let raw = body.data?.summary?.cacheHitRate?.value,
              let fraction = Double(raw) else { return nil }
        return min(max(fraction, 0), 1)
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetch()
            }
        }
    }

    private func fetch() {
        guard !inFlight else { return }
        guard let token else {
            timer?.invalidate()
            state = .loggedOut
            return
        }

        inFlight = true
        isRefreshing = true

        var request = URLRequest(url: Self.apiURL, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://bigmodel.cn", forHTTPHeaderField: "Referer")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let outcome = AppModel.classify(data: data, response: response, error: error)
            Task { @MainActor in
                self?.finish(with: outcome)
            }
        }.resume()
    }

    private func finish(with outcome: Outcome) {
        inFlight = false
        isRefreshing = false

        switch outcome {
        case .authFailure:
            TokenStore.clear()
            token = nil
            cacheTimer?.invalidate()
            cacheRates = nil
            loginNotice = "凭证已过期，请重新登录"
            state = .loggedOut
            showLoginWindow()

        case .failure(let message):
            state = .error(message, isAuthError: false)

        case .success(let limits, let level):
            let now = Date()
            lastUpdated = now
            state = .ok(limits, level: level, now)
        }
    }

    // MARK: - Response classification (pure, unit-testable)

    nonisolated static func classify(data: Data?, response: URLResponse?, error: Error?) -> Outcome {
        if let error {
            return .failure("网络错误：\((error as NSError).localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse else {
            return .failure("无效的服务器响应")
        }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 || http.statusCode == 403 { return .authFailure }
            return .failure("服务器错误（HTTP \(http.statusCode)）")
        }
        guard let data else { return .failure("空响应") }

        guard let body = try? JSONDecoder().decode(QuotaResponse.self, from: data) else {
            return .failure("响应解析失败")
        }
        // Expired / invalid token comes back as HTTP 200 with body code 401;
        // 1001 means "Authorization header missing".
        if body.code == 401 || body.code == 1001 { return .authFailure }
        guard body.success, let quota = body.data else {
            return .failure(body.msg ?? "接口返回异常（code \(body.code)）")
        }
        guard !quota.limits.isEmpty else {
            return .failure("暂无额度数据，请确认已订阅 Coding Plan")
        }
        return .success(quota.limits, level: quota.level)
    }

    // MARK: - Display helpers

    /// All limits, ordered 5h first, weekly second, others by usage.
    var displayLimits: [QuotaLimit] {
        guard case .ok(let limits, _, _) = state else { return [] }
        return limits.sorted { a, b in
            if a.rank != b.rank { return a.rank < b.rank }
            return a.effectivePercentage > b.effectivePercentage
        }
    }

    /// Plan tier from the API, e.g. "max" -> "MAX".
    var planLevelBadge: String? {
        guard case .ok(_, let level, _) = state, let level, !level.isEmpty else { return nil }
        return level.uppercased()
    }

    /// The (up to) two limits surfaced in the menu bar itself.
    var barLimits: [QuotaLimit] {
        Array(displayLimits.prefix(2))
    }

    var menuBarText: String {
        switch state {
        case .loggedOut: return "未登录"
        case .loading: return "…"
        case .error: return "!"
        case .ok: return barLimits.map { "\(QuotaFormat.percentText($0.effectivePercentage))%" }
                .joined(separator: "·")
        }
    }

    var menuBarPercentage: Double {
        barLimits.map(\.effectivePercentage).max() ?? 0
    }

    // MARK: - Login

    func showLoginWindow() {
        if loginController == nil {
            loginController = LoginWindowController { [weak self] raw in
                self?.handleLoginToken(raw)
            }
        }
        loginController?.open()
    }

    /// Log out of the BigModel account (keeps the app running).
    func logout() {
        TokenStore.clear()
        token = nil
        timer?.invalidate()
        cacheTimer?.invalidate()
        cacheRates = nil
        loginController?.close()
        loginController = nil
        loginNotice = "已退出登录，可重新登录或切换账号"
        state = .loggedOut
        clearWebSession()
    }

    /// Clear the WKWebView session so the next login shows a fresh login page
    /// instead of silently re-using the previous account's cookie.
    private func clearWebSession() {
        let store = WKWebsiteDataStore.default()
        store.removeData(
            ofTypes: [WKWebsiteDataTypeCookies, WKWebsiteDataTypeLocalStorage,
                      WKWebsiteDataTypeSessionStorage],
            modifiedSince: .distantPast
        ) {}
    }

    private func handleLoginToken(_ raw: String) {
        guard let normalized = TokenStore.normalize(raw) else { return }
        token = normalized
        TokenStore.save(normalized)
        loginNotice = nil
        startPolling()
    }
}
