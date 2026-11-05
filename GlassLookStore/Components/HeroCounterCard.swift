import SwiftUI

/// The hero card (IMG2 light, IMG5 dark): the session timer HH:MM in huge ultra-thin numerals that bend under a slow
/// liquid wave, date, project and status above, the usage bar bottom left and your signature bottom right.
struct HeroCounterCard: View {
    let snapshot: CounterSnapshot
    @Environment(AppSettings.self) private var settings
    @Environment(AIGlass.self) private var ai
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var editing = false
    @State private var draft = ""

    private let radius: CGFloat = 42
    private let bevel: CGFloat = 18

    var body: some View {
        let dark = scheme == .dark
        let wave = settings.waveOn && !reduceMotion
        TimelineView(.periodic(from: .now, by: 1)) { clock in
            let hhmm = CounterSnapshot.clock(from: snapshot.sessionStart, now: clock.date)
            ZStack {
                backdrop(dark: dark, wave: wave)
                VStack(spacing: 0) {
                    header(now: clock.date)
                    Spacer(minLength: 0)
                    numerals(hhmm, wave: wave, dark: dark)
                    Spacer(minLength: 0)
                    footer
                }
                .padding(.horizontal, bevel + 8)
                .padding(.vertical, bevel + 6)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(BevelRim(cornerRadius: radius, bevel: bevel))
            .shadow(color: .black.opacity(0.12), radius: 30, y: 12)
            .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Session time \(hhmm.replacingOccurrences(of: ":", with: " hours ")) minutes, \(snapshot.projectName)")
        }
        .alert("Signature", isPresented: $editing) {
            TextField("Your signature", text: $draft)
            Button("Save") { settings.signature = String(draft.prefix(24)) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func backdrop(dark: Bool, wave: Bool) -> some View {
        let colors: [Color] = dark ? [Color(red: 0.89, green: 0.23, blue: 0.31), Color(red: 0.73, green: 0.25, blue: 0.37), Color(red: 0.30, green: 0.44, blue: 0.86), Color(red: 0.18, green: 0.56, blue: 0.90)]
                                   : [Color(red: 0.965, green: 0.969, blue: 0.976), Color(red: 0.714, green: 0.725, blue: 0.753), Color(red: 0.933, green: 0.941, blue: 0.949), Color(red: 0.604, green: 0.620, blue: 0.655)]
        let r = Float(radius), b = Float(bevel)
        return ZStack {
            if reduceTransparency {
                Color(.secondarySystemBackground)
            } else {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                MovingLight(colors: dark ? [Color.pink.opacity(0.55), Color.cyan.opacity(0.5), Color.white.opacity(0.2)]
                                         : [Color.white.opacity(0.95), Color.gray.opacity(0.55), Color.white.opacity(0.8)], speed: 0.8)
                    .modifier(LiquidWaveEffect(on: wave, amplitude: 14))
                Rectangle().fill(ai.advice.tint)
            }
        }
        .visualEffect { content, proxy in
            content.layerEffect(ShaderLibrary.glassLens(.float4(0, 0, Float(proxy.size.width), Float(proxy.size.height)),
                                                        .float(r), .float(b), .float(2.4), .float(0.7), .float(1)),
                                maxSampleOffset: CGSize(width: CGFloat(b) + 6, height: CGFloat(b) + 6))
        }
    }

    private func header(now: Date) -> some View {
        VStack(spacing: 2) {
            Text("\(now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))  ·  \(snapshot.projectName)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Text(snapshot.status)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.18), radius: 2)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func numerals(_ hhmm: String, wave: Bool, dark: Bool) -> some View {
        Text(hhmm)
            .font(.system(size: 140, weight: .ultraLight).width(.condensed))
            .monospacedDigit()
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .foregroundStyle(.white.opacity(0.92))
            .shadow(color: dark ? GlassPalette.glow : .black.opacity(0.25), radius: dark ? 14 : 1)
            .contentTransition(.numericText())
            .animation(.snappy, value: hhmm)
            .modifier(LiquidWaveEffect(on: wave, amplitude: 5))
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            UsageBar(left: snapshot.usageLeft)
            Spacer(minLength: 8)
            Button {
                draft = settings.signature
                editing = true
            } label: {
                Text(settings.signature.isEmpty ? "sign" : settings.signature)
                    .font(.custom("SnellRoundhand", size: 34, relativeTo: .title))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.25), radius: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Signature \(settings.signature), edit")
        }
    }
}

/// The IMG2 liquid wave, looping every 10 seconds (Reduce Motion or the Settings switch turns it off).
struct LiquidWaveEffect: ViewModifier {
    let on: Bool
    let amplitude: Float

    func body(content: Content) -> some View {
        if on {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10))
                let a = amplitude
                content.visualEffect { c, proxy in
                    c.distortionEffect(ShaderLibrary.liquidWave(.float(t), .float(a), .float2(proxy.size)),
                                       maxSampleOffset: CGSize(width: CGFloat(a) + 1, height: CGFloat(a) + 1))
                }
            }
        } else {
            content
        }
    }
}
