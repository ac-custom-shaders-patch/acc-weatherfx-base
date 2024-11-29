float dithering(float2 screenPosPixels){
  return lerp(0.00196, -0.00196, frac(0.25 + dot(screenPosPixels, 0.5)));
}

float4 main(PS_IN pin) {
  clip(pin.PosC.y);

  float main = txMain.SampleLevel(samLinearClamp, pin.Tex, 0).x;
  float high = txHigh.SampleLevel(samLinearClamp, pin.Tex, 0).x * (1 - main);

  float4 ret = float4(0, 0, 0, 1);
  ret.rgb += main * float3((0.5 - 0.4 * normalize(pin.PosC).y) * (1 + pow(main, 4)), 1, 0.2); 
  ret.rgb += high * float3(1 - 0.1 * max(normalize(pin.PosC).y, pow(high, 4)), 0, 0.7 + 0.3 * max(normalize(pin.PosC).y, pow(high, 4))); 
  #if USE_LINEAR_COLOR_SPACE
    ret.rgb = pow(ret.rgb, 2.2);
  #endif

  ret.rgb += dithering(pin.PosH.xy) * 10;
  ret.rgb *= gBrightnessMult;
  return ret;
}
