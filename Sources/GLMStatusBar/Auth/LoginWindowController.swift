import AppKit
import WebKit

@MainActor
final class LoginWindowController: NSWindowController, WKNavigationDelegate, NSWindowDelegate {
    static let loginURL = URL(string: "https://bigmodel.cn/coding-plan/personal/overview")!
    private static let tokenJS = "localStorage.getItem('bigmodel_token_production') || ''"
    private static let tokenCookieName = "bigmodel_token_production"

    private var webView: WKWebView?
    private var pollTimer: Timer?
    private let onToken: (String) -> Void

    init(onToken: @escaping (String) -> Void) {
        self.onToken = onToken

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default() // persistent across launches
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 500, height: 700), configuration: configuration)
        view.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "登录 BigModel"
        window.contentView = view

        super.init(window: window)

        window.delegate = self
        view.navigationDelegate = self
        webView = view
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func open() {
        if webView?.url == nil {
            webView?.load(URLRequest(url: Self.loginURL))
        }
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startPolling()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.probeToken()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func probeToken() {
        webView?.evaluateJavaScript(Self.tokenJS) { [weak self] result, _ in
            guard let raw = result as? String else { return }
            self?.accept(raw)
        }
        // The web app's axios interceptor reads the Authorization token from the
        // `bigmodel_token_production` cookie (domain .bigmodel.cn), not only from
        // localStorage — so poll the shared WKWebView cookie store as well.
        webView?.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let cookie = cookies.first(where: {
                $0.name == Self.tokenCookieName && $0.domain.contains("bigmodel.cn")
            }) else { return }
            self?.accept(cookie.value)
        }
    }

    private func accept(_ raw: String) {
        guard let token = TokenStore.normalize(raw) else { return }
        stopPolling()
        window?.orderOut(nil)
        onToken(token)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        probeToken()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        stopPolling()
    }
}
