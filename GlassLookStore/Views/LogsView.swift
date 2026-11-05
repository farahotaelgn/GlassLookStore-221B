import SwiftUI

/// A monospaced timeline of events (session started, build passed, version bumped). Swipe to delete.
struct LogsView: View {
    @Environment(LiveStore.self) private var store

    var body: some View {
        List {
            Section {
                ForEach(store.logs) { e in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(e.date.formatted(date: .omitted, time: .standard))
                            .foregroundStyle(.secondary)
                        Image(systemName: e.symbol)
                            .foregroundStyle(e.kind == .warning ? Color.orange : Color.primary)
                        Text(e.text)
                    }
                    .font(.system(.footnote, design: .monospaced))
                    .listRowBackground(Color.clear)
                    .accessibilityElement(children: .combine)
                }
                .onDelete { store.deleteLogs(at: $0) }
            } header: {
                Text("Logs")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .padding(.bottom, 4)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if store.logs.isEmpty {
                ContentUnavailableView("No events yet", systemImage: "terminal", description: Text("Session, build and version events appear here."))
            }
        }
    }
}
