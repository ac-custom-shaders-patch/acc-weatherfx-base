#include "pp_tonemapping.hlsl"

float noise(float t) {
  return txNoise.SampleLevel(samLinear, float2(t, 0) / 32, 0).x;
}

float computeSunAura(float2 uv, float2 pos) {
  float2 main = uv - pos;  
  float ang = atan2(main.y, main.x);
  float distB = length(main); 
  return (16 + sin(noise(sin(ang * 2 + pos.x) * 4.0 - cos(ang * 3 + pos.y)) * 16)) / (distB * 128 + 1);  
}

float dot2(float2 v){
  return dot(v, v);
}

bool lensFlareFits(float2 pos, float distance){
  return dot2(pos) < distance;
}

float3 computeLensFlare(float2 uv, float2 pos) {  
  float2 uvd = uv * length(uv);

  float3 r2 = 0, r4 = 0, r5 = 0, r6 = 0;
  
  {
    float3 f2 = float3(dot2(uvd + 0.8 * pos), dot2(uvd + 0.85 * pos), dot2(uvd + 0.9 * pos));
    r2 = saturate(1 / (1 + 32 * f2)) * float3(0.25, 0.23, 0.21);
  }
  
  float2 uvx = lerp(uv, uvd, -0.5);  
  [branch]
  if (lensFlareFits(uvx + 0.45 * pos, 0.2)) {
    float3 f4 = float3(dot2(uvx + 0.4 * pos), dot2(uvx + 0.45 * pos), dot2(uvx + 0.5 * pos));
    r4 = saturate(0.022 - f4) * 0.48 * float3(6, 5, 3);
  }
  
  uvx = lerp(uv, uvd, -0.4);  
  [branch]
  if (lensFlareFits(uvx + 0.25 * pos, 0.7)) {
    float3 f5 = float3(dot2(uvx + 0.2 * pos), dot2(uvx + 0.4 * pos), dot2(uvx + 0.6 * pos));
    r5 = saturate(0.035 - pow(f5, 2)) * 0.6;
  }
  
  uvx = lerp(uv, uvd, -0.5);  
  [branch]
  if (lensFlareFits(uvx - 0.325 * pos, 0.025)) {
    float3 f6 = float3(dot2(uvx - 0.3 * pos), dot2(uvx - 0.325 * pos), dot2(uvx - 0.35 * pos));
    r6 = saturate(0.003 - f6) * float3(18, 9, 15);
  }

  return r2 + r4 + r5 + r6;
}

#ifdef USE_FILM_GRAIN
  float3 sampleGrain3(float2 uv){
    float4 noise = txNoise.SampleLevel(samLinearSimple, uv.xy / 1024, 0);
    float timeAdjusted = gTime + noise.x * 0.1;
    float timeInput = timeAdjusted * 20;
    float transition = frac(timeInput);
    float3 frame1 = txGrain.SampleLevel(samLinearSimple, (uv / 256 + ((int)(timeInput) & 15)) * float2(1, 1. / 16) + floor(timeAdjusted) * 0.2, 0).rgb;
    float3 frame2 = txGrain.SampleLevel(samLinearSimple, (uv / 256 + ((int)(timeInput + 1) & 15)) * float2(1, 1. / 16) + floor(timeAdjusted) * 0.2, 0).rgb;
    return lerp(frame1, frame2, transition);
  }
#endif

float2 lensDistortion(float2 uv) {
  return (uv - 0.5) * (1 + dot2(uv - 0.5) * gLensDistortion) / (1 + gLensDistortion / 4) + 0.5;
}

float3 hsv2rgb(float3 c) {
  float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float3 toSrgb(float3 linearRGB) {  
	bool3 cutoff = linearRGB < 0.0031308;
	float3 higher = 1.055 * pow(max(linearRGB, 0), 1. / 2.4) - 0.055;
	float3 lower = linearRGB * 12.92;
	return lerp(higher, lower, cutoff ? 1 : 0);
}

float4 main(PS_IN pin){
  #ifdef USE_LENS_DISTORTION
    float2 lensRatio = gVignetteRatio.x > gVignetteRatio.y 
      ? float2(1, gVignetteRatio.y / gVignetteRatio.x)
      : float2(gVignetteRatio.x / gVignetteRatio.y, 1);
    pin.Tex = ((pin.Tex * 2 - 1) * lensRatio) * 0.5 + 0.5;
    pin.Tex = lensDistortion(pin.Tex);
    pin.Tex = ((pin.Tex * 2 - 1) / lensRatio) * 0.5 + 0.5;
  #endif
  
  float2 uvPos = (pin.Tex * 2 - 1) * gVignetteRatio;
  float4 col = txInput.SampleLevel(samLinearSimple, pin.Tex, 0);

  #ifdef USE_CHROMATIC_ABERRATION
    col.r = txInput.SampleLevel(samPointClamp, pin.Tex + uvPos * gChromaticAberrationLateral + gChromaticAberrationUniform, 0).r;
    col.b = txInput.SampleLevel(samPointClamp, pin.Tex - uvPos * gChromaticAberrationLateral - gChromaticAberrationUniform, 0).b;
  #endif

  #ifdef USE_GLARE
    float4 blur1 = txBlur1.SampleLevel(samLinearSimple, pin.Tex, 0);
    float4 blur2 = txBlur2.SampleLevel(samLinearSimple, pin.Tex, 0);
    float3 blurT = blur1.rgb + blur2.rgb * 3;
    col.rgb += pow(blurT, 2) * 0.1 * gGlareLuminance;
  #endif

  // For testing tonemapping functions:
  // col.rgb = hsv2rgb(float3(pin.Tex.y * 2, 1, 1)) * pow(pin.Tex.x, 4) * 1e3;

  #ifdef USE_SUN_RAYS
    float2 sunPos = (gSunPosition * 2 - 1) * gVignetteRatio;

    float raysMask = txSunRaysMask.SampleLevel(samLinearBorder0, pin.Tex, 0);
    if (raysMask > 0.01) {
      float sunAura = computeSunAura(uvPos, sunPos);
      col.rgb += gSunColor * pow(sunAura * raysMask, USE_LINEAR_COLOR_SPACE ? 2 : 1) * (USE_LINEAR_COLOR_SPACE ? 10 : 1);
    }

    float flareMult = saturate((1 - dot2(sunPos)) * 2);
    [branch]
    if (flareMult > 0.01) {
      float flareMask = flareMult * txMask.SampleLevel(samLinearBorder0, gSunPosition, 0);
      if (flareMask > 0.01) {
        float3 flare = computeLensFlare(uvPos, sunPos);
        col.rgb += gSunColor * flare * flareMask; 
      }
    }
  #endif

  #ifdef USE_LENS_DISTORTION
    float2 uvRel = abs(pin.Tex * 2 - 1);
    float pad = gLensDistortionRoundness;
    uvRel = (uvRel - 1) * float2(pad * lensRatio.x / lensRatio.y, pad) + 1;
    uvRel = pow(max(uvRel, 0), 2);
    col *= saturate(smoothstep(0, 1, (1 - length(uvRel)) * gLensDistortionSmoothness));
  #endif

  #ifdef USE_VIGNETTE
    if (gVignette > 0){
      col *= lerp(1, 1 - length((pin.Tex * 2 - 1) * gVignetteRatio), gVignette);
    }
  #endif

  if (USE_LINEAR_COLOR_SPACE) {
    col.rgb = toSrgb(col.rgb * gGammaFixBrightnessOffset);
  }
  
  // if (dot(abs(col.rgb - float3(200, 100, 0)), 1) < 10) return float4(0, 0, 1, 1);
  // if (col.r > 180) return float4(0, 0, 1, 1);

  float4 adj = mul(float4(col.rgb, 1), gMat);
  col.rgb = max(0, adj.rgb / adj.w);
  col.rgb *= gExposure; 
  col.rgb = colorGrading(col.rgb);
  col.rgb = pow(max(col.rgb, 0), gGamma);

  // col.rgb = float3(raysMask, 1 - raysMask, 0);

  #ifdef USE_COLOR_GRADING
    if (gColorGrading > 0) {
      col.rgb = lerp(col.rgb, txColorGrading.SampleLevel(samLinearClamp, saturate(col.rgb), 0).rgb, gColorGrading);
    }
  #endif

  #ifdef USE_FILM_GRAIN
    float3 noise = sampleGrain3(pin.PosH.xy);
    float response = saturate(1 - dot(col.rgb, 1/3.));
    col.rgb *= lerp(1, 2 * noise.rgb, 0.4 * pow(response, 12));
  #endif
  
  col.w = 1;
  return saturate(col) + pin.GetDithering();
}
