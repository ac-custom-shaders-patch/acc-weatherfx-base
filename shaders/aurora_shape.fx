#define HIGHFREQ_NOISE
#include "aurora_base.hlsl"

float main(PS_IN pin) {
  float3 dir = normalize(mul(float4((pin.Tex * 2 - 1) * gUVPadding * 0.5 + 0.5, 1, 1), gTexToCamera).xyz);
  clip(dir.y);

  float3 skyPoint = getSkyPoint(dir);
  float cur = waves(skyPoint.xz * 0.0001) 
    * saturate(dir.y * 15 - 0.5) 
    * sqrt(saturate(dir.y * 4));

  return cur;
}
