import SwiftUI

/// Card style A, "Liquid slab" with straight edges (owner's pick): native Liquid Glass frosted by AI glass, the moving
/// light inside, a thick clear bevel and the IMG1 rim from the GlassLens shader. Text sits above the glass and is
/// never frosted (preview build 14 lesson).
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 38
    var bevel: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(bevel + 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { CardSurface(cornerRadius: cornerRadius, bevel: bevel) }
    }
}

struct CardSurface: View {
    var cornerRadius: CGFloat
    var bevel: CGFloat
    @Environment(AIGlass.self) private var ai
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let dark = scheme == .dark
        let advice = ai.advice
        let r = Float(cornerRadius), b = Float(bevel)
        ZStack {
            if reduceTransparency {
                shape.fill(Color(.secondarySystemBackground))
            } else {
                shape.fill(advice.tint).glassEffect(advice.blur > 0.5 ? .regular : .clear, in: shape)
                shape.fill((dark ? Color.black : Color.white).opacity(advice.frost * 0.5))
                MovingLight(colors: advice.lightColors(dark: dark), speed: 0.6)
                    .opacity(dark ? 0.55 : 0.7)
                    .clipShape(shape)
                    .visualEffect { content, proxy in
                        content.layerEffect(ShaderLibrary.glassLens(.float4(0, 0, Float(proxy.size.width), Float(proxy.size.height)),
                                                                    .float(r), .float(b), .float(2.2), .float(0.6), .float(1)),
                                            maxSampleOffset: CGSize(width: CGFloat(b) + 4, height: CGFloat(b) + 4))
                    }
                    .modifier(WavyEdges(on: settings.wavyCardEdges && !reduceMotion))
            }
            BevelRim(cornerRadius: cornerRadius, bevel: bevel)
        }
        .shadow(color: .black.opacity(0.12), radius: 30, y: 12)
        .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
    }
}

/// Optional waving card edges (Off by default; owner: "the shape keeps changing to non straight lines").
private struct WavyEdges: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10))
                content.visualEffect { c, proxy in
                    c.distortionEffect(ShaderLibrary.liquidWave(.float(t), .float(3), .float2(proxy.size)),
                                       maxSampleOffset: CGSize(width: 4, height: 4))
                }
            }
        } else {
            content
        }
    }
}
