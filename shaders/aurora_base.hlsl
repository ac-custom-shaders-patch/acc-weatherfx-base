#define BaseH 10e3
#define EarthR 500e3

float4 sampleNoise(float2 uv, bool fixUv = false){
  if (fixUv){
    float textureResolution = 32;
    uv = uv * textureResolution + 0.5;
    float2 i = floor(uv);
    float2 f = frac(uv);
    uv = i + f * f * (3 - 2 * f);
    uv = (uv - 0.5) / textureResolution;
  }
	return txNoise.SampleLevel(samLinearSimple, uv, 0);
}

float waves(float2 inCoords, float concentration = 4){
  float2 uv = inCoords;
  uv += sampleNoise(inCoords * -0.05 + 0.5 + gTime * 0.0019, true).xy * 0.4;
  uv += sampleNoise(inCoords * 0.04 + gTime * 0.0015, true).xy * 0.5;
  uv += sampleNoise(inCoords * 0.004 - gTime * 0.0002, true).xy * 2.5;
  uv += txNoiseLr.SampleLevel(samLinearSimple, inCoords * 0.003 - gTime * 0.00004, true).xy * 12.5;
  return saturate(1 - lerp(concentration, 1, saturate(fwidth(uv.y))) * abs(frac(uv.y + 0.5) - 0.5))
    * saturate(sampleNoise(uv * float2(0.001, 0.1) + gTime * 0.00033).x * 8 - 4)
    // * saturate(sampleNoise(uv * 0.73 * float2(0.001, 0.1) + gTime * 0.00031).x * 8 - 3)
    #ifdef HIGHFREQ_NOISE
    * lerp(1, 0.4, saturate(sampleNoise(uv * 0.01 + gTime * 0.0031).x * 8 - 4) 
      * sampleNoise(uv * float2(0.00113, 0.113) + gTime * 0.00027).x * saturate(sampleNoise(inCoords * 0.5, false).x * 10 - 4))
    #endif
    ;
}

float3 getSkyPoint(float3 dir, float H = BaseH){  
  float h = H - gCameraPosition.y;
  float m = h / dir.y;
  float3 skyPoint = gCameraPosition + dir * m;

  float3 core = gCameraPosition - float3(0, EarthR, 0);
  float3 skyRel = skyPoint - core;
  float3 skyNorm = normalize(skyPoint - core) * (H + EarthR);
  skyPoint += skyNorm - skyRel;
  return skyPoint;
}

float temporalSmoothing(Texture2D<float1> txPrevious, float2 tex, float ret){  
  float4 oldPos = mul(float4(tex, 1, 1), gTexToCamera);
  oldPos /= oldPos.w;

  float4 newUV = mul(oldPos, gPreviousCameraToTex);
  newUV /= newUV.w;

  float prev = txPrevious.Sample(samLinearBorder0, newUV.xy).x;
  float2 uvDist = abs(newUV.xy - 0.5);
  float mix = prev == 0 ? 1 : lerp(gTemporalSmoothing, 1, saturate((max(uvDist.x, uvDist.y) - 0.495) * 200) * 0.95);
  return lerp(prev, ret, mix);
}

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
