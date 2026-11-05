import SwiftUI
import UIKit
#if !WIDGET_EXTENSION && canImport(FoundationModels)
import FoundationModels
#endif

// Shared by the app and the widget extension: colours, settings, the Apple AI glass and the icon packs.

// MARK: - Colours (asset catalog colour sets, each with a light and a dark value)

enum GlassPalette {
    static let accent = Color("AccentBlue")
    static let backgroundTop = Color("BackgroundTop")
    static let backgroundMid = Color("BackgroundMid")
    static let backgroundBottom = Color("BackgroundBottom")
    static let pill = Color("PillGrey")
    static let hairline = Color("HairlineGrey")
    static let glow = Color("TextGlow")
    /// Every colour set, checked by the 🧪 Test in light and dark.
    static let names = ["AccentBlue", "BackgroundTop", "BackgroundMid", "BackgroundBottom", "PillGrey", "HairlineGrey", "TextGlow", "LaunchBackground"]
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Settings (kept in UserDefaults, never reset by an update, rule 14.49)

enum ThemeChoice: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum DataSource: String, CaseIterable, Identifiable, Sendable {
    case mock, manual, github
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mock: return "Mock (live demo)"
        case .manual: return "Manual values"
        case .github: return "GitHub"
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()
    @ObservationIgnored private let d: UserDefaults

    var theme: ThemeChoice { didSet { d.set(theme.rawValue, forKey: "theme") } }
    var hapticsOn: Bool { didSet { d.set(hapticsOn, forKey: "haptics.on") } }
    var waveOn: Bool { didSet { d.set(waveOn, forKey: "wave.on") } }
    var accentHex: String { didSet { d.set(accentHex, forKey: "accent.hex") } }
    var source: DataSource { didSet { d.set(source.rawValue, forKey: "data.source") } }
    var signature: String { didSet { d.set(signature, forKey: "signature") } }
    /// Owner (preview build 12): Walmart lands on the grey pill; the bubble at rest stays as a choice.
    var glassBubbleAtRest: Bool { didSet { d.set(glassBubbleAtRest, forKey: "bar.bubbleAtRest") } }
    var mirroredLabels: Bool { didSet { d.set(mirroredLabels, forKey: "bar.mirrored") } }
    /// Owner (preview build 15): cards keep straight edges; the wave stays as a choice.
    var wavyCardEdges: Bool { didSet { d.set(wavyCardEdges, forKey: "card.wavy") } }
    var iconLibrary: String { didSet { d.set(iconLibrary, forKey: "icon.library") } }
    var liveActivityOn: Bool { didSet { d.set(liveActivityOn, forKey: "live.activity") } }
    /// Owner: "Everything when it comes to colors frost blur using apple Ai".
    var aiGlassOn: Bool { didSet { d.set(aiGlassOn, forKey: "ai.glass") } }

    init(defaults: UserDefaults = .standard) {
        d = defaults
        func flag(_ k: String, _ v: Bool) -> Bool { defaults.object(forKey: k) as? Bool ?? v }
        theme = ThemeChoice(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system
        hapticsOn = flag("haptics.on", true)
        waveOn = flag("wave.on", true)
        accentHex = defaults.string(forKey: "accent.hex") ?? ""
        source = DataSource(rawValue: defaults.string(forKey: "data.source") ?? "") ?? .mock
        signature = defaults.string(forKey: "signature") ?? "Fady"
        glassBubbleAtRest = flag("bar.bubbleAtRest", false)
        mirroredLabels = flag("bar.mirrored", true)
        wavyCardEdges = flag("card.wavy", false)
        iconLibrary = defaults.string(forKey: "icon.library") ?? IconPacks.sfSymbols
        liveActivityOn = flag("live.activity", true)
        aiGlassOn = flag("ai.glass", true)
    }

    /// Your accent, or the asset accent (#2F5BEA light, a lighter blue dark).
    var accent: Color { accentHex.isEmpty ? GlassPalette.accent : (Color(hex: accentHex) ?? GlassPalette.accent) }
}

// MARK: - 🍎 AI glass: Apple AI decides colours, frost and blur

/// What the glass looks like right now. Apple AI fills it; the iPhone reading is used only until or unless it answers.
struct GlassAdviceValues: Sendable, Equatable {
    /// White (light) or black (dark) frost under content, 0...0.6.
    var frost: Double
    /// 0 clear glass ... 1 regular (blurred) glass.
    var blur: Double
    /// Tint hue in degrees and its strength 0...0.3.
    var tintHue: Double
    var tintStrength: Double
    /// Colours of the moving light inside cards.
    var lightHues: [Double]
    var who: String

    static func iPhoneReading(dark: Bool) -> GlassAdviceValues {
        dark ? GlassAdviceValues(frost: 0.22, blur: 0.35, tintHue: 228, tintStrength: 0.10, lightHues: [350, 215, 265], who: "iPhone reading")
             : GlassAdviceValues(frost: 0.30, blur: 0.55, tintHue: 220, tintStrength: 0.05, lightHues: [0, 220, 200], who: "iPhone reading")
    }

    var tint: Color { Color(hue: tintHue / 360, saturation: 0.55, brightness: 0.9).opacity(tintStrength) }

    func lightColors(dark: Bool) -> [Color] {
        lightHues.map { Color(hue: $0 / 360, saturation: dark ? 0.75 : 0.10, brightness: dark ? 0.95 : 1).opacity(dark ? 0.55 : 0.85) }
    }

    /// Pure: every value inside its range (the 🧪 Test checks it).
    var isValid: Bool {
        (0...0.6).contains(frost) && (0...1).contains(blur) && (0...360).contains(tintHue) && (0...0.3).contains(tintStrength)
            && !lightHues.isEmpty && lightHues.allSatisfy { (0...360).contains($0) }
    }
}

#if !WIDGET_EXTENSION && canImport(FoundationModels)
@Generable
struct GlassAdvice {
    @Guide(description: "Frost under cards and text so every text reads at 4.5:1, 0 to 60 percent", .range(0...60))
    var frost: Int
    @Guide(description: "Glass blur, 0 clear glass to 100 fully frosted glass", .range(0...100))
    var blur: Int
    @Guide(description: "Hue in degrees of a soft tint on the glass that suits the background", .range(0...360))
    var tintHue: Int
    @Guide(description: "Strength of that tint, 0 to 30 percent", .range(0...30))
    var tintStrength: Int
    @Guide(description: "Three hues in degrees for the slow moving light inside the cards", .count(3))
    var lightHues: [Int]
}
#endif

@MainActor
@Observable
final class AIGlass {
    static let shared = AIGlass()
    var advice = GlassAdviceValues.iPhoneReading(dark: false)
    var status = "Not asked yet"
    var asking = false

    /// Asks Apple AI on the iPhone (never the web). Falls back to the iPhone reading when Apple AI is off or missing.
    func refresh(dark: Bool) async {
        let reading = GlassAdviceValues.iPhoneReading(dark: dark)
        guard AppSettings.shared.aiGlassOn else { advice = reading; status = "AI glass is off: iPhone reading"; return }
        if advice.who != "🍎 Apple AI" { advice = reading }
        asking = true
        defer { asking = false }
        if let a = await Self.askApple(dark: dark) {
            advice = a
            status = "🍎 Apple AI decided"
        } else {
            advice = reading
            status = Self.appleAvailable ? "Apple AI did not answer: iPhone reading" : "Apple AI not available on this iPhone: iPhone reading"
        }
    }

    nonisolated static var appleAvailable: Bool {
        #if !WIDGET_EXTENSION && canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    nonisolated static func askApple(dark: Bool) async -> GlassAdviceValues? {
        #if !WIDGET_EXTENSION && canImport(FoundationModels)
        guard appleAvailable else { return nil }
        let instructions = """
        You choose the glass look of an iPhone app. Cards and a tab bar are clear Liquid Glass over a background gradient. \
        Pick the frost under text so all text reads at 4.5:1, the glass blur, a soft tint that suits the background, and \
        three hues for a slow moving light inside the cards. Prefer the least frost that keeps text readable.
        """
        let background = dark ? "deep navy (#1D2350) to wine red (#7A2C4D) to blue (#2A63C9), white text"
                              : "soft silver (#F2F3F5) to grey (#C3C6CC) to light grey (#E7E8EB), near black text"
        let session = LanguageModelSession(instructions: instructions)
        let prompt = "Mode: \(dark ? "dark" : "light"). Background: \(background). Accent blue #2F5BEA."
        guard let r = try? await session.respond(to: prompt, generating: GlassAdvice.self, options: GenerationOptions(temperature: 0.1)) else { return nil }
        let g = r.content
        let hues = g.lightHues.prefix(3).map { Double(max(0, min(360, $0))) }
        let v = GlassAdviceValues(frost: Double(max(0, min(60, g.frost))) / 100, blur: Double(max(0, min(100, g.blur))) / 100,
                                  tintHue: Double(max(0, min(360, g.tintHue))), tintStrength: Double(max(0, min(30, g.tintStrength))) / 100,
                                  lightHues: hues.isEmpty ? GlassAdviceValues.iPhoneReading(dark: dark).lightHues : Array(hues), who: "🍎 Apple AI")
        return v.isValid ? v : nil
        #else
        return nil
        #endif
    }
}

// MARK: - 💠 Icon packs (rule 14.54, the same free libraries as Supplies 221B; SF Symbols stays the default)

struct IconPack: Identifiable, Sendable {
    enum Kind: Sendable { case template, original, symbol }
    let id: String
    let name: String
    let prefix: String
    let kind: Kind
    let credit: String
}

enum IconPacks {
    static let sfSymbols = "sf"

    static let all: [IconPack] = [
        IconPack(id: "phosphor", name: "Phosphor", prefix: "Ph", kind: .template, credit: "Phosphor Icons · MIT · phosphoricons.com"),
        IconPack(id: "remix", name: "Remix Icon", prefix: "Rx", kind: .template, credit: "Remix Icon · Apache 2.0 · remixicon.com"),
        IconPack(id: "lucide", name: "Open Symbols · Lucide", prefix: "Os", kind: .symbol, credit: "Open Symbols (OrchardKit, MIT) · Lucide · ISC"),
        IconPack(id: "mingcute", name: "MingCute", prefix: "Mc", kind: .template, credit: "MingCute Icon · Apache 2.0"),
        IconPack(id: "ionicons", name: "Ionicons", prefix: "Io", kind: .template, credit: "Ionicons · MIT"),
        IconPack(id: "fluent", name: "Fluent System", prefix: "Fl", kind: .template, credit: "Fluent UI System Icons (Microsoft) · MIT"),
        IconPack(id: "heroicons", name: "Heroicons", prefix: "He", kind: .template, credit: "Heroicons (Tailwind Labs) · MIT"),
        IconPack(id: "iconoir", name: "Iconoir", prefix: "Ic", kind: .template, credit: "Iconoir · MIT"),
        IconPack(id: "material", name: "Material Symbols Rounded", prefix: "Ms", kind: .template, credit: "Material Symbols (Google) · Apache 2.0"),
        IconPack(id: "hugeicons", name: "Hugeicons", prefix: "Hu", kind: .template, credit: "Hugeicons Free · MIT"),
        IconPack(id: "fluentcolor", name: "Fluent Emoji Colour", prefix: "Fc", kind: .original, credit: "Fluent Emoji Color (Microsoft) · MIT"),
        IconPack(id: "fluentflat", name: "Fluent Emoji Flat", prefix: "Ff", kind: .original, credit: "Fluent Emoji Flat (Microsoft) · MIT"),
        IconPack(id: "flatcolor", name: "Flat Color Icons", prefix: "Fi", kind: .original, credit: "Flat Color Icons (Icons8) · MIT"),
        IconPack(id: "fluentemoji", name: "Fluent Emoji 3D", prefix: "Fx", kind: .original, credit: "Fluent Emoji 3D (Microsoft) · MIT"),
        IconPack(id: "fluenthc", name: "Fluent Emoji High Contrast", prefix: "Fh", kind: .template, credit: "Fluent Emoji High Contrast (Microsoft) · MIT"),
        IconPack(id: "phosphorduo", name: "Phosphor Duotone", prefix: "Pd", kind: .template, credit: "Phosphor Icons Duotone · MIT"),
        IconPack(id: "solar", name: "Solar Duotone", prefix: "So", kind: .template, credit: "Solar Icons by 480 Design · CC BY 4.0")
    ]

    /// Phosphor's own asset names for the tab slots.
    static let phosphor = ["Clock": "Ph-Clock", "Folder": "Ph-Folder", "List": "Ph-List-Bullets", "Settings": "Ph-Gear-Six"]

    static func pack(_ id: String) -> IconPack? { all.first { $0.id == id } }

    /// Pure name: the asset a pack would use for a slot (nil for SF Symbols).
    static func assetName(slot: String, library: String) -> String? {
        guard library != sfSymbols, let p = pack(library) else { return nil }
        return p.id == "phosphor" ? phosphor[slot] : p.prefix + "-" + slot
    }

    /// The asset to draw, or nil = SF Symbols (the default, or a slot this pack does not have).
    static func asset(slot: String, library: String) -> (name: String, kind: IconPack.Kind)? {
        guard let name = assetName(slot: slot, library: library), let p = pack(library), UIImage(named: name) != nil else { return nil }
        return (name, p.kind)
    }
}

// MARK: - Background and moving light

/// The page background: soft silver (IMG2, IMG4) in light mode, navy to red (IMG5) in dark mode.
struct GlassBackground: View {
    var body: some View {
        LinearGradient(colors: [GlassPalette.backgroundTop, GlassPalette.backgroundMid, GlassPalette.backgroundBottom],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

/// The slow light that drifts inside the glass (owner: "I love the moving light"). Colours come from AI glass.
struct MovingLight: View {
    var colors: [Color]
    var speed: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * speed
            Canvas { ctx, size in
                let n = max(1, colors.count)
                for (i, c) in colors.enumerated() {
                    let ph = t * 0.45 + Double(i) * 2.1
                    let fx = 0.2 + 0.6 * Double(i) / Double(max(1, n - 1)) + 0.18 * sin(ph)
                    let fy = 0.25 + 0.5 * Double((i * 7) % n) / Double(n) + 0.12 * cos(ph * 1.2)
                    let center = CGPoint(x: size.width * fx, y: size.height * fy)
                    let r = max(size.width, size.height) * 0.55
                    ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)),
                             with: .radialGradient(Gradient(colors: [c, c.opacity(0)]), center: center, startRadius: 0, endRadius: r))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// The thick clear bevel of every glass object: a bright inner stroke, a white streak top left, a soft shade bottom
/// right (the colour fringe and the IMG1 smear come from the GlassLens shader).
struct BevelRim: View {
    var cornerRadius: CGFloat
    var bevel: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.05), .black.opacity(0.14)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: bevel)
                .blur(radius: bevel * 0.35)
                .clipShape(shape)
            shape.strokeBorder(.white.opacity(0.6), lineWidth: 0.75)
        }
        .allowsHitTesting(false)
    }
}
