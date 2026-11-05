import SwiftUI
import WidgetKit

// The widget extension: a Home Screen widget (small, medium) and Lock Screen widgets (circular, rectangular, inline)
// showing session time and usage left in the same glass style, plus the Live Activity.

@main
struct GlassLookStoreWidgets: WidgetBundle {
    var body: some Widget {
        SessionWidget()
        GlassLookStoreLiveActivity()
    }
}

struct SessionEntry: TimelineEntry, Sendable {
    let date: Date
    let snapshot: CounterSnapshot
}

struct SessionTimeline: TimelineProvider {
    func placeholder(in context: Context) -> SessionEntry { SessionEntry(date: .now, snapshot: .placeholder()) }

    func getSnapshot(in context: Context, completion: @escaping (SessionEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionEntry>) -> Void) {
        // The timer text counts by itself; a new entry every 15 minutes refreshes usage left.
        completion(Timeline(entries: [current()], policy: .after(Date.now.addingTimeInterval(15 * 60))))
    }

    private func current() -> SessionEntry {
        SessionEntry(date: .now, snapshot: SharedSnapshot.load() ?? .placeholder())
    }
}

struct SessionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GlassLookStoreSession", provider: SessionTimeline()) { entry in
            SessionWidgetView(entry: entry)
        }
        .configurationDisplayName("Coding session")
        .description("Session time and usage left.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct SessionWidgetView: View {
    let entry: SessionEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let s = entry.snapshot
        Group {
            switch family {
            case .accessoryCircular:
                Gauge(value: s.usageLeft) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                } currentValueLabel: {
                    Text("\(Int(s.usageLeft * 100))")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.projectName).font(.caption2.bold())
                    Text(s.sessionStart, style: .timer).font(.system(size: 22, weight: .light).width(.condensed)).monospacedDigit()
                    ProgressView(value: s.usageLeft) { Text("\(Int(s.usageLeft * 100))% left").font(.caption2) }
                }
            case .accessoryInline:
                Text("\(Int(s.usageLeft * 100))% left  ·  \(s.sessionStart, style: .timer)")
            default:
                home(s)
            }
        }
        .containerBackground(for: .widget) { glassBackground }
    }

    private func home(_ s: CounterSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.projectName).font(.system(size: 12, weight: .bold, design: .rounded)).lineLimit(1)
            Text(s.sessionStart, style: .timer)
                .font(.system(size: family == .systemMedium ? 52 : 38, weight: .ultraLight).width(.condensed))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(Int(s.usageLeft * 100))% usage left").font(.system(size: 11, weight: .bold, design: .rounded))
            Capsule().fill(.white.opacity(0.35)).frame(height: 5)
                .overlay(alignment: .leading) {
                    GeometryReader { g in Capsule().fill(.white).frame(width: g.size.width * s.usageLeft) }
                }
                .frame(height: 5)
        }
        .foregroundStyle(.white)
    }

    private var glassBackground: some View {
        ZStack {
            LinearGradient(colors: scheme == .dark
                           ? [Color(red: 0.89, green: 0.23, blue: 0.31), Color(red: 0.30, green: 0.44, blue: 0.86)]
                           : [Color(red: 0.80, green: 0.81, blue: 0.84), Color(red: 0.55, green: 0.57, blue: 0.62)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.05), .white.opacity(0.3)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 6)
                .blur(radius: 2)
        }
    }
}
