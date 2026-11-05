import Foundation

// Shared by the app and the widget extension: the numbers one screen shows, and how they reach the widget.

/// Everything the Live screen, the widgets and the Live Activity show at one moment.
struct CounterSnapshot: Codable, Sendable, Equatable {
    var sessionStart: Date
    var projectName: String
    var status: String
    /// Share of the session limit still left, 0...1.
    var usageLeft: Double
    var limitReset: Date
    var tokensToday: Int
    var commitsToday: Int
    var linesAdded: Int
    var linesRemoved: Int
    var lastBuildOK: Bool
    var lastBuildAt: Date
    var streakDays: Int
    /// Share of the limit used on each of the last 7 days, oldest first, 0...1.
    var weekUsage: [Double]
    /// Same for the last 30 days.
    var monthUsage: [Double]
    var source: String

    static func placeholder(now: Date = .now) -> CounterSnapshot {
        CounterSnapshot(sessionStart: now.addingTimeInterval(-(2 * 3600 + 14 * 60)), projectName: "GlassLookStore",
                        status: "Coding, session live", usageLeft: 0.67, limitReset: now.addingTimeInterval(3 * 3600 + 41 * 60),
                        tokensToday: 48_210, commitsToday: 7, linesAdded: 412, linesRemoved: 96, lastBuildOK: true,
                        lastBuildAt: now.addingTimeInterval(-25 * 60), streakDays: 12,
                        weekUsage: [0.42, 0.55, 0.48, 0.71, 0.63, 0.82, 0.33],
                        monthUsage: (0..<30).map { 0.35 + 0.3 * abs(sin(Double($0) * 0.7)) }, source: "Mock")
    }

    /// "HH:MM" of the running session.
    static func clock(from start: Date, now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", s / 3600, (s / 60) % 60)
    }

    /// "HH:MM:SS" until a moment.
    static func countdown(to end: Date, now: Date) -> String {
        let s = max(0, Int(end.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
    }
}

struct SessionInfo: Sendable { var start: Date; var project: String; var status: String }
struct UsageInfo: Sendable { var left: Double; var resetsAt: Date; var week: [Double]; var month: [Double] }
struct CommitInfo: Sendable, Equatable { var today: Int; var added: Int; var removed: Int }
struct BuildInfo: Sendable { var ok: Bool; var at: Date }

/// Where the live numbers come from (Mock, Manual or GitHub).
@MainActor
protocol CounterProvider: AnyObject {
    var name: String { get }
    func session(now: Date) async -> SessionInfo
    func usage(now: Date) async -> UsageInfo
    func tokens(now: Date) async -> Int
    func commits(now: Date) async -> CommitInfo
    func builds(now: Date) async -> BuildInfo
    func streak(now: Date) async -> Int
}

extension CounterProvider {
    func snapshot(now: Date) async -> CounterSnapshot {
        let s = await session(now: now)
        let u = await usage(now: now)
        let t = await tokens(now: now)
        let c = await commits(now: now)
        let b = await builds(now: now)
        let k = await streak(now: now)
        return CounterSnapshot(sessionStart: s.start, projectName: s.project, status: s.status, usageLeft: max(0, min(1, u.left)),
                               limitReset: u.resetsAt, tokensToday: t, commitsToday: c.today, linesAdded: c.added,
                               linesRemoved: c.removed, lastBuildOK: b.ok, lastBuildAt: b.at, streakDays: k,
                               weekUsage: u.week, monthUsage: u.month, source: name)
    }
}

/// The snapshot the widgets read, kept in the shared App Group.
enum SharedSnapshot {
    static let group = "group.com.fady.glasslookstore"
    static let key = "snapshot"

    static var defaults: UserDefaults? { UserDefaults(suiteName: group) }

    @discardableResult
    static func save(_ s: CounterSnapshot) -> Bool {
        guard let d = defaults, let data = try? JSONEncoder().encode(s) else { return false }
        d.set(data, forKey: key)
        return true
    }

    static func load() -> CounterSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CounterSnapshot.self, from: data)
    }
}

/// One line on the Logs tab.
struct LogEvent: Codable, Sendable, Identifiable, Equatable {
    enum Kind: String, Codable, Sendable { case session, build, version, warning, note }
    var id = UUID()
    var date: Date
    var kind: Kind
    var text: String

    var symbol: String {
        switch kind {
        case .session: return "play.circle"
        case .build: return "hammer"
        case .version: return "tag"
        case .warning: return "exclamationmark.triangle"
        case .note: return "text.bubble"
        }
    }

    static func samples(now: Date) -> [LogEvent] {
        [LogEvent(date: now.addingTimeInterval(-25 * 60), kind: .build, text: "Build passed (Codemagic, 144 tests)"),
         LogEvent(date: now.addingTimeInterval(-70 * 60), kind: .version, text: "Version bumped 0.0.9 to 0.1.0"),
         LogEvent(date: now.addingTimeInterval(-2 * 3600 - 14 * 60), kind: .session, text: "Session started")]
    }
}

/// One card on the Projects tab.
struct ProjectItem: Codable, Sendable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var version: String
    var lastEdit: Date
    var progress: Double

    static func samples(now: Date) -> [ProjectItem] {
        [ProjectItem(name: "GlassLookStore", version: "0.1.0", lastEdit: now.addingTimeInterval(-600), progress: 0.35),
         ProjectItem(name: "Supplies 221B", version: "34.6.0", lastEdit: now.addingTimeInterval(-2 * 3600), progress: 0.72),
         ProjectItem(name: "Sherlock Sleep", version: "4.0.0", lastEdit: now.addingTimeInterval(-3 * 3600), progress: 0.68)]
    }
}
