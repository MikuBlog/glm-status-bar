import SwiftUI

struct PanelView: View {
    @EnvironmentObject private var model: AppModel

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.6)
            content
            Divider().opacity(0.6)
            footer
        }
        .padding(.vertical, 4)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("GLM Coding Plan")
                    .font(.system(size: 13, weight: .semibold))
                if let lastUpdated = model.lastUpdated {
                    Text("更新于 \(Self.timeFormatter.string(from: lastUpdated)) · 每 \(Int(model.pollInterval)) 秒自动刷新")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("每 \(Int(model.pollInterval)) 秒自动刷新")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                model.refreshNow()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .rotationEffect(.degrees(model.isRefreshing ? 360 : 0))
                    .animation(
                        model.isRefreshing
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: model.isRefreshing
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .help("立即刷新")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
            Image(systemName: "lock.circle")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text(model.loginNotice ?? "尚未登录 BigModel 账号")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                model.showLoginWindow()
            } label: {
                Label("登录 BigModel", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.tint))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("正在获取额度…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34))
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                model.refreshNow()
            } label: {
                Label("重试", systemImage: "arrow.clockwise")
                    .font(.callout.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
    }

    private var cards: some View {
        let limits = model.displayLimits
        let grid = LazyVGrid(
            columns: limits.count >= 3
                ? [GridItem(.adaptive(minimum: 240), spacing: 10)]
                : [GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(limits) { limit in
                QuotaCard(limit: limit)
            }
        }
        .padding(16)

        return Group {
            if limits.count > 3 {
                ScrollView {
                    grid
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: 460)
            } else {
                grid
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 14) {
            Button {
                NSWorkspace.shared.open(AppModel.overviewURL)
            } label: {
                Label("打开网页版", systemImage: "globe")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .help("在浏览器中查看完整用量页面")
            Spacer()
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("退出应用")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .font(.caption)
    }
}
