float4 main(PS_IN pin){
  float4 col = txInput.SampleLevel(samLinear, pin.Tex, 0);
  if (gBrightnessMult) {
    float brightness = dot(col.rgb, float3(0.3, 0.5, 0.2));
    col.rgb = max(0, col.rgb - gBrightnessMult * 500);
    col.rgb /= gBrightnessMult;
    col.rgb = col.rgb / (1 + 0.05 * col.rgb);
    col.rgb *= gBrightnessMult;
    return col;
  } else {
    col.rgb = max(0, col.rgb - gThreshold);
    col.rgb = col.rgb / (1 + 0.05 * col.rgb);
  }
  return col;
}
