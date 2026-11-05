import SwiftUI
import Charts

/// Usage over the last 7 days: an area, a line and the last point emphasised.
struct SparklineCard: View {
    let values: [Double]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        GlassCard(cornerRadius: 36, bevel: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("USAGE, LAST 7 DAYS")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                Chart {
                    ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                        AreaMark(x: .value("Day", i), y: .value("Used", v * 100))
                            .foregroundStyle(LinearGradient(colors: [settings.accent.opacity(0.28), settings.accent.opacity(0)],
                                                            startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Day", i), y: .value("Used", v * 100))
                            .foregroundStyle(settings.accent)
                            .interpolationMethod(.catmullRom)
                    }
                    if let last = values.last {
                        PointMark(x: .value("Day", values.count - 1), y: .value("Used", last * 100))
                            .foregroundStyle(settings.accent)
                            .symbolSize(50)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { _ in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.25))
                    }
                }
                .frame(height: 84)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usage over the last 7 days")
        .accessibilityValue(values.map { "\(Int($0 * 100)) percent" }.joined(separator: ", "))
    }
}
