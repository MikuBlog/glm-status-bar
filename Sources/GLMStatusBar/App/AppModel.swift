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
    static let overviewURL = URL(string: "https://bigmodel.cn/coding-plan/personal/overview")!
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    /// Auto refresh cadence (per product requirement: every 3 seconds).
    let pollInterval: TimeInterval = 3

    @Published private(set) var state: State
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    /// Shown on the logged-out panel, e.g. "凭证已过期，请重新登录".
    @Published var loginNotice: String?

    private var token: String?
    private var timer: Timer?
    private var inFlight = false
    private var loginController: LoginWindowController?

    /// Developer/UI-snapshot only: inject a state without touching the network.
    func overrideForSnapshot(_ newState: State) {
        token = nil
        timer?.invalidate()
        state = newState
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
    }

    func refreshNow() {
        fetch()
        restartTimer()
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
