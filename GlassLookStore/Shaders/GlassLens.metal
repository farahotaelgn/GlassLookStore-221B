// GlassLens: the IMG1 music-icon glass. Inside a rounded rectangle, content near the rim is pulled inward and split
// into red and blue (colour fringe 0 in the centre, strongest at the rim), with a white streak top left and a thin
// bright inner stroke. The same math as the approved web preview. Applied with .layerEffect on top of native glass.
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float sdRoundBox(float2 p, float2 c, float2 h, float r) {
    float2 d = abs(p - c) - (h - r);
    return length(max(d, float2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

/// rect = (x, y, width, height) in the layer's points; radius = corner radius; bevel = rim width;
/// fringe = colour split in points at the rim; smear = how far the rim pulls content (IMG1); magnify = lens zoom.
[[ stitchable ]] half4 glassLens(float2 position, SwiftUI::Layer layer, float4 rect, float radius, float bevel,
                                 float fringe, float smear, float magnify) {
    float2 h = rect.zw * 0.5;
    float2 c = rect.xy + h;
    float r = min(radius, min(h.x, h.y));
    float d = sdRoundBox(position, c, h, r);
    if (d > 0.0) {
        return layer.sample(position);
    }
    float e = 1.0;
    float2 n = float2(sdRoundBox(position + float2(e, 0.0), c, h, r) - sdRoundBox(position - float2(e, 0.0), c, h, r),
                      sdRoundBox(position + float2(0.0, e), c, h, r) - sdRoundBox(position - float2(0.0, e), c, h, r));
    n = n / max(length(n), 0.0001);
    float depth = -d;
    float t = clamp(1.0 - depth / max(bevel, 0.001), 0.0, 1.0);
    float2 base = c + (position - c) / max(magnify, 0.01);
    float2 disp = -n * pow(t, 1.4) * bevel * smear;
    float ca = fringe * t * t;
    half4 g = layer.sample(base + disp);
    half rr = layer.sample(base + disp + n * ca).r;
    half bb = layer.sample(base + disp - n * ca).b;
    half4 col = half4(rr, g.g, bb, g.a);
    float spec = max(0.0, dot(n, normalize(float2(-0.7, -0.75)))) * t * t * 0.55;
    float stroke = 0.6 * (1.0 - smoothstep(0.0, 1.2, depth));
    float light = clamp(spec + stroke, 0.0, 1.0);
    col.rgb = col.rgb + half3(light) * (1.0h - col.rgb);
    col.a = max(col.a, half(light));
    return col;
}
