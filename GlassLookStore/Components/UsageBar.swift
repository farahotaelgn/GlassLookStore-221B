import SwiftUI

/// The battery-style bar of IMG2 and IMG5: "67% usage left" over a thin white track.
struct UsageBar: View {
    let left: Double

    var body: some View {
        let pct = Int((max(0, min(1, left)) * 100).rounded())
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: batterySymbol)
                Text("\(pct)% usage left")
                    .contentTransition(.numericText(value: Double(pct)))
                    .animation(.snappy, value: pct)
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            Capsule()
                .fill(.white.opacity(0.35))
                .frame(width: 110, height: 6)
                .overlay(alignment: .leading) {
                    Capsule().fill(left < 0.2 ? Color.orange : Color.white).frame(width: 110 * max(0, min(1, left)), height: 6)
                        .animation(.snappy, value: left)
                }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usage left")
        .accessibilityValue("\(pct) percent")
    }

    private var batterySymbol: String {
        switch left {
        case ..<0.13: return "battery.0percent"
        case ..<0.38: return "battery.25percent"
        case ..<0.63: return "battery.50percent"
        case ..<0.88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
