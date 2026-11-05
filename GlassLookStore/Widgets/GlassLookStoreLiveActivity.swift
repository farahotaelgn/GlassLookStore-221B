import SwiftUI
import WidgetKit
@preconcurrency import ActivityKit

// Shared by the app (starts and updates it) and the widget extension (draws it).

/// The running session on the Lock Screen and in the Dynamic Island.
struct SessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var usageLeft: Double
        var tokens: Int
        var status: String
        var buildOK: Bool
    }

    var projectName: String
    var sessionStart: Date
}

#if !WIDGET_EXTENSION
/// Starts the Live Activity with the session, updates it once a minute (not every second), ends it when switched off.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var activity: Activity<SessionActivityAttributes>?
    private(set) var statusLine = "Not started yet"

    func sync(snapshot s: CounterSnapshot, enabled: Bool) async {
        guard enabled else { await end(); return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            statusLine = "Live Activities are off in iOS Settings"
            return
        }
        let state = SessionActivityAttributes.ContentState(usageLeft: s.usageLeft, tokens: s.tokensToday, status: s.status, buildOK: s.lastBuildOK)
        let content = ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(180))
        if let a = activity ?? Activity<SessionActivityAttributes>.activities.first {
            activity = a
            await a.update(content)
            statusLine = "Running, updated \(Date.now.formatted(date: .omitted, time: .shortened))"
        } else {
            do {
                activity = try Activity.request(attributes: SessionActivityAttributes(projectName: s.projectName, sessionStart: s.sessionStart),
                                                content: content)
                statusLine = "Started"
            } catch {
                statusLine = "Could not start: \(error.localizedDescription)"
            }
        }
    }

    func end() async {
        for a in Activity<SessionActivityAttributes>.activities {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
        statusLine = "Off"
    }
}
#endif

struct GlassLookStoreLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            SessionLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.sessionStart, style: .timer).monospacedDigit()
                    } icon: {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                    }
                    .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.usageLeft * 100))% left").font(.headline).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: context.state.usageLeft).tint(GlassPalette.accent)
                        Text("\(context.attributes.projectName)  ·  \(context.state.tokens.formatted()) tokens").font(.caption)
                    }
                }
            } compactLeading: {
                Text(context.attributes.sessionStart, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } compactTrailing: {
                Text("\(Int(context.state.usageLeft * 100))%").monospacedDigit()
            } minimal: {
                Image(systemName: "gauge.with.dots.needle.67percent")
            }
        }
    }
}

struct SessionLockScreenView: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(attributes.projectName).font(.caption.bold())
                Text(attributes.sessionStart, style: .timer)
                    .font(.system(size: 40, weight: .ultraLight).width(.condensed))
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(Int(state.usageLeft * 100))% usage left").font(.caption.bold())
                ProgressView(value: state.usageLeft).tint(.white).frame(width: 110)
                Label(state.buildOK ? "Build passed" : "Build failed", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(state.buildOK ? .green : .red)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}
