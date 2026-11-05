import SwiftUI
import SwiftData
import WidgetKit

@main
struct GlassLookStoreApp: App {
    @State private var store = LiveStore(inMemory: Launch.uiTesting)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(AppSettings.shared)
                .environment(AIGlass.shared)
                .modelContainer(store.manualContainer)
        }
    }
}

/// Launch arguments used by the UI tests (screenshots in light and dark, no Live Activity, no saved files).
enum Launch {
    static var uiTesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }
    static var forceDark: Bool { ProcessInfo.processInfo.arguments.contains("-forceDark") }
    static var forceLight: Bool { ProcessInfo.processInfo.arguments.contains("-forceLight") }
}

struct RootView: View {
    @Environment(LiveStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var tab: AppTab = .live
    @State private var resets: [AppTab: Int] = [:]

    var body: some View {
        ZStack {
            GlassBackground()
            screen
                .id("\(tab.rawValue).\(resets[tab, default: 0])")
                .transition(.opacity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassTabBar(selection: $tab) { again in resets[again, default: 0] += 1 }
        }
        .animation(.snappy(duration: 0.22), value: tab)
        .preferredColorScheme(scheme)
        .task {
            store.start()
            await AIGlass.shared.refresh(dark: colorScheme == .dark)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: store.start()
            case .background: store.stop()
            default: break
            }
        }
        .onChange(of: colorScheme) { _, s in
            Task { await AIGlass.shared.refresh(dark: s == .dark) }
        }
    }

    private var scheme: ColorScheme? {
        if Launch.forceDark { return .dark }
        if Launch.forceLight { return .light }
        return settings.theme.scheme
    }

    @ViewBuilder private var screen: some View {
        switch tab {
        case .live: LiveView()
        case .projects: ProjectsView()
        case .stats: StatsView()
        case .logs: LogsView()
        case .settings: SettingsView()
        }
    }
}

/// The live numbers, the logs and the projects. Updates every second on the main actor while the app is open and
/// pauses in the background.
@MainActor
@Observable
final class LiveStore {
    var snapshot: CounterSnapshot
    var logs: [LogEvent]
    var projects: [ProjectItem]
    var providerName = "Mock"

    let manualContainer: ModelContainer
    @ObservationIgnored let mock: MockProvider
    @ObservationIgnored let manual: ManualProvider
    @ObservationIgnored let github = GitHubProvider()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var ticks = 0
    @ObservationIgnored private var sessionLogged = false
    @ObservationIgnored let inMemory: Bool

    init(inMemory: Bool = false) {
        self.inMemory = inMemory
        let now = Date.now
        mock = MockProvider(now: now)
        manualContainer = ManualProvider.makeContainer(inMemory: inMemory)
        manual = ManualProvider(container: manualContainer)
        snapshot = .placeholder(now: now)
        logs = inMemory ? LogEvent.samples(now: now) : (Self.load([LogEvent].self, Self.logsFile) ?? LogEvent.samples(now: now))
        projects = inMemory ? ProjectItem.samples(now: now) : (Self.load([ProjectItem].self, Self.projectsFile) ?? ProjectItem.samples(now: now))
    }

    var provider: any CounterProvider {
        switch AppSettings.shared.source {
        case .mock: return mock
        case .manual: return manual
        case .github: return github
        }
    }

    var isRunning: Bool { loop != nil }

    func start() {
        guard loop == nil else { return }
        if !sessionLogged {
            sessionLogged = true
            addLog(.session, "Session started")
        }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        SharedSnapshot.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func tick() async {
        let p = provider
        let s = await p.snapshot(now: .now)
        let crossed = snapshot.usageLeft >= 0.2 && s.usageLeft < 0.2
        if s.lastBuildAt != snapshot.lastBuildAt, ticks > 0 {
            addLog(.build, s.lastBuildOK ? "Build passed" : "Build failed")
        }
        snapshot = s
        providerName = p.name
        if crossed {
            Haptics.rigid()
            addLog(.warning, "Usage passed 80 %")
        }
        ticks += 1
        if ticks % 30 == 1 { SharedSnapshot.save(s) }
        if ticks % 300 == 1 { WidgetCenter.shared.reloadAllTimelines() }
        if ticks % 60 == 1 {
            await LiveActivityManager.shared.sync(snapshot: s, enabled: AppSettings.shared.liveActivityOn && !inMemory)
        }
    }

    func addLog(_ kind: LogEvent.Kind, _ text: String) {
        logs.insert(LogEvent(date: .now, kind: kind, text: text), at: 0)
        if logs.count > 500 { logs.removeLast(logs.count - 500) }
        saveLogs()
    }

    func deleteLogs(at offsets: IndexSet) {
        logs.remove(atOffsets: offsets)
        saveLogs()
    }

    private func saveLogs() { if !inMemory { Self.save(logs, Self.logsFile) } }

    // Files on the iPhone only (your data never goes to GitHub, rule 8.10).
    static let logsFile = "GlassLookStoreLogs.json"
    static let projectsFile = "GlassLookStoreProjects.json"

    static func url(_ name: String) -> URL { URL.documentsDirectory.appending(path: name) }

    static func load<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, _ name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url(name), options: .atomic)
    }
}
