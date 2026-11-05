import SwiftUI

/// The clear glass bubble of IMG6: a magnified copy of the tabs (1.4x) inside a capsule that spills a little above
/// and below the bar, IMG1 colour rims from the GlassLens shader, a glossy top rim, a soft shade and a thin outline.
struct GlassLensDroplet: View {
    let layout: BarLayout
    let x: CGFloat
    let size: CGSize
    let amount: CGFloat
    let lit: AppTab
    let accent: Color
    let zoom: CGFloat
    let reduceTransparency: Bool

    var body: some View {
        let a = max(0, min(1, amount))
        let mid = BarLayout.height / 2
        let rect = CGRect(x: x - size.width / 2, y: mid - size.height / 2, width: size.width, height: size.height)
        let mag = 1 + (zoom - 1) * a
        ZStack {
            Group {
                if reduceTransparency {
                    Capsule().fill(Color(.tertiarySystemBackground))
                } else {
                    Capsule().fill(.white.opacity(0.10 * a)).glassEffect(.clear.interactive(), in: Capsule())
                }
            }
            .frame(width: size.width, height: size.height)
            .position(x: x, y: mid)

            TabRow(layout: layout, lit: lit, accent: accent, mirrored: false, allLit: true)
                .scaleEffect(mag, anchor: UnitPoint(x: x / max(1, layout.width), y: 0.5))
                .mask { Capsule().frame(width: size.width, height: size.height).position(x: x, y: mid) }
                .layerEffect(ShaderLibrary.glassLens(.float4(Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height)),
                                                     .float(Float(size.height / 2)), .float(Float(11 * a)), .float(Float(1.8 * a)),
                                                     .float(0.3), .float(1)),
                             maxSampleOffset: CGSize(width: 16, height: 16))

            Capsule()
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.15), .white.opacity(0.5)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 1.4)
                .frame(width: size.width, height: size.height)
                .position(x: x, y: mid)
                .opacity(Double(a))
            Capsule()
                .strokeBorder(Color.gray.opacity(0.45), lineWidth: 0.5)
                .frame(width: size.width, height: size.height)
                .position(x: x, y: mid)
                .opacity(Double(a))
        }
        .frame(width: layout.width, height: BarLayout.height)
        .shadow(color: .black.opacity(0.12 * Double(a)), radius: 10, y: 4)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
