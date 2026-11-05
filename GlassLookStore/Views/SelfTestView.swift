import SwiftUI
import SwiftData
import UIKit

/// One check of the 🧪 Test. Dry runs only: no taps, no devices, no vibration (rule 6.4).
struct FeatureCheck: Sendable {
    let id: String
    let name: String
    let run: @MainActor @Sendable () async -> CheckOutcome
}

struct CheckOutcome: Sendable {
    let ok: Bool
    let detail: String
    static func pass(_ d: String = "") -> CheckOutcome { CheckOutcome(ok: true, detail: d) }
    static func fail(_ d: String) -> CheckOutcome { CheckOutcome(ok: false, detail: d) }
    static func check(_ ok: Bool, _ d: String) -> CheckOutcome { CheckOutcome(ok: ok, detail: d) }
}

/// Every feature registers its check here; the Updates Log check refuses a ✨ New change without one.
@MainActor
enum FeatureChecks {
    static func all(store: LiveStore) -> [FeatureCheck] {
        [
            FeatureCheck(id: "bar.layout", name: "Bar sizes and centred tabs (IMG7)") {
                for w in [358.0, 390.0, 402.0] as [CGFloat] {
                    let l = BarLayout(width: w)
                    let leftGap = l.center(0) - l.pillWidth / 2, rightGap = w - (l.center(4) + l.pillWidth / 2)
                    guard abs(leftGap - BarLayout.inset) < 0.01, abs(rightGap - BarLayout.inset) < 0.01 else {
                        return .fail("pill gap \(leftGap) / \(rightGap) at width \(w)")
                    }
                    for i in 0..<5 where l.nearest(l.center(i)) != i { return .fail("tab \(i) does not snap to itself") }
                }
                let ok = BarLayout.height == 62 && BarLayout.lensHeight == 71.5 && BarLayout.zoom == 1.4 && BarLayout.press == 1.035
                return .check(ok, ok ? "62 pt bar, pill 4.3 pt inside each end, tabs centred" : "reference sizes changed")
            },
            FeatureCheck(id: "bar.lens", name: "Lens snap, spring and Reduce Motion") {
                let l = BarLayout(width: 390)
                let mid = (l.center(1) + l.center(2)) / 2 - 1
                guard l.nearest(mid) == 1, l.nearest(-50) == 0, l.nearest(999) == 4 else { return .fail("nearest tab is wrong") }
                let rest = l.indicatorSize(amount: 0, stretch: 0), full = l.indicatorSize(amount: 1, stretch: 0)
                guard abs(rest.width - l.pillWidth) < 0.01, abs(full.height - 71.5) < 0.01 else { return .fail("lens size \(full)") }
                guard BarLayout.springResponse == 0.35, BarLayout.springDamping == 0.7 else { return .fail("spring changed") }
                return .check(BarLayout.zoom(reduceMotion: true) == 1, "snaps, spring 0.35 / 0.7, no zoom with Reduce Motion")
            },
            FeatureCheck(id: "hero.clock", name: "Hero clock and countdown") {
                let now = Date(timeIntervalSince1970: 100_000)
                let a = CounterSnapshot.clock(from: now.addingTimeInterval(-(2 * 3600 + 14 * 60 + 59)), now: now)
                let b = CounterSnapshot.countdown(to: now.addingTimeInterval(3 * 3600 + 41 * 60 + 9), now: now)
                return .check(a == "02:14" && b == "03:41:09", "\(a), \(b)")
            },
            FeatureCheck(id: "provider.mock", name: "Mock numbers move and stay in range") {
                let m = MockProvider(now: .now)
                let a = await m.snapshot(now: .now), b = await m.snapshot(now: .now.addingTimeInterval(60))
                let ok = (0...1).contains(a.usageLeft) && b.tokensToday > a.tokensToday && a.weekUsage.count == 7 && a.monthUsage.count == 30
                return .check(ok, "tokens \(a.tokensToday) → \(b.tokensToday), usage \(Int(a.usageLeft * 100)) %")
            },
            FeatureCheck(id: "provider.manual", name: "Manual values saved with SwiftData") {
                let p = ManualProvider(container: ManualProvider.makeContainer(inMemory: true))
                p.values().tokensToday = 1234
                p.values().usageLeft = 0.42
                p.save()
                let s = await p.snapshot(now: .now)
                return .check(s.tokensToday == 1234 && abs(s.usageLeft - 0.42) < 0.0001, "read back \(s.tokensToday), \(s.usageLeft)")
            },
            FeatureCheck(id: "keychain", name: "Keychain write, read, delete") {
                let key = "selftest.key"
                KeychainStore.save("abcd1234", for: key)
                let back = KeychainStore.read(key)
                KeychainStore.delete(key)
                return .check(back == "abcd1234" && KeychainStore.read(key) == nil && KeychainStore.masked("abcd1234") == "•••• 1234",
                              back == nil ? "Keychain refused the write" : "round trip OK")
            },
            FeatureCheck(id: "widget.snapshot", name: "Widget data in the App Group") {
                guard SharedSnapshot.defaults != nil else { return .fail("App Group not available (the .ipa must keep its entitlement)") }
                let before = SharedSnapshot.load()
                var s = CounterSnapshot.placeholder()
                s.tokensToday = 777
                SharedSnapshot.save(s)
                let ok = SharedSnapshot.load()?.tokensToday == 777
                SharedSnapshot.save(before ?? store.snapshot)
                return .check(ok, ok ? "saved and read back, your data restored" : "read back failed")
            },
            FeatureCheck(id: "liveactivity", name: "Live Activity content encodes") {
                let st = SessionActivityAttributes.ContentState(usageLeft: 0.5, tokens: 10, status: "x", buildOK: true)
                guard let d = try? JSONEncoder().encode(st), let back = try? JSONDecoder().decode(SessionActivityAttributes.ContentState.self, from: d) else {
                    return .fail("encode failed")
                }
                return .check(back == st, LiveActivityManager.shared.statusLine)
            },
            FeatureCheck(id: "haptics", name: "Haptics follow the switch (dry run)") {
                let was = AppSettings.shared.hapticsOn
                Haptics.dryRun = true
                Haptics.clearLog()
                AppSettings.shared.hapticsOn = false
                Haptics.selection()
                let offCount = Haptics.log.count
                AppSettings.shared.hapticsOn = true
                Haptics.selection(); Haptics.light(); Haptics.soft(); Haptics.rigid()
                let onCount = Haptics.log.count
                AppSettings.shared.hapticsOn = was
                Haptics.dryRun = false
                return .check(offCount == 0 && onCount == 4, "off \(offCount), on \(onCount)")
            },
            FeatureCheck(id: "theme.colors", name: "Every colour in light and dark") {
                for name in GlassPalette.names {
                    for style in [UIUserInterfaceStyle.light, .dark] {
                        guard UIColor(named: name)?.resolvedColor(with: UITraitCollection(userInterfaceStyle: style)) != nil else {
                            return .fail("\(name) missing")
                        }
                    }
                }
                let l = UIColor(named: "AccentBlue")?.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
                let d = UIColor(named: "AccentBlue")?.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
                return .check(l != d, "\(GlassPalette.names.count) colour sets, light and dark differ")
            },
            FeatureCheck(id: "card.glass", name: "Shaders are in the app") {
                let lib = Bundle.main.url(forResource: "default", withExtension: "metallib")
                return .check(lib != nil, lib == nil ? "default.metallib missing (GlassLens, LiquidWave)" : "GlassLens and LiquidWave compiled")
            },
            FeatureCheck(id: "ai.glass", name: "AI glass values in range") {
                let a = GlassAdviceValues.iPhoneReading(dark: false), b = GlassAdviceValues.iPhoneReading(dark: true)
                let now = AIGlass.shared.advice
                return .check(a.isValid && b.isValid && now.isValid,
                              "decided by \(now.who); Apple AI \(AIGlass.appleAvailable ? "available" : "not available on this iPhone")")
            },
            FeatureCheck(id: "icons.packs", name: "Icon packs: every tab icon or an SF Symbols fallback") {
                var found = 0, fallback = 0
                for p in IconPacks.all {
                    for tab in AppTab.allCases {
                        if IconPacks.asset(slot: tab.slot, library: p.id) != nil { found += 1 } else { fallback += 1 }
                        guard UIImage(systemName: tab.symbol) != nil else { return .fail("SF Symbol \(tab.symbol) missing") }
                    }
                }
                return .check(found > 0, "\(IconPacks.all.count) packs, \(found) icons, \(fallback) use SF Symbols")
            },
            FeatureCheck(id: "version", name: "Version X.Y.Z matches the Updates Log") {
                let v = Bundle.main.versionString
                let parts = v.split(separator: ".").compactMap { Int($0) }
                let ok = parts.count == 3 && parts[1] <= 9 && parts[2] <= 9 && UpdatesLog.versions.first?.version == v
                return .check(ok, "app \(v), log \(UpdatesLog.versions.first?.version ?? "none")")
            },
            FeatureCheck(id: "updates.checks", name: "Every new feature has a check") {
                let ids = Set(all(store: store).map(\.id))
                let missing = UpdatesLog.versions.flatMap(\.changes).filter { $0.tag == .new && ($0.check.map { !ids.contains($0) } ?? true) }
                return .check(missing.isEmpty, missing.isEmpty ? "all ✨ changes are tested" : "no check: \(missing.map(\.text).joined(separator: "; "))")
            },
            FeatureCheck(id: "settings.persist", name: "Settings survive (rule 14.49)") {
                guard let d = UserDefaults(suiteName: "glasslookstore.selftest") else { return .fail("test settings store unavailable") }
                let a = AppSettings(defaults: d)
                a.wavyCardEdges = true
                a.signature = "Test"
                let b = AppSettings(defaults: d)
                let ok = b.wavyCardEdges && b.signature == "Test"
                d.removePersistentDomain(forName: "glasslookstore.selftest")
                return .check(ok, ok ? "saved and read back" : "lost a setting")
            },
            FeatureCheck(id: "speed", name: "Speed: data and layout under 0.1 s") {
                let t0 = Date.now
                _ = await MockProvider().snapshot(now: .now)
                for w in stride(from: 300.0, to: 440.0, by: 1.0) { _ = BarLayout(width: CGFloat(w)).nearest(150) }
                let ms = Date.now.timeIntervalSince(t0) * 1000
                return .check(ms < 100, String(format: "%.1f ms", ms))
            }
        ]
    }
}

@MainActor
@Observable
final class SelfTestRunner {
    enum State: Equatable { case idle, running, passed, failed, stopped }
    struct Row: Identifiable, Sendable { let id: String; let name: String; let ok: Bool; let detail: String; let ms: Int }

    var state: State = .idle
    var progress = 0.0
    var current = ""
    var rows: [Row] = []
    var log: [String] = []
    @ObservationIgnored private var task: Task<Void, Never>?
    nonisolated static let timeLimit: Double = 3

    func start(store: LiveStore) {
        guard state != .running else { return }
        let checks = FeatureChecks.all(store: store)
        rows = []
        log = []
        progress = 0
        state = .running
        task = Task {
            for (i, c) in checks.enumerated() {
                if Task.isCancelled { state = .stopped; return }
                current = c.name
                let t0 = Date.now
                let outcome = await Self.withTimeLimit(c)
                let ms = Int(Date.now.timeIntervalSince(t0) * 1000)
                rows.append(Row(id: c.id, name: c.name, ok: outcome.ok, detail: outcome.detail, ms: ms))
                log.append("\(outcome.ok ? "✅" : "❌") \(c.id) \(ms) ms \(outcome.detail)")
                if log.count > 50 { log.removeFirst() }
                progress = Double(i + 1) / Double(checks.count)
            }
            current = ""
            state = rows.allSatisfy(\.ok) ? .passed : .failed
            if state == .passed { Haptics.success() } else { Haptics.warning() }
        }
    }

    func stop() {
        task?.cancel()
        state = .stopped
    }

    /// A check that runs longer than the limit is reported ⏱ and the test moves on, never stuck.
    private static func withTimeLimit(_ c: FeatureCheck) async -> CheckOutcome {
        let limit = timeLimit
        return await withTaskGroup(of: CheckOutcome?.self) { group in
            group.addTask { await c.run() }
            group.addTask {
                try? await Task.sleep(for: .seconds(limit))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? .fail("⏱ over \(Int(limit)) s")
        }
    }

    var summary: String {
        let passed = rows.filter(\.ok).count
        let head = "GlassLookStore \(Bundle.main.versionString) (\(Bundle.main.buildString)) 🧪 Test: \(state == .passed ? "✅ Passed" : state == .stopped ? "⛔ Stopped" : "❌ Failed") \(passed)/\(rows.count)"
        let errors = rows.filter { !$0.ok }.map { "❌ \($0.id): \($0.detail)" }
        return ([head] + errors).joined(separator: "\n")
    }

    var forClaude: String {
        let items = rows.map { ["id": $0.id, "ok": $0.ok ? "true" : "false", "ms": "\($0.ms)", "detail": $0.detail] }
        let json = (try? JSONSerialization.data(withJSONObject: ["version": Bundle.main.versionString, "checks": items], options: [.prettyPrinted, .sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let notes = UpdatesLog.versions.prefix(5).map { "\($0.version): \($0.behind)" }.joined(separator: "\n")
        return summary + "\n\nLog (last 50):\n" + log.joined(separator: "\n") + "\n\nBehind the scenes:\n" + notes + "\n\nFOR CLAUDE\n" + json
    }
}

struct SelfTestView: View {
    @Environment(LiveStore.self) private var store
    @State private var runner = SelfTestRunner()
    @State private var copied = false

    var body: some View {
        List {
            Section {
                Text(title)
                    .font(.headline)
                    .accessibilityIdentifier("test.state")
                ProgressView(value: runner.progress) {
                    Text("\(Int(runner.progress * 100)) %  \(runner.current)")
                }
                HStack {
                    Button(runner.state == .running ? "Running…" : "▶︎ Run 🧪 Test") { runner.start(store: store) }
                        .buttonStyle(.glassProminent)
                        .disabled(runner.state == .running)
                        .accessibilityIdentifier("test.run")
                    if runner.state == .running {
                        Button("⛔ Stop") { runner.stop() }.buttonStyle(.glass)
                    }
                }
            }
            if !runner.rows.isEmpty {
                Section("Report") {
                    let passed = runner.rows.filter(\.ok)
                    if !passed.isEmpty { Text("✅ \(passed.count) passed") }
                    ForEach(runner.rows.filter { !$0.ok }) { r in
                        VStack(alignment: .leading) {
                            Text("❌ \(r.name)").font(.subheadline.bold())
                            Text(r.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button(copied ? "Copied" : "📋 Copy for Claude") {
                        UIPasteboard.general.string = runner.forClaude
                        copied = true
                        Haptics.success()
                    }
                }
                Section("Log") {
                    ForEach(Array(runner.log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.caption2, design: .monospaced))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("🧪 Test")
        .onAppear { if ProcessInfo.processInfo.arguments.contains("-autoTest") { runner.start(store: store) } }
    }

    private var title: String {
        switch runner.state {
        case .idle: return "Ready"
        case .running: return "Running"
        case .passed: return "✅ Passed"
        case .failed: return "❌ Failed"
        case .stopped: return "⛔ Stopped"
        }
    }
}
