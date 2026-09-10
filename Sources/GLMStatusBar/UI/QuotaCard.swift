import SwiftUI

struct QuotaCard: View {
    let limit: QuotaLimit

    @State private var animatedPercentage: Double = 0

    private var percentage: Double { limit.effectivePercentage }
    private var color: Color { QuotaFormat.color(for: percentage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(limit.displayTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline) {
                Text(QuotaFormat.percentText(percentage))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text("% 已使用")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quinary)
                    Capsule()
                        .fill(color)
                        .frame(width: max(4, geo.size.width * animatedPercentage / 100))
                }
            }
            .frame(height: 6)

            HStack(alignment: .firstTextBaseline) {
                Text("积分 \(QuotaFormat.used(limit.usage)) / \(QuotaFormat.total(limit.currentValue))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                resetText
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.quinary)
        )
        .onAppear {
            animatedPercentage = percentage
        }
        .onChange(of: percentage) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                animatedPercentage = newValue
            }
        }
    }

    @ViewBuilder
    private var resetText: some View {
        if let date = ResetTime.parse(limit.nextResetTime) {
            Text("\(ResetTime.absolute(date)) · \(ResetTime.relative(date))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else if let raw = limit.nextResetTime, !raw.isEmpty {
            Text("\(raw) 重置")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}
