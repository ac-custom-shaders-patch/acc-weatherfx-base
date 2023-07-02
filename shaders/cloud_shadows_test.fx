#define HIGHFREQ_NOISE
#include "aurora_base.hlsl"

float main(PS_IN pin) {
  // float4 camPosW = mul(float4(pin.Tex, 0, 1), gTexToCamera);
  // float3 camPos = camPosW.xyz / camPosW.w;
  // float3 camDir = mul(float4(pin.Tex, 1, 1), gTexToCamera).xyz;

  float3 dir = normalize(mul(float4(pin.Tex, 1, 1), gTexToCamera).xyz);
  float3 skyPoint = getSkyPoint(dir);
  float cur = waves(skyPoint.xz * 0.001);
  return cur;
}


