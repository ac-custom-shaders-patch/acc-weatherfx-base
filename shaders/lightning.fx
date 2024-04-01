float4 perlin(float2 input, int steps, float2 k = float2(2, 0.5)) {
  float4 ret;
  float mult = 1;
  for (int i = 0; i < steps; ++i) {
    ret += txNoiseLR.SampleLevel(samLinearSimple, input, 0) * mult;
    input *= k.x;
    mult *= k.y;
  }
  return ret;
}

float curveOffset(float pinX, float uvY, out float xPos, float base = 0, float offsetMult = 0) {
  float4 txn = perlin(float2(0, uvY), 4);
  xPos = base + abs(txn.x) * offsetMult;
  return abs(pinX * 2 - xPos); // < 0.01 * (1 / max(0.5, 1 - abs(txn1.x - txn.x) * 10));
}

float lShape(float2 pinTex) {
  float uv0 = pinTex.y * 0.05 + 0.17;
  float4 txn = perlin(float2(gTimer * 0.0002, uv0), 6);
  float s0 = abs(pinTex.x * 2 - txn.x);
  for (int i = 0; i < 4; ++i){
    float u1 = frac(pinTex.y * (1 + i));
    float s1 = floor(pinTex.y * (1 + i)) % 2 == 1 ? 1 : -1;
    if (frac(gSeed + i * 0.117 + floor(pinTex.y * (1 + i)) * 0.533) > 0.9) {
      float xPos;
      s0 = min(s0, (1 / (1 - u1)) * curveOffset(pinTex.x, pinTex.y * -0.1 * (1 + i * 0.5) + 0.712, xPos, txn.x,
        0.5 * u1 * s1));

      for (int j = 0; j < 2; ++j){
        float u2 = frac(u1 * (2 + j));
        float s2 = floor(u1 * (2 + j)) % 2 == 1 ? 1 : -1;
        if (floor(u1 * (2 + j)) >= 1
            && frac(gSeed + j * 0.495 + floor(pinTex.y * (1 + j)) * 0.717) > 0.8) {
          s0 = min(s0, (1 / (1 - u2)) * curveOffset(pinTex.x, pinTex.y * 0.2 * (1 + j * 0.5) + 0.978, xPos, xPos,
            0.2 * u2 * s2));
        }
      }
    }
    pinTex.y += gSeed * 10;
  }
  return s0;
}

float4 main(PS_IN pin){
  float2 baseUV = pin.Tex;
  {
    float baseTexY = pin.Tex.y;
    pin.Tex.y = pin.Tex.y + gSeed * 10;
    float s1 = lShape(pin.Tex);
    float s2 = lShape(pin.Tex - float2(0, 0.005));
    #ifdef LOWRES
      return saturate(1.2 - s1 * 40);
    #else
      float v = saturate(1.2 - s1 * 200);
      v = saturate(1 - s1 * lerp(200, 1 / max(0.001, fwidth(s1)), 0.5));
      v *= (1 - pow(baseTexY, 20)) * pow(saturate(baseTexY * 3), 4);
      if (baseTexY < 0.01) v = 0;
      v += pow(txGlow.SampleLevel(samLinearSimple, baseUV, 0), 2) * saturate(baseTexY * 3) * 0.002;
      return float4(pin.ApplyFog(
        gWhiteRefPoint.xxx * lerp(100, 0, pow(gTimer, 0.01)) * lerp(1, float3(1 - baseTexY, baseTexY, baseTexY), 0.2)), v);
    #endif
    return s1 < 0.01;// / (1 - abs(s2 - s1) * 0);
  }
}