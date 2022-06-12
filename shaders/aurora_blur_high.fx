#include "aurora_base.hlsl"

float gatherGlow(float2 uv, float2 blurDir, float4 offset){
  float ret = 0;
  for (int i = 0; i < 16; ++i){
    float2 uvOffset = reflect(POISSON_DISC_16[i].xy, normalize(offset.yz - 0.5));
    ret += txPrepared.SampleLevel(samLinearBorder0, uv + blurDir * ((i + offset.x) / 16.) + uvOffset * gNoiseScale, 0).x;
  }
  return ret / 16;
}

float main(PS_IN pin) {
  float2 uvAlt = (pin.Tex * 2 - 1) / gUVPadding * 0.5 + 0.5;

  float3 dir = normalize(pin.PosC);
  clip(dir.y);

  float3 skyPoint = getSkyPoint(dir, 14e3);
  float4 pointBase = mul(float4(skyPoint, 1), gCameraToTex);
  float4 pointDir = mul(float4(skyPoint - float3(0, BaseH / 2, 0), 1), gCameraToTex);
  float2 blurDir = (pointDir.xy / pointDir.w - pointBase.xy / pointBase.w);
  float4 offset = txNoise.SampleLevel(samPoint, (pin.PosH.xy + gShuffle) / 16, 0);

  float ret = gatherGlow(uvAlt, blurDir, offset);
  return temporalSmoothing(txPrevious, pin.Tex, ret);
}
