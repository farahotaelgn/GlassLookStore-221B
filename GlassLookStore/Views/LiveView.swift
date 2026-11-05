import SwiftUI

/// The main screen: the hero counter, six live tiles and the 7 day sparkline.
struct LiveView: View {
    @Environment(LiveStore.self) private var store
    @State private var showTest = false

    var body: some View {
        let s = store.snapshot
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text("Live")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Spacer()
                    Button { showTest = true } label: {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .accessibilityLabel("Run the self test")
                    .accessibilityIdentifier("live.test")
                }
                if UpdatesLog.isNewVersion { UpdatedCard() }
                HeroCounterCard(snapshot: s)
                    .containerRelativeFrame(.vertical) { h, _ in h * 0.55 }
                TimelineView(.periodic(from: .now, by: 1)) { clock in
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        StatTile(title: "Tokens today", value: s.tokensToday.formatted())
                        StatTile(title: "Limit resets in", value: CounterSnapshot.countdown(to: s.limitReset, now: clock.date))
                        StatTile(title: "Commits today", value: "\(s.commitsToday)")
                        StatTile(title: "Lines", value: "+\(s.linesAdded) / −\(s.linesRemoved)")
                        StatTile(title: "Last build", value: s.lastBuildAt.formatted(date: .omitted, time: .shortened),
                                 dot: s.lastBuildOK ? .green : .red)
                        StatTile(title: "Streak", value: "\(s.streakDays) days")
                    }
                }
                SparklineCard(values: s.weekUsage)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await store.tick() }
        .sheet(isPresented: $showTest) { NavigationStack { SelfTestView() } }
    }
}

/// "Updated to X" after an update (rule 13.3).
struct UpdatedCard: View {
    @State private var hidden = false

    var body: some View {
        if !hidden, let v = UpdatesLog.versions.first {
            GlassCard(cornerRadius: 28, bevel: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🆕 Updated to \(v.version)").font(.headline)
                        Text(v.title).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("OK") {
                        UpdatesLog.markSeen()
                        withAnimation(.snappy) { hidden = true }
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
}
