import Foundation

/// The default source: realistic numbers that move every second, so the app feels live without any account.
@MainActor
final class MockProvider: CounterProvider {
    let name = "Mock"
    private let start: Date

    init(now: Date = .now) {
        start = now.addingTimeInterval(-(2 * 3600 + 14 * 60))
    }

    private func elapsed(_ now: Date) -> Double { max(0, now.timeIntervalSince(start)) }

    func session(now: Date) -> SessionInfo {
        SessionInfo(start: start, project: "GlassLookStore", status: "Coding, session live")
    }

    func usage(now: Date) -> UsageInfo {
        let e = elapsed(now)
        // A 5 hour window: 78 % left at the start, falling with work, never below 4 %.
        let left = max(0.04, 0.78 - e / (5 * 3600) * 0.62)
        let today = 1 - left
        let week = [0.42, 0.55, 0.48, 0.71, 0.63, 0.82, today]
        let month = (0..<29).map { 0.35 + 0.3 * abs(sin(Double($0) * 0.7)) } + [today]
        return UsageInfo(left: left, resetsAt: start.addingTimeInterval(5 * 3600 + 3600), week: week, month: month)
    }

    func tokens(now: Date) -> Int { 46_000 + Int(elapsed(now) * 0.27) + Int(elapsed(now).truncatingRemainder(dividingBy: 7)) }

    func commits(now: Date) -> CommitInfo {
        let e = elapsed(now)
        return CommitInfo(today: 5 + Int(e / 1800), added: 380 + Int(e / 20), removed: 90 + Int(e / 95))
    }

    func builds(now: Date) -> BuildInfo {
        let e = elapsed(now)
        let last = start.addingTimeInterval((e / 1500).rounded(.down) * 1500)
        return BuildInfo(ok: Int(e / 1500) % 7 != 3, at: last)
    }

    func streak(now: Date) -> Int { 12 }
}
