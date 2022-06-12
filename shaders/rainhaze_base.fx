float main(PS_IN pin) {
  float depthValue = txDepth.SampleLevel(samLinearSimple, pin.Tex, 0);
  float linearDepth = linearizeDepth(depthValue);
  if (depthValue == 1 || linearDepth < 10 || linearDepth > 2e3) return 0;

  float4 posW = mul(float4(pin.Tex, depthValue, 1), gTexToCamera);
  posW.xyz /= posW.w;

  float3 baseOffset = gCameraPosition + gRainOffset;
  float4 rnd = txNoise.Load(int3(pin.PosH.xy % 32, 0));

  float t = 1;
  for (int i = 1; i < 10; ++i){
    float3 p = lerp(posW.xyz, 0, ((float)i + rnd.x) / 10.);
    t *= 1 - pow(txNoise3D.SampleLevel(samLinearSimple, (baseOffset + p.xyz) * (1. / float3(140, 200, 140) / 1), 0).x, 3);
  }
  t = pow(1 - t, 1);

  return gIntensity * saturate(t * 2.5 - 1.5) * saturate(linearDepth / 10 - 1) * saturate(2 - linearDepth / 1e3) * (1 - 1 / (1 + linearDepth * gDistanceInv));
}