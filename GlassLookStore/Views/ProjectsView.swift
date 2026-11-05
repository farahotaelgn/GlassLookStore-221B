import SwiftUI

/// One glass card per project: name, version X.Y.Z, last edit and a small progress ring.
struct ProjectsView: View {
    @Environment(LiveStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Projects")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                ForEach(store.projects) { p in
                    GlassCard(cornerRadius: 38, bevel: 14) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.name).font(.system(size: 17, weight: .bold, design: .rounded))
                                Text("v\(p.version)  ·  edited \(p.lastEdit.formatted(.relative(presentation: .named)))")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            ProgressRing(value: p.progress, accent: settings.accent)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

struct ProgressRing: View {
    let value: Double
    let accent: Color

    var body: some View {
        ZStack {
            Circle().stroke(.primary.opacity(0.12), lineWidth: 6)
            Circle().trim(from: 0, to: max(0, min(1, value)))
                .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(value * 100))%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
        }
        .frame(width: 56, height: 56)
        .accessibilityLabel("Progress \(Int(value * 100)) percent")
    }
}
