float4 main(PS_IN pin){
  float4 col = txInput.SampleLevel(samLinear, pin.Tex, 0);
  col.rgb = max(0, col.rgb - gThreshold);
  col.rgb = col.rgb / (1 + 0.05 * col.rgb);
  return col;
}
