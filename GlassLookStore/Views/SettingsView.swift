import SwiftUI
import SwiftData

/// Theme, haptics, wave, accent, data source, signature, look switches, AI glass, icon packs, tools and the version.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AIGlass.self) private var ai
    @Environment(LiveStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                if UpdatesLog.isNewVersion {
                    Section { UpdatedCard().listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
                }
                Section("Look") {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(ThemeChoice.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    ColorPicker("Accent colour", selection: Binding(get: { settings.accent }, set: { settings.accentHex = $0.hex }),
                                supportsOpacity: false)
                    if !settings.accentHex.isEmpty {
                        Button("Use the standard blue") { settings.accentHex = "" }
                    }
                    Toggle("Liquid wave", isOn: $settings.waveOn)
                    Toggle("Waving card edges", isOn: $settings.wavyCardEdges)
                    Toggle("Glass bubble at rest", isOn: $settings.glassBubbleAtRest)
                    Toggle("Mirrored tab labels", isOn: $settings.mirroredLabels)
                    NavigationLink { IconPackPicker() } label: {
                        LabeledContent("Icon pack", value: IconPacks.pack(settings.iconLibrary)?.name ?? "SF Symbols")
                    }
                }
                Section {
                    Toggle("Apple AI decides colours, frost and blur", isOn: $settings.aiGlassOn)
                        .onChange(of: settings.aiGlassOn) { _, _ in Task { await ai.refresh(dark: scheme == .dark) } }
                    LabeledContent("Decided by", value: ai.advice.who)
                    LabeledContent("Frost", value: "\(Int(ai.advice.frost * 100)) %")
                    LabeledContent("Blur", value: "\(Int(ai.advice.blur * 100)) %")
                    Button(ai.asking ? "Asking Apple AI…" : "Ask Apple AI now") {
                        Task { await ai.refresh(dark: scheme == .dark) }
                    }
                    .disabled(ai.asking)
                } header: { Text("🤖 AI glass") } footer: { Text(ai.status) }
                Section("Feel") {
                    Toggle("Haptics", isOn: $settings.hapticsOn)
                    Toggle("Live Activity and Dynamic Island", isOn: $settings.liveActivityOn)
                }
                Section {
                    Picker("Data source", selection: $settings.source) {
                        ForEach(DataSource.allCases) { Text($0.title).tag($0) }
                    }
                    if settings.source == .manual {
                        NavigationLink("Manual values") { ManualEditor(provider: store.manual) }
                    }
                    if settings.source == .github {
                        NavigationLink("GitHub key and repo") { GitHubKeyPage(provider: store.github) }
                    }
                    TextField("Signature", text: $settings.signature)
                } header: { Text("Data") } footer: { Text("Now showing: \(store.providerName)") }
                Section("Tools") {
                    NavigationLink { SelfTestView() } label: { Label("🧪 Test", systemImage: "testtube.2") }
                        .accessibilityIdentifier("settings.test")
                    NavigationLink { UpdatesLogView() } label: { Label("📜 Updates Log", systemImage: "clock.arrow.circlepath") }
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.versionString)
                        .accessibilityIdentifier("settings.version")
                    LabeledContent("Build", value: Bundle.main.buildString)
                }
            }
            .scrollContentBackground(.hidden)
            .background(GlassBackground())
            .navigationTitle("Settings")
        }
    }
}

extension Bundle {
    var versionString: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
    var buildString: String { object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }
}

/// Every slider has − and + buttons, one step each, with the value shown (rule 14.57).
struct StepSlider: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(title, value: format(value))
            HStack(spacing: 10) {
                Button { nudge(-step) } label: { Image(systemName: "minus").frame(width: 30, height: 30) }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Less \(title)")
                Slider(value: $value, in: range, step: step)
                Button { nudge(step) } label: { Image(systemName: "plus").frame(width: 30, height: 30) }
                    .buttonStyle(.glass)
                    .accessibilityLabel("More \(title)")
            }
        }
    }

    private func nudge(_ d: Double) {
        value = min(range.upperBound, max(range.lowerBound, value + d))
        Haptics.selection()
    }
}

/// Manual values, saved with SwiftData.
struct ManualEditor: View {
    let provider: ManualProvider
    @State private var usage: Double = 0.67
    @State private var tokens: Int = 0
    @State private var commits: Int = 0
    @State private var added: Int = 0
    @State private var removed: Int = 0
    @State private var streak: Int = 0
    @State private var buildOK = true
    @State private var project = ""

    var body: some View {
        Form {
            TextField("Project name", text: $project)
            StepSlider(title: "Usage left", value: $usage, range: 0...1, step: 0.01) { "\(Int(($0 * 100).rounded())) %" }
            Stepper("Tokens today: \(tokens.formatted())", value: $tokens, in: 0...10_000_000, step: 500)
            Stepper("Commits today: \(commits)", value: $commits, in: 0...999)
            Stepper("Lines added: \(added)", value: $added, in: 0...999_999, step: 10)
            Stepper("Lines removed: \(removed)", value: $removed, in: 0...999_999, step: 10)
            Stepper("Streak: \(streak) days", value: $streak, in: 0...9999)
            Toggle("Last build passed", isOn: $buildOK)
            Button("Start the session now") {
                provider.values().sessionStart = .now
                provider.save()
                Haptics.success()
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Manual values")
        .onAppear {
            let v = provider.values()
            usage = v.usageLeft; tokens = v.tokensToday; commits = v.commitsToday; added = v.linesAdded
            removed = v.linesRemoved; streak = v.streakDays; buildOK = v.lastBuildOK; project = v.projectName
        }
        .onDisappear(perform: write)
        .onChange(of: usage) { _, _ in write() }
    }

    private func write() {
        let v = provider.values()
        if v.lastBuildOK != buildOK { v.lastBuildAt = .now }
        v.usageLeft = usage; v.tokensToday = tokens; v.commitsToday = commits; v.linesAdded = added
        v.linesRemoved = removed; v.streakDays = streak; v.lastBuildOK = buildOK
        v.projectName = project.isEmpty ? "GlassLookStore" : project
        provider.save()
    }
}

/// The GitHub token (Keychain) and repo, with a 🧪 Test and a status (rule 8.13).
struct GitHubKeyPage: View {
    let provider: GitHubProvider
    @State private var token = ""
    @State private var repo = ""
    @State private var testing = false
    @State private var status: GitHubProvider.Status = .notAdded

    var body: some View {
        Form {
            Section {
                TextField("Personal access token", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.footnote, design: .monospaced))
                TextField("Repo (owner/name)", text: $repo)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Save") {
                    if token.isEmpty { KeychainStore.delete(KeychainStore.githubToken) } else { KeychainStore.save(token, for: KeychainStore.githubToken) }
                    UserDefaults.standard.set(repo, forKey: GitHubProvider.repoKey)
                    Haptics.success()
                }
                Button(testing ? "Testing…" : "🧪 Test key") {
                    Task {
                        testing = true
                        await provider.refresh()
                        status = provider.status
                        testing = false
                    }
                }
                .disabled(testing)
            } footer: {
                Text("The token stays in this iPhone's Keychain. Saved: \(KeychainStore.masked(KeychainStore.read(KeychainStore.githubToken)))")
            }
            Section("Status") { Text(statusText) }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("GitHub")
        .onAppear {
            token = KeychainStore.read(KeychainStore.githubToken) ?? ""
            repo = provider.repo
            status = provider.status
        }
    }

    private var statusText: String {
        switch status {
        case .notAdded: return "⚪ Not added"
        case .working: return "🟢 Working"
        case .notWorking(let why): return "🔴 Not working: \(why)"
        }
    }
}

/// Icon packs with a preview and credits; a missing icon falls back to SF Symbols (rule 14.54).
struct IconPackPicker: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        List {
            row(id: IconPacks.sfSymbols, name: "SF Symbols", credit: "Apple")
            ForEach(IconPacks.all) { p in row(id: p.id, name: p.name, credit: p.credit) }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Icon pack")
    }

    private func row(id: String, name: String, credit: String) -> some View {
        Button {
            settings.iconLibrary = id
            Haptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(name).font(.headline)
                    Spacer()
                    if settings.iconLibrary == id { Image(systemName: "checkmark").foregroundStyle(settings.accent) }
                }
                HStack(spacing: 14) {
                    ForEach(AppTab.allCases) { tab in
                        preview(tab, library: id).frame(width: 22, height: 22)
                    }
                }
                Text(credit).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func preview(_ tab: AppTab, library: String) -> some View {
        if let a = IconPacks.asset(slot: tab.slot, library: library) {
            switch a.kind {
            case .template: Image(a.name).renderingMode(.template).resizable().scaledToFit()
            case .original: Image(a.name).renderingMode(.original).resizable().scaledToFit()
            case .symbol: Image(a.name)
            }
        } else {
            Image(systemName: tab.symbol)
        }
    }
}
