import SwiftUI

struct QuotaCard: View {
    let limit: QuotaLimit

    @State private var animatedPercentage: Double = 0

    private var percentage: Double { limit.effectivePercentage }
    private var gradient: LinearGradient { Theme.usageGradient(for: percentage) }
    private var glow: Color { Theme.usageGlow(for: percentage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            HStack(alignment: .center, spacing: 12) {
                ring
                stats
            }
            resetFooter
        }
        .padding(16)
        .background(Theme.cardShape().fill(Theme.cardFill))
        .overlay(Theme.cardShape().strokeBorder(Theme.cardBorder))
        .onAppear { animatedPercentage = percentage }
        .onChange(of: percentage) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedPercentage = newValue
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(gradient)
            Text(limit.displayTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(QuotaFormat.percentText(percentage))% 已使用")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.07)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
        }
    }

    // MARK: - Progress ring

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.09), lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0.02, animatedPercentage / 100))
                .stroke(gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: glow.opacity(0.75), radius: 7)
                .shadow(color: glow.opacity(0.35), radius: 14)
            VStack(spacing: 0) {
                Text(QuotaFormat.percentText(animatedPercentage))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: 58, height: 58)
    }

    // MARK: - Stats

    private var stats: some View {
        VStack(alignment: .leading, spacing: 6) {
            statRow(label: "已用积分", value: QuotaFormat.used(limit.usedCredits), prominent: true)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("总额")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                Text(QuotaFormat.total(limit.totalCredits))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Theme.textSecondary)
                Text("· 剩余")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                Text(QuotaFormat.total(limit.remaining))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statRow(label: String, value: String, prominent: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: prominent ? 13 : 11,
                              weight: prominent ? .bold : .semibold,
                              design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(prominent ? Theme.textPrimary : Theme.textSecondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Reset footer

    private var resetFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            resetText
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var resetText: some View {
        if let epoch = limit.nextResetTime {
            let date = ResetTime.parse(epochMilliseconds: epoch)
            Text("\(ResetTime.absolute(date)) · \(ResetTime.relative(date))")
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textTertiary)
        }
    }
}
