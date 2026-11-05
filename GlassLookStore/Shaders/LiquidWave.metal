// LiquidWave: the slow liquid wave of IMG2 behind and through the hero counter. A noise-like sum of sines that loops
// exactly every 10 seconds (time is in seconds; every term turns a whole number of times per loop).
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] float2 liquidWave(float2 position, float time, float amplitude, float2 size) {
    float loop = 6.2831853 * time / 10.0;
    float2 p = position / max(size, float2(1.0));
    float dx = 0.6 * sin(p.y * 9.0 + loop) + 0.4 * sin(p.x * 5.0 - 2.0 * loop);
    float dy = 0.6 * cos(p.x * 7.0 + loop) + 0.4 * sin(p.y * 4.0 + 3.0 * loop);
    return position + float2(dx, dy) * amplitude;
}
