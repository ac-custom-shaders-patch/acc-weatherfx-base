#define BaseH 10e3
#define EarthR 6e6

float3 getSkyPoint(float3 dir, float H, int layer){  
  float3 pos = gCameraPosition;
  pos.xz += gWindOffset * (1 + 0.2 * layer);
  return pos + float3(dir.x / dir.y, 1, dir.z / dir.y) * (H - gCameraPosition.y);
}

float2 rot(float2 x) {
  return mul(float2x2(4./5, -3./5, 3./5, 4./5), x);
}

float4 sampleClouds(float2 uv, int layer) {
  if (layer >= 0) {
    return txNoiseLr.Sample(samLinearSimple, uv) + (txNoiseLr.Sample(samLinearSimple, gMaskOffset + uv * 0.02645 * (layer == 2 ? 0.5 : 1)) * gMaskBoost[layer] + gMaskShift[layer]);
  }
  float4 ret = 0;
  float m = 1;
  for (int i = 0; i < (MAIN_PASS ? 4 : 3); ++i){
    uv = rot(uv) * 2 + float2(0.336288, 0.394923) - gWindOffset * 0.00005;
    m *= 0.5;
    ret += txNoiseLr.Sample(samLinearSimple, uv) * m;
  }
  return ret;
}

float2 spiralUV(float2 uv, float texBlurry) {
  // From https://www.shadertoy.com/view/XsjGRd
	float reps = 2;
	float2 uv2 = frac(uv*reps);
	float2 center = floor(frac(uv*reps)) + 0.5;
	float2 delta = uv2 - center;
	float dist = length(delta);
	float angle = atan2(delta.y, delta.x);
	float nudge = dist * 4.0;
	float2 offset = float2(delta.y, -delta.x);
	float blend = max(abs(delta.x), abs(delta.y)) * 2.0;
	blend = saturate((0.5 - dist) * 2.0);
	blend = pow(blend, 1.5);
	offset *= blend;
	return uv + offset * 1.1 * texBlurry;
}

float sampleLayerBase(float2 uv, int layer) {
  if (layer == 0) {
    uv = spiralUV(uv, 0.5);
  }
  if (layer == 1) {
    uv = spiralUV(uv, 0.25);
  }
  return sampleClouds(uv, layer).x;
}

float blendTwoSets(float a, float b) {
  return lerp(a, b, gWindMix);
}

float finalizeResult(float r, int layer) {
  r = saturate(r / (1 + abs(r) * 0.5));
  r = smoothstep(0, 1, r);
  if (layer == 1) return pow(r, 4);
  if (layer == 2) return pow(r, 3);
  return pow(r, 2);
  // return pow(r, layer == 2 ? 2 : 8);
}

float sampleLayer(float2 uv, int layer) {
  float blend;
  if (layer == 2) {
    blend = sampleLayerBase(uv, layer) + sampleClouds(uv, -1).x;
  } else if (layer == 1) {
    blend = blendTwoSets(
      sampleLayerBase(mul(uv, float2x2(gWindShiftAlt00, gWindShiftAlt01)), layer),
      sampleLayerBase(mul(uv, float2x2(gWindShiftAlt10, gWindShiftAlt11)), layer))
      + sampleClouds(uv, -1).x;
  } else {
    blend = blendTwoSets(
      sampleLayerBase(mul(uv, float2x2(gWindShift00, gWindShift01)), layer),
      sampleLayerBase(mul(uv, float2x2(gWindShift10, gWindShift11)), layer))
      + sampleClouds(uv, -1).x;
  }
  return finalizeResult(blend, layer);
  // float ret = 0;
  // for (int i = 0; i < 4; ++i) {
  //   ret += sampleLayerBase(skyPoint);
  //   skyPoint.xz += gWindOffset * 5;
  // }
  // return ret / 4;
}

void mixLayer(inout float4 base, float4 cover){
  float newAlpha = lerp(base.w, 1, cover.w);
  base.xyz = lerp(base.xyz * base.w, cover.xyz, cover.w) / max(0.000001, newAlpha);
  base.w = newAlpha;
}

float4 main(PS_IN pin) {
  float3 dir = normalize(mul(float4(pin.Tex, 1, 1), gTexToCamera).xyz);
  clip(dir.y - 0.01);

  float3 skyPointH = getSkyPoint(dir, 14e3, 0);
  float3 skyPointM = getSkyPoint(dir, 8e3, 1);
  float3 skyPointL = getSkyPoint(dir, 4e3, 2);

  float layerH = sampleLayer(skyPointH.xz / 3.35e4, 0);
  float layerM = sampleLayer(skyPointM.xz / 2.17e4, 1);
  float layerL = sampleLayer(skyPointL.xz / 5.76e3, 2);

  float layerL0 = sampleClouds(skyPointL.xz / 5e3, 2).x;
  float layerL1 = sampleClouds(skyPointL.xz / 5e3 + float2(0.02, 0), 2).x;
  float layerL2 = sampleClouds(skyPointL.xz / 5e3 + float2(0, 0.02), 2).x;
  float3 nm = normalize(float3(layerL1 - layerL0, -0.2, layerL2 - layerL0));

  float3 baseColor = (gCloudsAmbientColor + gCloudsSunColor) * 0.1;

  float4 mixed = float4(baseColor, layerH * gThickness.x);
  mixLayer(mixed, float4(baseColor, layerM * gThickness.y));

  // mixed = float4(1, 0, 0, layerH);
  // mixLayer(mixed, float4(0, 1, 0, layerM));
  mixLayer(mixed, float4((gCloudsAmbientColor + gCloudsSunColor 
    * (0.5 + 0.5 * (MAIN_PASS ? dot(nm, gCloudsSunDirection) : 0.5))) * 0.1, layerL * gThickness.z));

  mixed.w = saturate(mixed.w - 1 + saturate((dir.y - 0.01) * 50));
  mixed.rgb += pow(saturate(dot(dir, gCloudsSunDirection)), 3) * gCloudsSunColor * saturate(1 - mixed.w);

  pin.PosC = skyPointL - gCameraPosition;
  return pin.ApplyFog(mixed);
}