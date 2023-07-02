float tonemap_uchimura(float x, float P, float a, float m, float l, float c, float b) {
  // Uchimura 2017, "HDR theory and practice"
  // Math: https://www.desmos.com/calculator/gslcdxvipg
  // Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
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

float tonemap_uchimura(float x) {
  const float P = 1.0;  // max display brightness
  const float a = 1.0;  // contrast
  const float m = 0.22; // linear section start
  const float l = 0.4;  // linear section length
  const float c = 1.33; // black
  const float b = 0.0;  // pedestal
  return tonemap_uchimura(x, P, a, m, l, c, b);
}

float3 main(float3 color){
  float3 ret = float3(tonemap_uchimura(color.x), tonemap_uchimura(color.y), tonemap_uchimura(color.z)).rgb;  
  float4 tx = txGif.SampleLevel(samLinear, color.xy, 0);
  // ret = ret * uv.rrg;
  ret += tx.rgb;
  ret += frac(gTime) * 0.1;
  return ret;
}