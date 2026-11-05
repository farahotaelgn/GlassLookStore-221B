import SwiftUI

/// A small glass tile (IMG4 lock screen widgets): a label and one big thin number that rolls when it changes.
struct StatTile: View {
    let title: String
    let value: String
    var dot: Color? = nil

    var body: some View {
        GlassCard(cornerRadius: 30, bevel: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    if let dot {
                        Circle().fill(dot).frame(width: 9, height: 9)
                    }
                    Text(value)
                        .font(.system(size: 30, weight: .thin).width(.condensed))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: value)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
