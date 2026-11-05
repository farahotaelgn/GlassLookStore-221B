import SwiftUI

/// The five tabs.
enum AppTab: Int, CaseIterable, Identifiable, Sendable {
    case live, projects, stats, logs, settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .live: return "Live"
        case .projects: return "Projects"
        case .stats: return "Stats"
        case .logs: return "Logs"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .live: return "gauge.with.dots.needle.67percent"
        case .projects: return "folder"
        case .stats: return "chart.bar"
        case .logs: return "terminal"
        case .settings: return "gearshape"
        }
    }

    /// The icon pack slot (the same slot names as Supplies 221B).
    var slot: String {
        switch self {
        case .live: return "Clock"
        case .projects: return "Folder"
        case .stats: return "Chart"
        case .logs: return "List"
        case .settings: return "Settings"
        }
    }
}

/// Sizes measured from the Walmart bar at rest (IMG7, 3x screenshot) and pressed (IMG6). Pure, checked by the 🧪 Test.
struct BarLayout: Equatable, Sendable {
    static let height: CGFloat = 62
    static let sideMargin: CGFloat = 20
    static let bottomGap: CGFloat = 8
    /// The pill stays 4.3 pt inside each end of the bar and is 7.5 pt wider than the tab spacing.
    static let inset: CGFloat = 4.3
    static let extra: CGFloat = 7.5
    static let lensTabs: CGFloat = 1.3
    static let lensHeight: CGFloat = 71.5
    static let zoom: CGFloat = 1.4
    static let press: CGFloat = 1.035
    static let springResponse: Double = 0.35
    static let springDamping: Double = 0.7

    let width: CGFloat

    var spacing: CGFloat { (width - 2 * Self.inset - Self.extra) / 5 }
    var pillWidth: CGFloat { spacing + Self.extra }
    var pillHeight: CGFloat { Self.height - 9 }
    var firstCenter: CGFloat { Self.inset + pillWidth / 2 }
    var lensWidth: CGFloat { spacing * Self.lensTabs }

    func center(_ i: Int) -> CGFloat { firstCenter + spacing * CGFloat(i) }
    func clamp(_ x: CGFloat) -> CGFloat { min(max(x, center(0)), center(4)) }
    func nearest(_ x: CGFloat) -> Int { max(0, min(4, Int(((x - firstCenter) / spacing).rounded()))) }

    /// The indicator's size for a lens amount (0 = grey pill, 1 = full lens) and a squash and stretch (0...0.08).
    func indicatorSize(amount: CGFloat, stretch: CGFloat) -> CGSize {
        let a = max(0, min(1, amount))
        let w = (pillWidth + (lensWidth - pillWidth) * a) * (1 + stretch)
        let h = (pillHeight + (Self.lensHeight - pillHeight) * a) * (1 - stretch * 0.6)
        return CGSize(width: w, height: h)
    }

    /// Reduce Motion: no magnification and no stretch.
    static func zoom(reduceMotion: Bool) -> CGFloat { reduceMotion ? 1 : zoom }
}

/// The floating Walmart-style bar: grey pill at rest (IMG7); touch and the pill turns into a clear glass lens that
/// magnifies the tabs with IMG1 colour rims and follows your finger (IMG6); release and it springs to the nearest tab.
struct GlassTabBar: View {
    @Binding var selection: AppTab
    var onReselect: (AppTab) -> Void = { _ in }

    @Environment(AppSettings.self) private var settings
    @Environment(AIGlass.self) private var ai
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme

    @State private var dragX: CGFloat?
    @State private var lens: CGFloat = 0
    @State private var stretch: CGFloat = 0
    @State private var pressing = false
    @State private var dragging = false
    @State private var hover: AppTab?
    @State private var lastX: CGFloat = 0
    @State private var lastTime = Date.now

    private var spring: Animation { .spring(response: BarLayout.springResponse, dampingFraction: BarLayout.springDamping) }

    var body: some View {
        GeometryReader { geo in
            let lay = BarLayout(width: geo.size.width)
            let x = dragX ?? lay.center(selection.rawValue)
            let lit = hover ?? selection
            let size = lay.indicatorSize(amount: lens, stretch: stretch)
            let mid = BarLayout.height / 2
            ZStack {
                barBody
                Capsule()
                    .fill(GlassPalette.pill)
                    .frame(width: lay.pillWidth, height: lay.pillHeight)
                    .position(x: x, y: mid)
                    .opacity(Double(max(0, 1 - lens * 1.6)))
                TabRow(layout: lay, lit: lit, accent: settings.accent, mirrored: settings.mirroredLabels, allLit: false)
                    .clipShape(Capsule())
                    .mask {
                        Rectangle()
                            .overlay {
                                if lens > 0.02 {
                                    Capsule().frame(width: size.width, height: size.height).position(x: x, y: mid).blendMode(.destinationOut)
                                }
                            }
                            .compositingGroup()
                    }
                if lens > 0.02 {
                    GlassLensDroplet(layout: lay, x: x, size: size, amount: lens, lit: lit, accent: settings.accent,
                                     zoom: BarLayout.zoom(reduceMotion: reduceMotion), reduceTransparency: reduceTransparency)
                }
            }
            .frame(width: geo.size.width, height: BarLayout.height)
            .scaleEffect(pressing ? BarLayout.press : 1)
            .contentShape(Capsule())
            .gesture(drag(lay))
            .overlay { accessibilityTabs(lay) }
        }
        .frame(height: BarLayout.height)
        .padding(.horizontal, BarLayout.sideMargin)
        .padding(.bottom, BarLayout.bottomGap)
        .onAppear { if settings.glassBubbleAtRest { lens = 1 } }
        .onChange(of: settings.glassBubbleAtRest) { _, on in withAnimation(spring) { lens = on ? 1 : 0 } }
    }

    private var barBody: some View {
        Group {
            if reduceTransparency {
                Capsule().fill(Color(.secondarySystemBackground))
            } else {
                GlassEffectContainer {
                    Capsule()
                        .fill(ai.advice.tint)
                        .glassEffect(ai.advice.blur > 0.5 ? .regular : .clear, in: Capsule())
                }
            }
        }
        .overlay(Capsule().strokeBorder(GlassPalette.hairline, lineWidth: 0.5))
        .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .clear, .white.opacity(0.18)],
                                                        startPoint: .top, endPoint: .bottom), lineWidth: 1).padding(0.5))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    /// VoiceOver and UI tests: one button per tab, drawn over the bar, invisible.
    private func accessibilityTabs(_ lay: BarLayout) -> some View {
        ZStack {
            ForEach(AppTab.allCases) { tab in
                Color.clear
                    .frame(width: lay.spacing, height: BarLayout.height)
                    .position(x: lay.center(tab.rawValue), y: BarLayout.height / 2)
                    .accessibilityElement()
                    .accessibilityLabel(tab.title)
                    .accessibilityIdentifier("tab.\(tab.title)")
                    .accessibilityValue(tab == selection ? "selected" : "")
                    .accessibilityAddTraits(tab == selection ? [.isButton, .isSelected] : .isButton)
                    .accessibilityAction { choose(tab, lay: lay, dragged: false) }
                    .allowsHitTesting(false)
            }
        }
    }

    private func drag(_ lay: BarLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                if !pressing {
                    lastX = lay.center(selection.rawValue)
                    lastTime = v.time
                    withAnimation(.snappy(duration: 0.18)) { pressing = true; lens = 1 }
                }
                guard dragging || abs(v.translation.width) > 6 else { return }
                dragging = true
                let nx = lay.clamp(v.location.x)
                let dt = max(0.001, v.time.timeIntervalSince(lastTime))
                let speed = (nx - lastX) / dt
                lastX = nx
                lastTime = v.time
                stretch = reduceMotion ? 0 : min(0.08, abs(speed) / 3000)
                dragX = nx
                let n = AppTab(rawValue: lay.nearest(nx)) ?? selection
                if n != hover {
                    hover = n
                    Haptics.selection()
                }
            }
            .onEnded { v in
                let target: AppTab
                if dragging {
                    target = AppTab(rawValue: lay.nearest(dragX ?? lay.center(selection.rawValue))) ?? selection
                } else {
                    target = AppTab(rawValue: lay.nearest(lay.clamp(v.location.x))) ?? selection
                }
                choose(target, lay: lay, dragged: dragging)
            }
    }

    /// Lands on a tab: the lens springs to its centre (measured on the bar at rest, so it always lands centred),
    /// then shrinks into the grey pill while its glass fades (Walmart).
    private func choose(_ target: AppTab, lay: BarLayout, dragged: Bool) {
        if dragged { Haptics.light() } else { Haptics.soft() }
        if target == selection && !dragged { onReselect(target) }
        selection = target
        withAnimation(spring) {
            dragX = nil
            stretch = 0
            pressing = false
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78).delay(dragged ? 0.12 : 0.25)) {
            lens = settings.glassBubbleAtRest ? 1 : 0
        }
        dragging = false
        hover = nil
    }
}

/// The five icons and labels, each centred on its tab, with the label mirrored in the bottom bevel (IMG3).
struct TabRow: View {
    let layout: BarLayout
    let lit: AppTab
    let accent: Color
    let mirrored: Bool
    /// The magnified copy inside the lens shows every tab in the accent colour (IMG6).
    let allLit: Bool

    var body: some View {
        ZStack {
            ForEach(AppTab.allCases) { tab in
                let on = allLit || tab == lit
                VStack(spacing: 3) {
                    TabIcon(tab: tab, filled: tab == lit)
                        .frame(width: 22, height: 22)
                    Text(tab.title)
                        .font(.system(size: 12, weight: tab == lit ? .semibold : .regular, design: .rounded))
                        .lineLimit(1)
                        .fixedSize()
                        .overlay(alignment: .top) {
                            if mirrored {
                                Text(tab.title)
                                    .font(.system(size: 12, weight: tab == lit ? .semibold : .regular, design: .rounded))
                                    .fixedSize()
                                    .scaleEffect(x: 1, y: -1)
                                    .opacity(0.22)
                                    .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                                    .offset(y: 14)
                                    .accessibilityHidden(true)
                            }
                        }
                }
                .foregroundStyle(on ? accent : Color.primary)
                .position(x: layout.center(tab.rawValue), y: BarLayout.height / 2 - 1)
                .accessibilityHidden(true)
            }
        }
        .frame(width: layout.width, height: BarLayout.height)
    }
}

/// One tab icon from the chosen icon pack; a slot the pack lacks falls back to SF Symbols.
struct TabIcon: View {
    let tab: AppTab
    let filled: Bool
    @Environment(AppSettings.self) private var settings

    var body: some View {
        if let a = IconPacks.asset(slot: tab.slot, library: settings.iconLibrary) {
            switch a.kind {
            case .template: Image(a.name).renderingMode(.template).resizable().scaledToFit()
            case .original: Image(a.name).renderingMode(.original).resizable().scaledToFit()
            case .symbol: Image(a.name).font(.system(size: 19))
            }
        } else {
            Image(systemName: tab.symbol)
                .symbolVariant(filled ? .fill : .none)
                .font(.system(size: 19, weight: .regular))
        }
    }
}
