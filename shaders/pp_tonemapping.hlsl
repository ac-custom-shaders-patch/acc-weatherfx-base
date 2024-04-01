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
  x = max(x, 0);
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
  x = max(x, 0);
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
  return pow(max(0, x / (x + 0.155) * 1.019), 2.8);
}

float tm_filmic(float x) {
  const float A = 0.22, B = 0.3, C = 0.1, D = 0.20, E = 0.01, F = 0.30;
	return ((x * (0.22 * x + 0.1 * 0.3) + 0.2 * 0.01) / (x * (0.22 * x + 0.3) + 0.2 * 0.3)) - 0.01 / 0.3;
}

// From: https://iolite-engine.com/blog_posts/minimal_agx_implementation
float3 tm_agx(float3 val) {
  float3 higher = pow(max(0, (val + 0.055) / 1.055), 2.4);
  float3 lower = val / 12.92;  
  val = lerp(higher, lower, val < 0.04045);

  val = saturate((log2(mul(float3x3(
    0.842479062253094, 0.0784335999999992, 0.0792237451477643,
    0.0423282422610123,  0.878468636469772,  0.0791661274605434,
    0.0423756549057051, 0.0784336, 0.879142973793104), val)) + 12.47393) / 16.5);

  float3 va2 = val * val;
  float3 va4 = va2 * va2;  
  val = 15.5 * va4 * va2 - 40.14 * va4 * val + 31.96 * va4 
    - 6.868 * va2 * val + 0.4298 * va2 + 0.1191 * val - 0.00232;

  float luma = dot(val, float3(0.2126, 0.7152, 0.0722));
  float punch = saturate((W - 2) / 10);
  val = luma + (1 + 0.4 * punch) * (pow(max(0, val), 1 + 0.35 * punch) - luma);

  return mul(float3x3(
    1.19687900512017, -0.0980208811401368, -0.0990297440797205,
    -0.0528968517574562, 1.15190312990417, -0.0989611768448433,
    -0.0529716355144438, -0.0980434501171241, 1.15107367264116), val);
}

float3 colorGrading(float3 col) {
  #if TONEMAP_FN == 0 // linear
    return col;
  #elif TONEMAP_FN == 1 // linear (saturation)
    return saturate(col);
  #elif TONEMAP_FN == 2 // sensitometric, not very accurate
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
    float tone = exp(-1 / (2 * luma + 0.2)) / max(0.01, luma);
    col = lerp(luma, col, lerp(pow(max(tone, 0), 0.25), tone, saturate((W - 2) / 10)));
    return col * tone;
  #elif TONEMAP_FN == 16 // agx
    return tm_agx(col);
  #else
    return col.g;
  #endif
}