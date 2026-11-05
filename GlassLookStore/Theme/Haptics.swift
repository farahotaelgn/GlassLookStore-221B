import UIKit

/// One haptic per moment (rule 11.8). Off when Settings › Haptics is off. The 🧪 Test runs it dry (no vibration).
@MainActor
enum Haptics {
    static var dryRun = false
    private(set) static var log: [String] = []

    /// The lens crosses into a new tab while dragging.
    static func selection() { fire("selection") { UISelectionFeedbackGenerator().selectionChanged() } }
    /// Release and snap after a drag.
    static func light() { fire("light") { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    /// A tap selection.
    static func soft() { fire("soft") { UIImpactFeedbackGenerator(style: .soft).impactOccurred() } }
    /// A counter passes a threshold (usage over 80 %).
    static func rigid() { fire("rigid") { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() } }
    static func success() { fire("success") { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    static func warning() { fire("warning") { UINotificationFeedbackGenerator().notificationOccurred(.warning) } }

    static func clearLog() { log.removeAll() }

    private static func fire(_ name: String, _ body: () -> Void) {
        guard AppSettings.shared.hapticsOn else { return }
        log.append(name)
        if log.count > 50 { log.removeFirst(log.count - 50) }
        if !dryRun { body() }
    }
}
