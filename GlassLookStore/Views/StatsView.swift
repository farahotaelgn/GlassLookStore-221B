import SwiftUI
import Charts

/// Weekly and monthly usage charts inside glass cards.
struct StatsView: View {
    @Environment(LiveStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let s = store.snapshot
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Stats")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        label("THIS WEEK, LIMIT USED")
                        Chart {
                            ForEach(Array(s.weekUsage.enumerated()), id: \.offset) { i, v in
                                BarMark(x: .value("Day", Self.dayName(back: s.weekUsage.count - 1 - i)), y: .value("Used", v * 100))
                                    .foregroundStyle(v > 0.8 ? Color.orange : settings.accent)
                                    .cornerRadius(6)
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 170)
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        label("LAST 30 DAYS")
                        Chart {
                            ForEach(Array(s.monthUsage.enumerated()), id: \.offset) { i, v in
                                AreaMark(x: .value("Day", i + 1), y: .value("Used", v * 100))
                                    .foregroundStyle(LinearGradient(colors: [settings.accent.opacity(0.3), settings.accent.opacity(0)],
                                                                    startPoint: .top, endPoint: .bottom))
                                    .interpolationMethod(.catmullRom)
                                LineMark(x: .value("Day", i + 1), y: .value("Used", v * 100))
                                    .foregroundStyle(settings.accent)
                                    .interpolationMethod(.catmullRom)
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 170)
                    }
                }
                HStack(spacing: 12) {
                    StatTile(title: "Week average", value: "\(Int(average(s.weekUsage) * 100))%")
                    StatTile(title: "Month average", value: "\(Int(average(s.monthUsage) * 100))%")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.system(size: 10.5, weight: .bold, design: .rounded)).tracking(0.4).foregroundStyle(.secondary)
    }

    private func average(_ v: [Double]) -> Double { v.isEmpty ? 0 : v.reduce(0, +) / Double(v.count) }

    static func dayName(back: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: -back, to: .now) ?? .now
        return d.formatted(.dateTime.weekday(.abbreviated))
    }
}
