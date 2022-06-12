#include "aurora_base.hlsl"

float main(PS_IN pin) {
  float3 dir = normalize(mul(float4((pin.Tex * 2 - 1) * gUVPadding * 0.5 + 0.5, 1, 1), gTexToCamera).xyz);
  clip(dir.y);

  float4 heightOffset = txNoise.SampleLevel(samLinearSimple, getSkyPoint(dir, 14e3).xz * 0.00001, 0);
  float cur = waves(getSkyPoint(dir, 14e3 * (0.8 + heightOffset.x * 0.4)).xz * 0.0001, 3)
    * saturate(dir.y * 15 - 0.5) 
    * sqrt(saturate(dir.y * 2));
  return cur;
}
