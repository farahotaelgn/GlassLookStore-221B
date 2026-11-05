import SwiftUI

/// 📜 Updates Log (rule 13.3): versions newest first under day headers with tag counts, filter chips, each version's
/// page with every change and ✅ Works / ❌ Something's wrong. Full detail lives in CHANGELOG.md and DEBUGLOG.md.
struct UpdateEntry: Identifiable, Sendable {
    enum Tag: String, CaseIterable, Sendable {
        case new = "✨", fix = "🛠", speed = "⚡", test = "🧪"
        var name: String {
            switch self {
            case .new: return "New"
            case .fix: return "Fix"
            case .speed: return "Speed"
            case .test: return "Test"
            }
        }
    }

    struct Change: Identifiable, Sendable {
        let id = UUID()
        let tag: Tag
        let text: String
        /// Every ✨ New change names the 🧪 check that tests it (rule 6.4).
        let check: String?
    }

    var id: String { version }
    let version: String
    let date: String
    let title: String
    let changes: [Change]
    let behind: String
}

enum UpdatesLog {
    static func c(_ tag: UpdateEntry.Tag, _ text: String, check: String? = nil) -> UpdateEntry.Change {
        UpdateEntry.Change(tag: tag, text: text, check: check)
    }

    static let versions: [UpdateEntry] = [
        UpdateEntry(version: "0.1.0", date: "2026-11-05 18:00", title: "The first glass", changes: [
            c(.new, "Walmart-style tab bar: grey pill at rest, a clear glass lens while you press or drag, springs to the nearest tab", check: "bar.layout"),
            c(.new, "The lens magnifies the tabs 1.4x with IMG1 colour rims and stretches with your speed", check: "bar.lens"),
            c(.new, "Hero counter: session time HH:MM in huge thin numerals under a slow liquid wave", check: "hero.clock"),
            c(.new, "Six live tiles, a 7 day sparkline, Projects, Stats and Logs", check: "provider.mock"),
            c(.new, "Cards in thick clear glass with straight edges, a deep IMG1 rim and moving light", check: "card.glass"),
            c(.new, "Apple AI decides colours, frost and blur; the iPhone reading only until it answers", check: "ai.glass"),
            c(.new, "Data from Mock, Manual (SwiftData) or GitHub (token in the Keychain)", check: "provider.manual"),
            c(.new, "Home Screen and Lock Screen widgets, Live Activity and Dynamic Island", check: "widget.snapshot"),
            c(.new, "Icon packs from Supplies 221B, SF Symbols by default", check: "icons.packs"),
            c(.test, "🧪 Test on the Live screen and in Settings, with Copy for Claude")
        ], behind: "New app. Built from the approved web preview (build 16). Never compiled before its first Codemagic run.")
    ]

    static let seenKey = "updates.seen"
    static var isNewVersion: Bool { UserDefaults.standard.string(forKey: seenKey) != versions.first?.version }
    static func markSeen() { UserDefaults.standard.set(versions.first?.version, forKey: seenKey) }

    static func feedback(_ version: String) -> Bool? { UserDefaults.standard.object(forKey: "updates.works.\(version)") as? Bool }
    static func setFeedback(_ version: String, works: Bool) { UserDefaults.standard.set(works, forKey: "updates.works.\(version)") }
}

struct UpdatesLogView: View {
    @State private var filter: UpdateEntry.Tag?

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        chip(nil, "All")
                        ForEach(UpdateEntry.Tag.allCases, id: \.self) { chip($0, "\($0.rawValue) \($0.name)") }
                    }
                }
                .scrollIndicators(.hidden)
                .listRowBackground(Color.clear)
            }
            ForEach(days, id: \.self) { day in
                Section(day) {
                    ForEach(UpdatesLog.versions.filter { $0.date.hasPrefix(day) }) { v in
                        NavigationLink { UpdateDetail(entry: v) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(v.version).font(.headline)
                                    if v.version == UpdatesLog.versions.first?.version { Text("🆕") }
                                    Spacer()
                                    Text(status(v))
                                }
                                Text(v.title).font(.subheadline).foregroundStyle(.secondary)
                                Text(counts(v)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Updates Log")
    }

    private var days: [String] {
        var seen: [String] = []
        for v in UpdatesLog.versions where filter == nil || v.changes.contains(where: { $0.tag == filter }) {
            let d = String(v.date.prefix(10))
            if !seen.contains(d) { seen.append(d) }
        }
        return seen
    }

    private func counts(_ v: UpdateEntry) -> String {
        UpdateEntry.Tag.allCases.compactMap { t in
            let n = v.changes.filter { $0.tag == t }.count
            return n > 0 ? "\(t.rawValue) \(n)" : nil
        }.joined(separator: "  ")
    }

    private func status(_ v: UpdateEntry) -> String {
        switch UpdatesLog.feedback(v.version) {
        case .some(true): return "✅"
        case .some(false): return "❌"
        case .none: return "⏳"
        }
    }

    private func chip(_ tag: UpdateEntry.Tag?, _ title: String) -> some View {
        Button(title) {
            filter = tag
            Haptics.selection()
        }
        .buttonStyle(.glass)
        .tint(filter == tag ? Color.accentColor : nil)
    }
}

struct UpdateDetail: View {
    let entry: UpdateEntry
    @State private var works: Bool?

    var body: some View {
        List {
            Section(entry.date) {
                ForEach(entry.changes) { c in
                    Text("\(c.tag.rawValue) \(c.text)")
                }
            }
            Section("Behind the scenes") { Text(entry.behind).font(.footnote) }
            Section {
                HStack {
                    Button("✅ Works") { set(true) }.buttonStyle(.glass)
                    Spacer()
                    Button("❌ Something's wrong") { set(false) }.buttonStyle(.glass)
                }
            } footer: {
                if let works { Text(works ? "Thanks, marked as working." : "Marked as something's wrong. Tell Claude what you saw.") }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(entry.version)
        .onAppear { works = UpdatesLog.feedback(entry.version) }
    }

    private func set(_ ok: Bool) {
        UpdatesLog.setFeedback(entry.version, works: ok)
        works = ok
        if ok { Haptics.success() } else { Haptics.warning() }
    }
}
