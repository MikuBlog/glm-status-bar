import SwiftUI

struct PanelView: View {
    @EnvironmentObject private var model: AppModel

    /// Ceiling for the scrollable content area, set by the presenter from the
    /// screen size. Content shorter than this renders without any scrolling.
    var maxContentHeight: CGFloat = .infinity
    @State private var launchAtLogin = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        ZStack {
            Theme.panelBackground
            VStack(spacing: 0) {
                header
                content
                footer
            }
            .padding(.vertical, 10)
        }
        .preferredColorScheme(.dark)
        .onAppear { launchAtLogin = LaunchAtLoginManager.isEnabled }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.accentGradient)
                    .frame(width: 30, height: 30)
                    .shadow(color: Color.cyan.opacity(0.45), radius: 7)
                Image(systemName: "gauge.with.needle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("GLM Coding Plan")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if let badge = model.planLevelBadge {
                        Text(badge)
                            .font(.system(size: 8, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accentGradient))
                    }
                }
                HStack(spacing: 4) {
                    PulsingDot(color: statusColor)
                    Text(headerSubtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .monospacedDigit()
                }
            }

            Spacer()

            refreshButton
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var headerSubtitle: String {
        if let lastUpdated = model.lastUpdated {
            return "实时 · \(Self.timeFormatter.string(from: lastUpdated)) · 每 \(Int(model.pollInterval))s"
        }
        return "每 \(Int(model.pollInterval)) 秒自动刷新"
    }

    private var statusColor: Color {
        switch model.state {
        case .ok: return .green
        case .loading: return .blue
        case .error: return .orange
        case .loggedOut: return .gray
        }
    }

    private var refreshButton: some View {
        Button {
            model.refreshNow()
        } label: {
            Hoverable { hovering in
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(hovering ? Theme.textPrimary : Theme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(hovering ? 0.14 : 0.07)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.10)))
                    .scaleEffect(hovering ? 1.05 : 1)
                    .rotationEffect(.degrees(model.isRefreshing ? 360 : 0))
                    .animation(
                        model.isRefreshing
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .spring(response: 0.25, dampingFraction: 0.7),
                        value: model.isRefreshing
                    )
            }
        }
        .buttonStyle(.plain)
        .help("立即刷新")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loggedOut:
            loggedOutView
        case .loading:
            loadingView
        case .ok:
            cards
        case .error(let message, _):
            errorView(message)
        }
    }

    private var loggedOutView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 64, height: 64)
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.textTertiary)
            }
            Text(model.loginNotice ?? "尚未登录 BigModel 账号")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            loginButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
    }

    private var loginButton: some View {
        Button {
            model.showLoginWindow()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 12, weight: .semibold))
                Text("登录 BigModel")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.accentGradient))
            .shadow(color: Color.blue.opacity(0.45), radius: 8)
        }
        .buttonStyle(.plain)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(.cyan)
            Text("正在获取额度…")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
                .shadow(color: .orange.opacity(0.5), radius: 8)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                model.refreshNow()
            } label: {
                Label("重试", systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    private var cards: some View {
        let limits = model.displayLimits
        let columns: [GridItem] = {
            switch limits.count {
            case 2: return [GridItem(.flexible()), GridItem(.flexible())]
            case 1: return [GridItem(.flexible())]
            default: return [GridItem(.adaptive(minimum: 300), spacing: 10)]
            }
        }()
        let quotaGrid = LazyVGrid(
            columns: columns,
            spacing: 10
        ) {
            ForEach(limits) { limit in
                QuotaCard(limit: limit)
            }
        }
        .padding(.horizontal, 14)

        return ScrollView {
            VStack(spacing: 10) {
                quotaGrid
                UsageDashboardView()
                    .padding(.horizontal, 14)
            }
            .padding(.bottom, 4)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: maxContentHeight)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            launchAtLoginToggle

            Spacer()

            Button {
                NSWorkspace.shared.open(AppModel.overviewURL)
            } label: {
                Hoverable { hovering in
                    Label("打开网页版", systemImage: "globe")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(hovering ? 0.10 : 0)))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.00))
            .help("在浏览器中查看完整用量页面")

            Spacer()

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1, height: 10)

            Button {
                NSApp.terminate(nil)
            } label: {
                Hoverable { hovering in
                    Label("退出", systemImage: "power")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(hovering ? 0.10 : 0)))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textTertiary)
            .help("退出应用")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var launchAtLoginToggle: some View {
        HStack(spacing: 6) {
            ThemedToggle(isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    if !LaunchAtLoginManager.setEnabled(newValue) {
                        // System rejected the change — reflect reality back.
                        launchAtLogin = LaunchAtLoginManager.isEnabled
                    }
                }
            Text("开机自启")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .help("登录 Mac 后自动启动 GLM StatusBar")
    }
}
