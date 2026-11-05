import Foundation
import SwiftData

/// The values you type in Settings › Data › Manual values, kept with SwiftData on the iPhone.
@Model
final class ManualValues {
    var projectName: String = "GlassLookStore"
    var sessionStart: Date = Date.now
    var usageLeft: Double = 0.67
    var resetHours: Double = 5
    var tokensToday: Int = 0
    var commitsToday: Int = 0
    var linesAdded: Int = 0
    var linesRemoved: Int = 0
    var lastBuildOK: Bool = true
    var lastBuildAt: Date = Date.now
    var streakDays: Int = 0

    init() {}
}

@MainActor
final class ManualProvider: CounterProvider {
    let name = "Manual"
    /// Kept alive here: a ModelContext whose container is released can crash SwiftData.
    let container: ModelContainer
    let context: ModelContext

    init(container: ModelContainer) {
        self.container = container
        context = container.mainContext
    }

    static func makeContainer(inMemory: Bool) -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        if let c = try? ModelContainer(for: ManualValues.self, configurations: config) { return c }
        // A damaged store never stops the app: fall back to memory (the 🧪 Test reports it).
        let memory = ModelConfiguration(isStoredInMemoryOnly: true)
        do { return try ModelContainer(for: ManualValues.self, configurations: memory) } catch { fatalError("SwiftData unavailable: \(error)") }
    }

    /// The one row of values, made on first use.
    func values() -> ManualValues {
        if let v = try? context.fetch(FetchDescriptor<ManualValues>()).first { return v }
        let v = ManualValues()
        context.insert(v)
        try? context.save()
        return v
    }

    func save() { try? context.save() }

    func session(now: Date) -> SessionInfo {
        let v = values()
        return SessionInfo(start: v.sessionStart, project: v.projectName, status: "Manual values")
    }

    func usage(now: Date) -> UsageInfo {
        let v = values()
        let used = 1 - v.usageLeft
        return UsageInfo(left: v.usageLeft, resetsAt: v.sessionStart.addingTimeInterval(v.resetHours * 3600),
                         week: Array(repeating: used, count: 7), month: Array(repeating: used, count: 30))
    }

    func tokens(now: Date) -> Int { values().tokensToday }
    func commits(now: Date) -> CommitInfo { let v = values(); return CommitInfo(today: v.commitsToday, added: v.linesAdded, removed: v.linesRemoved) }
    func builds(now: Date) -> BuildInfo { let v = values(); return BuildInfo(ok: v.lastBuildOK, at: v.lastBuildAt) }
    func streak(now: Date) -> Int { values().streakDays }
}
