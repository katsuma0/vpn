import SwiftUI

/// The one big button. Gray when off, orange while it works, green when you're safe.
struct ConnectButton: View {
    let phase: VPNController.Phase
    let isEnabled: Bool
    let action: () -> Void

    @State private var pulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 220, height: 220)
                    .scaleEffect(phase == .connecting && pulsing ? 1.1 : 1)
                Circle()
                    .fill(color.gradient)
                    .frame(width: 168, height: 168)
                    .shadow(color: color.opacity(0.45), radius: 18, y: 8)
                Image(systemName: "power")
                    .font(.system(size: 62, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.35), value: phase)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .accessibilityLabel(phase == .off ? "Connect" : "Disconnect")
    }

    private var color: Color {
        switch phase {
        case .off: return .gray
        case .connecting, .disconnecting: return .orange
        case .on: return .green
        }
    }
}

/// A round badge with the country code. Flags would be nicer, but codes
/// read clearly at any size and never render as a missing glyph.
struct CountryBadge: View {
    let code: String
    var size: CGFloat = 40

    var body: some View {
        Text(code == Country.otherCode ? "?" : code.uppercased())
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(CountryBadge.color(for: code).gradient))
            .accessibilityHidden(true)
    }

    static func color(for code: String) -> Color {
        let palette: [Color] = [.blue, .indigo, .purple, .pink, .red, .orange, .teal, .green, .cyan, .mint, .brown]
        let sum = code.uppercased().unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }
}
