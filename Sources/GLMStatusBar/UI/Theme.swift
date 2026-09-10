import SwiftUI

enum Theme {
    // MARK: - Palette

    static let bgTop = Color(red: 0.085, green: 0.10, blue: 0.17)
    static let bgBottom = Color(red: 0.035, green: 0.04, blue: 0.085)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)

    // MARK: - Usage gradients

    static func usageGradient(for percentage: Double) -> LinearGradient {
        switch QuotaFormat.level(for: percentage) {
        case .normal:
            LinearGradient(colors: [Color(red: 0.20, green: 0.85, blue: 0.65),
                                    Color(red: 0.15, green: 0.75, blue: 0.95)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .warning:
            LinearGradient(colors: [Color(red: 1.00, green: 0.72, blue: 0.20),
                                    Color(red: 1.00, green: 0.50, blue: 0.24)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .critical:
            LinearGradient(colors: [Color(red: 1.00, green: 0.32, blue: 0.38),
                                    Color(red: 0.95, green: 0.20, blue: 0.62)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static func usageGlow(for percentage: Double) -> Color {
        switch QuotaFormat.level(for: percentage) {
        case .normal: return Color(red: 0.15, green: 0.85, blue: 0.80)
        case .warning: return Color(red: 1.00, green: 0.62, blue: 0.22)
        case .critical: return Color(red: 1.00, green: 0.28, blue: 0.45)
        }
    }

    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.35, green: 0.55, blue: 1.00),
                 Color(red: 0.30, green: 0.85, blue: 0.98)],
        startPoint: .leading, endPoint: .trailing
    )

    // MARK: - Surfaces

    static let cardFill = LinearGradient(
        colors: [Color.white.opacity(0.085), Color.white.opacity(0.035)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let cardBorder = Color.white.opacity(0.10)

    static func cardShape(radius: CGFloat = 18) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    // MARK: - Background

    static var panelBackground: some View {
        ZStack {
            LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(Color.blue.opacity(0.14))
                .blur(radius: 46)
                .frame(width: 220, height: 220)
                .offset(x: -110, y: -80)
            Circle()
                .fill(Color.cyan.opacity(0.10))
                .blur(radius: 52)
                .frame(width: 240, height: 240)
                .offset(x: 120, y: 60)
            Circle()
                .fill(Color.purple.opacity(0.09))
                .blur(radius: 56)
                .frame(width: 200, height: 200)
                .offset(x: -60, y: 200)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Pulsing status dot

struct PulsingDot: View {
    let color: Color
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: 12, height: 12)
                .scaleEffect(pulsing ? 1.5 : 0.8)
                .opacity(pulsing ? 0 : 1)
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
        .onDisappear {
            // Stop the infinite animation when the panel is closed.
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { pulsing = false }
        }
    }
}

// MARK: - Hover highlight wrapper

struct Hoverable<Content: View>: View {
    @ViewBuilder let content: (Bool) -> Content
    @State private var hovering = false

    var body: some View {
        content(hovering).onHover { hovering = $0 }
    }
}
