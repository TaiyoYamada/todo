#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// 1点から広がる波紋。達成の瞬間に、画面全体を水面のように揺らす。
//
// 各画素について、中心からの距離ぶんだけ遅れて波が届くように時間をずらし、
// 減衰する正弦波の大きさだけ、中心から外向きに参照位置をずらす。
[[ stitchable ]] half4 Ripple(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float time,
    float amplitude,
    float frequency,
    float decay,
    float speed
) {
    float distance = length(position - origin);
    float delay = distance / speed;

    time = max(0.0, time - delay);

    float amount = amplitude * sin(frequency * time) * exp(-decay * time);
    float2 direction = distance > 0.0 ? normalize(position - origin) : float2(0.0, 0.0);

    half4 color = layer.sample(position + amount * direction);

    // 波の山を少し明るく、谷を少し暗くして、光が走るように見せる。
    color.rgb += 0.3 * (amount / amplitude) * color.a;
    return color;
}
