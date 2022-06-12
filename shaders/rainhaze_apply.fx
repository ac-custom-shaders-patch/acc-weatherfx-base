const static float3 POISSON_DISC_16[16] = {
  float3(0.8954767f, -0.1575644f, 0.9092332f),
  float3(0.4352259f, -0.4984821f, 0.6617447f),
  float3(0.7695779f, 0.3616731f, 0.850328f),
  float3(0.1323851f, 0.0497573f, 0.141427f),
  float3(0.2105618f, 0.9109722f, 0.9349902f),
  float3(0.2277734f, 0.4944786f, 0.544417f),
  float3(-0.380273f, 0.1147139f, 0.3971987f),
  float3(-0.1111894f, -0.2835931f, 0.3046114f),
  float3(-0.2282531f, 0.5713289f, 0.6152368f),
  float3(-0.5346423f, -0.2667225f, 0.5974808f),
  float3(-0.5894181f, -0.762647f, 0.9638693f),
  float3(-0.2105553f, -0.9640824f, 0.9868071f),
  float3(-0.6383594f, 0.4755866f, 0.7960436f),
  float3(-0.9285333f, 0.1501847f, 0.9406006f),
  float3(0.3938299f, -0.9144654f, 0.995665f),
  float3(-0.9361477f, -0.3214122f, 0.989787f)
};

float gatherBase(float2 uv){
  /* This is not a regular blur, but a weighted blur. More opaque each sample is, more weight it would
     have. Done like that, it solves a problem with anything covering distant fog getting some sort of
     halo effect around it. */
  float2 ret = 0;
  for (int i = 0; i < 16; ++i){
    float v = txBase.SampleLevel(samLinearBorder0, uv + POISSON_DISC_16[i].xy * gBlurRadius, 0).x;
    ret += float2(v, 1) * (v + 0.1);
  }
  return ret.x / ret.y;
}

float4 main(PS_IN pin) {
  return float4(gFogColor, gatherBase(pin.Tex));
}
