import SwiftUI

/// The menu bar status item: a compact gradient capsule that changes color
/// with usage level, so it stands out from neighboring monochrome icons.
struct MenuBarBadge: View {
    @ObservedObject var model: AppModel

    var body: some View {
        switch model.state {
        case .ok:
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8, weight: .black))
                Text(model.menuBarText)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.usageGradient(for: model.menuBarPercentage)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: Theme.usageGlow(for: model.menuBarPercentage).opacity(0.55), radius: 3, y: 1)

        case .loading:
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8, weight: .black))
                Text("…")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.accentGradient))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: Color.blue.opacity(0.5), radius: 3, y: 1)

        case .loggedOut:
            Text("未登录")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.14)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5))

        case .error:
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8, weight: .bold))
                Text("重试")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.usageGradient(for: 100)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: Theme.usageGlow(for: 100).opacity(0.55), radius: 3, y: 1)
        }
    }
}
