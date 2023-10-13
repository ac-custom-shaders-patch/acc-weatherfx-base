static const float3x3 tm_aces_input = float3x3(
  0.59719, 0.35458, 0.04823,
  0.07600, 0.90834, 0.01566,
  0.02840, 0.13383, 0.83777
);

static const float3x3 tm_aces_output = float3x3(
  1.60475, -0.53108, -0.07367,
  -0.10208,  1.10813, -0.00605,
  -0.00327, -0.07276,  1.07602
);

float3 tm_aces(float3 v) {
  float3 a = v * (v + 0.0245786) - 0.000090537;
  float3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
  return a / b;
}

float tm_uchimura(float x, float P, float a, float m, float l, float c, float b) {
  float l0 = ((P - m) * l) / a;
  float L0 = m - m / a;
  float L1 = m + (1.0 - m) / a;
  float S0 = m + l0;
  float S1 = m + a * l0;
  float C2 = (a * P) / (P - S1);
  float CP = -C2 / P;
  float w0 = 1.0 - smoothstep(0.0, m, x);
  float w2 = step(m + l0, x);
  float w1 = 1.0 - w0 - w2;
  float T = m * pow(x / m, c) + b;
  float S = P - (P - S1) * exp(CP * (x - S0));
  float L = m + a * (x - m);
  return T * w0 + L * w1 + S * w2;
}

float tm_uchimura(float x) {
  const float P = 1.0;  // max display brightness
  const float a = 1.0;  // contrast
  const float m = 0.22; // linear section start
  const float l = 0.4;  // linear section length
  const float c = 1.33; // black
  const float b = 0.0;  // pedestal
  return tm_uchimura(x, P, a, m, l, c, b);
}

#define W (gMappingFactor / 20)

float tm_lottes(float x) {
  const float a = 1.6;
  const float d = 0.977;
  const float hdrMax = max(0, W) + 1;
  const float midIn = 0.18;
  const float midOut = 0.267;
  const float b = (-pow(midIn, a) + pow(hdrMax, a) * midOut) / ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
  const float c = (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) / ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
  return pow(x, a) / (pow(x, a * d) * b + c);
}

float tm_unreal(float x) {
  return pow(x / (x + 0.155) * 1.019, 2.8);
}

float tm_filmic(float x) {
  const float A = 0.22, B = 0.3, C = 0.1, D = 0.20, E = 0.01, F = 0.30;
	return ((x * (0.22 * x + 0.1 * 0.3) + 0.2 * 0.01) / (x * (0.22 * x + 0.3) + 0.2 * 0.3)) - 0.01 / 0.3;
}

float3 colorGrading(float3 col) {
  #if TONEMAP_FN == 0 // linear
    return col;
  #elif TONEMAP_FN == 1 // linear (saturation)
    return saturate(col);
  #elif TONEMAP_FN == 2 // sensitometric, not accurate at all
    col = max(col, 0.0001);
    col = exp(-gMappingData.x * col);
    col = pow(1 - col * gMappingData.y, 2) * (1 - col);
    return col;
  #elif TONEMAP_FN == 3 // reinhard
    return col * (1 + col * gMappingData.x) / (1 + col);
  #elif TONEMAP_FN == 4 // reinhard (luminance)
    return col * (1 + col * gMappingData.x) / (1 + dot(col, 1./3));
  #elif TONEMAP_FN == 5 // logarithmic, not very accurate
    col *= 1 + gMappingData.z;
    return log(col * gMappingData.x + 1) * gMappingData.y;
  #elif TONEMAP_FN == 6 // logarithmic (luminance), not very accurate
    col *= 1 + gMappingData.z;
    return col * ((log(dot(col, 1./3) * gMappingData.x + 1) * gMappingData.y) / dot(col, 1./3));
  #elif TONEMAP_FN == 7 // ACES
    col = mul(tm_aces_input, col);
    col = tm_aces(col);
    return mul(tm_aces_output, col);
  #elif TONEMAP_FN == 8 // uchimura
    return float3(tm_uchimura(col.x), tm_uchimura(col.y), tm_uchimura(col.z));  
  #elif TONEMAP_FN == 9 // rombindahouse
    return exp(-1.0 / (2.72 * col + 0.15));  
  #elif TONEMAP_FN == 10 // lottes
    return float3(tm_lottes(col.x), tm_lottes(col.y), tm_lottes(col.z));  
  #elif TONEMAP_FN == 11 // uncharted
    float A = 0.15, B = 0.50, C = 0.10, D = 0.20, E = 0.02, F = 0.30;
    col = ((col * (A * col + C * B) + D * E) / (col * (A * col + B) + D * F)) - E / F;
    return col / (((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F);
  #elif TONEMAP_FN == 12 // unreal
    return float3(tm_unreal(col.x), tm_unreal(col.y), tm_unreal(col.z));  
  #elif TONEMAP_FN == 13 // filmic
    return float3(tm_filmic(col.r), tm_filmic(col.g), tm_filmic(col.b)) / tm_filmic(W);
  #elif TONEMAP_FN == 14 // reinhard (wp)
    float luma = dot(col, float3(0.2126, 0.7152, 0.0722));
    float toneMappedLuma = luma * (1. + luma / (W * W)) / (1. + luma);
    return col * toneMappedLuma / luma;
  #elif TONEMAP_FN == 15 // juicy
    col = max(col, 0.0001);
    float luma = dot(col, 0.3);
    float tone = exp(-1 / (2 * luma + 0.2)) / luma;
    col = lerp(luma, col, lerp(pow(max(tone, 0), 0.25), tone, saturate((W - 2) / 10)));
    return col * tone;
  #else
    return col.g;
  #endif
}

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
  float4 sampleGrain(float2 uv){
    float4 r = txGrain.SampleLevel(samLinearSimple, uv, 0);
    float p = frac(gTime * 3);
    float w1 = saturate(abs(p * 4 - 1));
    float w2 = saturate(abs(p * 4 - 2));
    float w3 = saturate(abs(p * 4 - 3));
    float w4 = saturate(p < 0.5 ? p * 4 : -(p * 4 - 4));
    return dot(r, float4(w1, w2, w3, w4));
  }
#endif

float2 lensDistortion(float2 uv) {
  return (uv - 0.5) * (1 + dot2(uv - 0.5) * gLensDistortion) / (1 + gLensDistortion / 4) + 0.5;
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
    col.r = txInput.SampleLevel(samLinearClamp, pin.Tex + uvPos * gChromaticAberrationLateral + gChromaticAberrationUniform, 0).r;
    col.b = txInput.SampleLevel(samLinearClamp, pin.Tex - uvPos * gChromaticAberrationLateral - gChromaticAberrationUniform, 0).b;
  #endif

  #ifdef USE_GLARE
    float4 blur1 = txBlur1.SampleLevel(samLinearSimple, pin.Tex, 0);
    float4 blur2 = txBlur2.SampleLevel(samLinearSimple, pin.Tex, 0);
    float3 blurT = blur1.rgb + blur2.rgb * 3;
    col.rgb += blurT * gGlareLuminance;
  #endif

  #ifdef USE_SUN_RAYS
    float2 sunPos = (gSunPosition * 2 - 1) * gVignetteRatio;

    float raysMask = txSunRaysMask.SampleLevel(samLinearBorder0, pin.Tex, 0);
    if (raysMask > 0.01) {
      float sunAura = computeSunAura(uvPos, sunPos);
      col.rgb += gSunColor * sunAura * raysMask;
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

  float4 adj = mul(float4(col.rgb, 1), gMat);
  col.rgb = max(0, adj.rgb / adj.w);
  col.rgb *= gExposure; 
  col.rgb = colorGrading(col.rgb);
  col.rgb = pow(max(col.rgb, 0), gGamma);

  #ifdef USE_COLOR_GRADING
    if (gColorGrading > 0) {
      col.rgb = lerp(col.rgb, txColorGrading.SampleLevel(samLinearClamp, saturate(col.rgb), 0).rgb, gColorGrading);
    }
  #endif

  #ifdef USE_FILM_GRAIN
    float4 noise = sampleGrain(pin.PosH.xy / 512.);
    float response = saturate(1 - dot(col.g, 1/3.));
    col.rgb *= 0.9 + 0.2 * noise.rgb * pow(response, 16);
  #endif
  
  col.w = 1;
  return saturate(col) + pin.GetDithering();
}
