#include "aurora_base.hlsl"

float gatherGlow(float2 uv, float2 blurDir, float offset){
  float ret = 0;
  for (int i = 0; i < 24; ++i){
    ret += txPrepared.SampleLevel(samLinearBorder0, uv + blurDir * pow((i + offset * min(1, i / 3.5)) / 24., 1), 0).x * lerp(1, 0, i / 24.);
  }
  return ret / 8;
}

float main(PS_IN pin) {
  float2 uvAlt = (pin.Tex * 2 - 1) / gUVPadding * 0.5 + 0.5;

  float3 dir = normalize(pin.PosC);
  clip(dir.y);

  float3 skyPoint = getSkyPoint(dir) - gCameraPosition;
  float4 pointBase = mul(float4(skyPoint, 1), gCameraToTex);
  float4 pointDir = mul(float4(skyPoint - float3(0, BaseH / 3, 0), 1), gCameraToTex);
  float2 blurDir = pointDir.xy / pointDir.w - pointBase.xy / pointBase.w;
  float offset = txNoise.SampleLevel(samPoint, (pin.PosH.xy + gShuffle) / 16, 0).x;

  float ret = gatherGlow(uvAlt, blurDir, offset);
  return temporalSmoothing(txPrevious, pin.Tex, ret);
}
