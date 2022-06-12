float4 main(PS_IN pin) {
  // Reading depth value for current pixel of the scene:
  float depthValue = txDepth.SampleLevel(samLinearSimple, pin.Tex, 0);

  // Turning that depth value in world coordinates in meters (relative to camera position):
  float4 posW = mul(float4(pin.Tex, depthValue, 1), gTexToCamera);
  posW.xyz /= posW.w;

  // Vertical offset is based on relative coordinate, but gets smaller with distance to avoid messing up distant relief
  float offset = posW.y / (1 + max(0, length(posW.xz) - 100) / 500);

  // Turning vertical offset to a nice intensity gradient with smoothstep:
  float intensity = gIntensity * smoothstep(0, 1, saturate((offset - 40) / 40));

  // If argument for clip is below zero, blending stage will be skipped, slightly improving performance:
  clip(depthValue == 1 
    ? -1                   // 1 for depthValue usually means it’s the sky
    : intensity - 0.001);  // otherwise, we clip pixels that would be barely visible anyway

  // Building resulting RGBA color:
  return float4(
    pin.GetFogColor(),  // we could just use gFogColor, but this way it would account for sunlight absorbing in fog
    intensity);
}